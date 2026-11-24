extends SceneTree
## 만주 들불 연속 장면 띠: 풀밭 옆 잡몹 무리에 기술을 쓴다. 광개토 = 낙뢰가 불을 붙여 번지는 것,
## 순신 = 먼저 불을 놓고(불씨) 해일검기로 끄는 것.
## godot --path . --resolution 720x1280 -s res://tools/shots/fire_strip.gd -- <영웅 id> <출력 png>

const TIMES := [0.2, 1.0, 2.0, 3.0, 4.2, 5.4, 6.6, 8.0]
const CROP := Rect2i(0, 160, 720, 960)

var main: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var hero := args[0]
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_settings.cfg"
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.stage_picked = true
	GameSettings.tutorial_done = true
	GameSettings.hero_picked = true
	GameSettings.opening_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.hero_id = StringName(hero)
	GameSettings.stage_id = &"manchuria_395"
	GameSettings.tutorial_enabled = false
	GameSettings.story_enabled = false
	GameSettings.enemy_hp_bars = false
	GameSettings.want_stage_list = false  # 전장 목록을 열지 않고 바로 판
	GameSettings.save_settings()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 40:
		await process_frame
	(main.get_node("EnemySpawner") as EnemySpawner).active = false
	(main.get_node("Player") as Player).grant_invulnerability(9999.0)
	for i in 160:
		await process_frame
	if main.is_choosing():  # 판 앞 몇 초 사이 레벨이 올라 고르기가 열렸으면 첫 카드
		main.seal_choice.pick(0)
	paused = false
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var player := main.get_node("Player") as Player
	var arena := main.get_node("Arena") as Arena
	spawner.active = false
	for e in spawner.get_children():
		if e is Enemy:
			e.queue_free()
	var fire: GrassFire = arena.hazards.get_child(0) if arena.hazards.get_child_count() > 0 else null
	if fire == null:
		push_error("no fire")
		quit(1)
		return
	var patch := Vector2(fire.data.patches[3].x, fire.data.patches[3].y)
	player.global_position = patch + Vector2(-60, 330)
	player.grant_invulnerability(9999.0)
	var st: StageTheme = load("res://data/stages/manchuria_395.tres")
	var d: EnemyData = st.waves.waves[0].enemies[0] if st.waves else st.spawn_table[0]
	for i in 6:
		var e := spawner.spawn_at(d, patch + Vector2((i % 3 - 1) * 90.0, (i / 3) * 90.0 - 40.0))
		if e:
			e.speed_mult = 0.0
	for i in 10:
		await physics_frame
	var caster := player.get_node("SkillCaster") as SkillCaster
	caster.aim.active = true
	caster.aim.dir = Vector2.UP
	player.facing = Vector2.UP
	if hero == "yi_sun_sin":
		fire.grid.ignite(patch, 150.0)
	var t0 := Time.get_ticks_msec() / 1000.0
	var cast_at := 0.6 if hero == "gwanggaeto" else 2.4
	var cast_done := false
	var shots: Array[Image] = []
	for t in TIMES:
		while Time.get_ticks_msec() / 1000.0 - t0 < t:
			if not cast_done and Time.get_ticks_msec() / 1000.0 - t0 >= cast_at:
				cast_done = true
				caster.reset_cooldown(SkillCaster.Slot.CHARGE)
				caster.cast(SkillCaster.Slot.CHARGE, 1.0)
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var vk := img.get_width() / 720.0
		shots.append(img.get_region(Rect2i(Vector2i(Vector2(CROP.position) * vk), Vector2i(Vector2(CROP.size) * vk))))
	print("[fire-strip] %s" % str(fire.report()))
	var w := shots[0].get_width() / 2
	var h := shots[0].get_height() / 2
	var out := Image.create((w + 6) * 4, (h + 6) * 2, false, shots[0].get_format())
	out.fill(Color.WHITE)
	for i in shots.size():
		shots[i].resize(w, h)
		out.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i((i % 4) * (w + 6), (i / 4) * (h + 6)))
	out.save_png(args[1])
	quit()
