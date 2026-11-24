extends SceneTree
## 기술 하나가 잡몹 무리에 들어가는 연속 장면 띠 (전·후 비교용: 예전 코드에서도 돈다). 실제 main 장면, 영웅 둘레·앞에 잡몹 n마리.
## godot --path . --resolution 720x1280 -s res://tools/shots/burst_strip.gd -- <영웅 id> <칸 tap|dash|charge|counter> <충전 0~1> <출력 png> [속성=값 ...]
## 예: yi_sun_sin counter 0 out.png radial_blades=8  /  gwanggaeto charge 1 out.png chain_count=2

const TIMES := [0.05, 0.12, 0.2, 0.28, 0.38, 0.5, 0.64, 0.8]
const CROP := Rect2i(0, 200, 720, 880)
const STAGES := {"yi_sun_sin": &"hansan_1592", "gwanggaeto": &"manchuria_395", "sejong": &"gyeongbokgung_1433",
	"shin_saimdang": &"chochungdo"}

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
	var charge := float(args[2])
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_settings.cfg"
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.stage_picked = true
	GameSettings.tutorial_done = true
	GameSettings.hero_picked = true
	GameSettings.opening_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.hero_id = StringName(hero)
	GameSettings.stage_id = STAGES[hero]
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
	for kv in args.slice(4):  # 큰 강화 등 속성 덮어쓰기
		var p := (kv as String).split("=")
		def.set(p[0], type_convert(p[1], typeof(def.get(p[0]))))
	var st: StageTheme = load("res://data/stages/%s.tres" % STAGES[hero])
	var d: EnemyData = st.waves.waves[0].enemies[0] if st.waves else st.spawn_table[0]
	for i in 10:  # 둘레 6 + 앞쪽 4
		var at := player.global_position + (Vector2.from_angle(TAU * i / 6.0) * 140.0 if i < 6 else Vector2((i - 7.5) * 70.0, -260.0))
		var e := spawner.spawn_at(d, at)
		if e:
			e.speed_mult = 0.0
	for i in 15:
		await physics_frame
	player.facing = Vector2.UP
	caster.aim.active = true
	caster.aim.dir = Vector2.UP
	caster.reset_cooldown(slot)
	var t0 := Time.get_ticks_msec() / 1000.0
	caster.cast(slot, charge)
	var shots: Array[Image] = []
	for t in TIMES:
		while Time.get_ticks_msec() / 1000.0 - t0 < t:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var vk := img.get_width() / 720.0
		shots.append(img.get_region(Rect2i(Vector2i(Vector2(CROP.position) * vk), Vector2i(Vector2(CROP.size) * vk))))
	var w := shots[0].get_width() / 2
	var h := shots[0].get_height() / 2
	var out := Image.create((w + 6) * 4, (h + 6) * 2, false, shots[0].get_format())
	out.fill(Color.WHITE)
	for i in shots.size():
		shots[i].resize(w, h)
		out.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i((i % 4) * (w + 6), (i / 4) * (h + 6)))
	out.save_png(args[3])
	quit()
