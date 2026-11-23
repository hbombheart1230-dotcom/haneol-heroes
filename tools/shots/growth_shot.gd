extends SceneTree
## 강화 단계별 기술 모습 나란히: 실제 main 장면에서 기술의 vfx_level을 바꿔 가며 같은 자리·같은 시각에 찍는다.
## 칸 = 단계들 (예: 0,3,6 = 기본/중간/최대), 영웅 둘레에 잡몹 8마리 (움직이지 않음).
## godot --path . --resolution 720x1280 -s res://tools/shots/growth_shot.gd -- <영웅 id> <칸 tap|dash|charge|counter> <단계들 0,3,6> <시각 초> <출력 png>

const CROP := Rect2i(0, 240, 720, 800)

var main: Node
var player: Player
var caster: SkillCaster
var spawner: EnemySpawner


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var hero := args[0]
	var slot := {"tap": SkillCaster.Slot.TAP, "dash": SkillCaster.Slot.DASH, "charge": SkillCaster.Slot.CHARGE,
		"counter": SkillCaster.Slot.COUNTER}[args[1]] as SkillCaster.Slot
	var levels := args[2].split(",")
	var at := float(args[3])
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_settings.cfg"
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.stage_picked = true
	GameSettings.tutorial_done = true
	GameSettings.hero_picked = true
	GameSettings.opening_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.hero_id = StringName(hero)
	GameSettings.stage_id = {"yi_sun_sin": &"hansan_1592", "gwanggaeto": &"manchuria_395", "sejong": &"gyeongbokgung_1433",
		"shin_saimdang": &"chochungdo"}[hero]
	GameSettings.tutorial_enabled = false
	GameSettings.story_enabled = false
	GameSettings.enemy_hp_bars = false
	GameSettings.save_settings()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 200:
		await process_frame
	spawner = main.get_node("EnemySpawner") as EnemySpawner
	player = main.get_node("Player") as Player
	caster = player.get_node("SkillCaster") as SkillCaster
	if spawner.waves:
		spawner.waves.phase = WaveRunner.Phase.BOSS
	player.grant_invulnerability(9999.0)
	var def := caster.def_of(slot)
	var shots: Array[Image] = []
	for lv in levels:
		_ring(8)
		for i in 20:
			await physics_frame
		def.vfx_level = int(lv)
		player.facing = Vector2.UP
		caster.aim.active = true
		caster.aim.dir = Vector2.UP
		caster.reset_cooldown(slot)
		var t0 := Time.get_ticks_msec() / 1000.0
		caster.cast(slot, 1.0)
		while Time.get_ticks_msec() / 1000.0 - t0 < at:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var vk := img.get_width() / 720.0
		shots.append(img.get_region(Rect2i(Vector2i(Vector2(CROP.position) * vk), Vector2i(Vector2(CROP.size) * vk))))
		for k in 150:  # 다음 칸 전에 효과가 다 사라지게
			await process_frame
	var w := shots[0].get_width()
	var h := shots[0].get_height()
	var out := Image.create((w + 8) * shots.size(), h, false, shots[0].get_format())
	out.fill(Color.WHITE)
	for i in shots.size():
		out.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i(i * (w + 8), 0))
	out.save_png(args[4])
	quit()


## 영웅 둘레 n마리 (살아 있는 적이 n보다 적으면 채운다, 체력 넉넉히).
func _ring(n: int) -> void:
	var alive := 0
	for c in spawner.get_children():
		if c is Enemy and not (c as Enemy).health.is_dead():
			alive += 1
	var st: StageTheme = load("res://data/stages/%s.tres" % GameSettings.stage_id)
	var d: EnemyData = st.waves.waves[0].enemies[0] if st.waves else st.spawn_table[0]
	for i in maxi(n - alive, 0):
		var e := spawner.spawn_at(d, player.global_position + Vector2.from_angle(TAU * i / n) * 170.0)
		if e:
			e.speed_mult = 0.0
			e.health.max = 99999
			e.health.current = 99999
