extends SceneTree
## 무대 장치 한 번(예고 → 발동)의 연속 장면 띠. 실제 main 장면, 영웅 둘레·앞에 잡몹, 장치 박자를 당겨 바로 예고.
## godot --path . --resolution 720x1280 -s res://tools/shots/hazard_strip.gd -- <영웅 id> <무대 id> <출력 png> [hero_in_lane]
## 예: yi_sun_sin hansan_1592 out.png

const TIMES := [0.05, 0.4, 0.8, 1.15, 1.25, 1.35, 1.55, 1.9]
const CROP := Rect2i(0, 160, 720, 960)

var main: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var hero := args[0]
	var stage := args[1]
	var hero_in_lane := args.size() > 3 and args[3] == "hero_in_lane"
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_settings.cfg"
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.stage_picked = true
	GameSettings.tutorial_done = true
	GameSettings.hero_picked = true
	GameSettings.opening_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.hero_id = StringName(hero)
	GameSettings.stage_id = StringName(stage)
	GameSettings.tutorial_enabled = false
	GameSettings.story_enabled = false
	GameSettings.enemy_hp_bars = false
	GameSettings.save_settings()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 200:
		await process_frame
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var player := main.get_node("Player") as Player
	var arena := main.get_node("Arena") as Arena
	if spawner.waves:
		spawner.waves.phase = WaveRunner.Phase.RUN
	spawner.active = false
	var lane: LaneStrike = arena.hazards.get_child(0) if arena.hazards.get_child_count() > 0 else null
	if lane == null:
		push_error("no hazard on stage %s" % stage)
		quit(1)
		return
	var row := lane.data.rows[2]
	player.global_position = Vector2(0, row.x + (0.0 if hero_in_lane else 220.0))
	var st: StageTheme = load("res://data/stages/%s.tres" % stage)
	var d: EnemyData = st.waves.waves[0].enemies[0] if st.waves else st.spawn_table[0]
	for i in 9:  # 줄 위 5 + 줄 밖 4
		var at := Vector2((i - 2) * 150.0, row.x) if i < 5 else Vector2((i - 6.5) * 170.0, row.x - 190.0)
		var e := spawner.spawn_at(d, at)
		if e:
			e.speed_mult = 0.0
	for i in 20:
		await physics_frame
	lane.clock.wait = 0.0  # 다음 물리 틀에 예고 시작
	var t0 := Time.get_ticks_msec() / 1000.0
	var shots: Array[Image] = []
	for t in TIMES:
		while Time.get_ticks_msec() / 1000.0 - t0 < t:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var vk := img.get_width() / 720.0
		shots.append(img.get_region(Rect2i(Vector2i(Vector2(CROP.position) * vk), Vector2i(Vector2(CROP.size) * vk))))
	print("[hazard-strip] row=%d enemy_hits=%d hero_hit=%s" % [lane.row, lane.last_enemy_hits, lane.last_hero_hit])
	var w := shots[0].get_width() / 2
	var h := shots[0].get_height() / 2
	var out := Image.create((w + 6) * 4, (h + 6) * 2, false, shots[0].get_format())
	out.fill(Color.WHITE)
	for i in shots.size():
		shots[i].resize(w, h)
		out.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i((i % 4) * (w + 6), (i / 4) * (h + 6)))
	out.save_png(args[2])
	quit()
