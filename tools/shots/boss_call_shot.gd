extends SceneTree
## 우두머리 대형 부르기 연속 캡처 (BossCalls): 우두머리를 세우고 체력을 40·25·10% 아래로 차례로 내려 부르는 모습을 찍는다.
## godot --path . --resolution 720x1280 -s res://tools/shots/boss_call_shot.gd -- <out 폴더> [무대 id] [영웅 id]

func _initialize() -> void:
	_run()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_settings_%d.cfg" % OS.get_process_id()
	var main: Node = await ShotStage.open(self, StringName(a[1] if a.size() > 1 else "hansan_1592"), StringName(a[2] if a.size() > 2 else "yi_sun_sin"))
	for i in 240:
		await process_frame
	var sp := main.get_node("EnemySpawner") as EnemySpawner
	var player := main.get_node("Player") as Player
	player.grant_invulnerability(9999.0)
	sp.waves.phase = WaveRunner.Phase.BOSS  # 물결은 멈추고 우두머리만
	sp.active = true
	var boss := sp.spawn_boss()
	var shot := 0
	for frac in [0.39, 0.24, 0.09]:
		for i in 60:
			await process_frame
			_skip_pick(main)
		boss.health.current = roundi(boss.health.max * frac)
		BossCalls.on_damaged(boss)
		print("CALL at %.2f formations %d" % [frac, sp.formations.size()])
		for i in 150:
			await process_frame
			_skip_pick(main)
			if i % 3 == 0:
				var img := root.get_texture().get_image()
				img.resize(360, 640, Image.INTERPOLATE_BILINEAR)
				img.save_png("%s/f_%04d.png" % [out, shot])
				shot += 1
	quit()


func _skip_pick(main: Node) -> void:
	var sc = main.get("seal_choice")
	if sc and sc.is_open():
		sc.pick(0)
