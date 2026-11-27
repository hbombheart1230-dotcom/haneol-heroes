extends SceneTree
## 우두머리 크기 확인 (EnemyAIData.boss_size_mult): 실제 판에서 우두머리를 세우고 (한산은 대장선 구역·누각 계단 자리)
## 영웅이 가만히 서 있을 때 20초 동안 — 몸이 걸을 곳 안에 있는지, 영웅과 가장 가까운 거리, 영웅이 받은 피해 횟수.
## godot --path . --resolution 720x1280 -s res://tools/probe/boss_fit_probe.gd -- <무대 id> <배율>

func _initialize() -> void:
	_run()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var stage := StringName(a[0])
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_settings_%d.cfg" % OS.get_process_id()
	var main: Node = await ShotStage.open(self, stage, &"yi_sun_sin")
	for i in 240:
		await process_frame
	Enemy.ai_data().boss_size_mult = float(a[1])
	var sp := main.get_node("EnemySpawner") as EnemySpawner
	var player := main.get_node("Player") as Player
	player.health.max = 999999
	player.health.current = 999999
	var zh: ZoneHop = null
	for n in main.find_children("*", "ZoneHop", true, false):
		zh = n
	var st: StageTheme = main.run_config.stage
	if zh and not st.zones.is_empty():
		var z: ZoneData = st.zones[st.zones.size() - 1]
		zh.plan.current = st.zones.size() - 1
		zh._apply(z, true)
		player.global_position = z.entry
	sp.waves.phase = WaveRunner.Phase.BOSS
	sp.active = true
	var boss := sp.spawn_boss()
	var area: PackedVector2Array = sp.walk_area
	var out_frames := 0
	var min_d := INF
	var hits := 0
	var last_hp := player.health.current
	var p0 := player.global_position
	for i in 1200:
		await physics_frame
		if not is_instance_valid(boss):
			break
		if area.size() >= 3 and not Geometry2D.is_point_in_polygon(boss.global_position, area):
			out_frames += 1
		min_d = minf(min_d, boss.global_position.distance_to(player.global_position))
		if player.health.current < last_hp:
			hits += 1
		last_hp = player.health.current
	print("FIT %s x%.1f start %s body %.0f | out-of-area frames %d | closest %.0f | hero hits %d | hero moved %.0f" % [stage, float(a[1]), str(sp.boss_point), boss.body_radius * boss.size_mult, out_frames, min_d, hits, player.global_position.distance_to(p0)])
	quit()
