extends SceneTree
## 우두머리·중간 우두머리 크기 비교 (EnemyAIData.boss_size_mult·mid_boss_size_mult): 무대마다 우두머리·중간 우두머리 하나·졸 셋을
## 영웅 옆에 세우고 우두머리 배율마다 한 장씩 찍는다 (폰 비율, 중간 우두머리는 데이터 값 그대로).
## godot --path . --resolution 720x1280 -s res://tools/shots/boss_size_shot.gd -- <out 폴더> <무대 id> [배율...]

var main: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var stage := StringName(a[1] if a.size() > 1 else "hansan_1592")
	var mults: Array = Array(a.slice(2)).map(func(x: String) -> float: return float(x)) if a.size() > 2 else [1.0, 1.2, 1.3, 1.5]
	DirAccess.make_dir_recursive_absolute(out)
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_settings_%d.cfg" % OS.get_process_id()
	main = await ShotStage.open(self, stage, &"yi_sun_sin")
	for i in 420:
		await process_frame
	var st: StageTheme = main.run_config.stage
	var sp := main.get_node("EnemySpawner") as EnemySpawner
	var player := main.get_node("Player") as Player
	player.grant_invulnerability(9999.0)
	var at := player.global_position
	var mid: EnemyData = st.waves.waves[2].elite_group[0] if not st.waves.waves[2].elite_group.is_empty() else st.elite
	var trash: EnemyData = st.waves.waves[0].enemies[0]
	for m in mults:
		for e in sp.get_children():
			if e is Enemy:
				e.free()
		Enemy.ai_data().boss_size_mult = m
		var list: Array = [sp.spawn_at(st.boss, at + Vector2(60, -250)), sp.spawn_at(mid, at + Vector2(-200, -90))]
		for k in 3:
			list.append(sp.spawn_at(trash, at + Vector2(150 + k * 70, -60 + k * 30)))
		for e in list:
			if e:
				(e as Enemy).set_physics_process(false)
				(e as Enemy).target = null
		for i in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s_%.1f.png" % [out, stage, m])
		print("SHOT %s %.1f" % [stage, m])
	quit()
