extends SceneTree
## 잡몹 떼 장면 찍기 (PC): 실제 main 장면에서 적 N마리를 영웅 둘레에 세우고 영웅이 탭 연타로 싸우는 동안 몇 장 찍는다.
## 예고 원이 화면을 덮는지·도깨비불이 어떻게 보이는지 확인용. 적은 죽으면 다시 채운다.
## godot --path . --resolution 720x1280 -s res://tools/perf/swarm_shot.gd -- <출력 접두사> [무대 id] [N] [적 id]

const SHOTS := [1.5, 3.0, 4.5]


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "user://swarm"
	var stage := StringName(args[1] if args.size() > 1 else "hansan_1592")
	var n := int(args[2]) if args.size() > 2 else 14
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_settings.cfg"
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.stage_picked = true
	GameSettings.tutorial_done = true
	GameSettings.hero_picked = true
	GameSettings.opening_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.stage_id = stage
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.tutorial_enabled = false
	GameSettings.story_enabled = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var player := main.get_node("Player") as Player
	var caster := player.get_node_or_null("SkillCaster") as SkillCaster
	if spawner.waves:
		spawner.waves.phase = WaveRunner.Phase.BOSS
	var st: StageTheme = load("res://data/stages/%s.tres" % stage)
	var d: EnemyData = load("res://data/enemies/%s.tres" % args[3]) if args.size() > 3 else st.waves.waves[0].enemies[0]
	for i in 200:  # 무대 제목 띠
		await process_frame
	player.grant_invulnerability(9999.0)
	var t := 0.0
	var tap := 0.0
	var k := 0
	while k < SHOTS.size():
		var alive := 0
		for c in spawner.get_children():
			if c is Enemy and not (c as Enemy).health.is_dead():
				alive += 1
		for i in maxi(n - alive, 0):
			spawner.spawn_at(d, player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(140.0, 300.0))
		tap -= 1.0 / 60.0
		if caster and tap <= 0.0:
			tap = 0.25
			caster.combo_tap()
		await process_frame
		t += 1.0 / 60.0
		if t >= SHOTS[k]:
			var img := root.get_viewport().get_texture().get_image()
			var path := "%s_%d.png" % [prefix, k]
			img.save_png(path)
			print("[swarm-shot] ", path, " windups ", EnemyAttack.active_windups)
			k += 1
	quit()
