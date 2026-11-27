extends SceneTree
## 순신 4번 해일검기를 다 모아 놓은 뒤 0.2·0.4·0.6초(HH_TIMES)에 한 장씩 (빠르기 비교).
## godot --path . --resolution 540x960 -s res://tools/shots/haeil_speed_shot.gd -- <출력 접두어(절대 경로)> [충전=1.0]
## 환경 HH_TIMES=0.05,0.1,0.15 (찍는 순간), HH_POWER=<값>이면 speed_size_power를 그 값으로 (0 = 예전 빠르기).


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var c := float(args[1]) if args.size() > 1 else 1.0
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_settings_%d.cfg" % OS.get_process_id()
	ShotStage.skip_menus(&"hansan_1592", &"yi_sun_sin")
	GameSettings.save_settings(GameSettings.settings_path)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var player := main.get_node("Player") as Player
	await create_timer(2.0, true, false, true).timeout
	spawner.active = false
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	player.grant_invulnerability(999.0)
	player.facing = Vector2.UP
	var caster := player.get_node("SkillCaster") as SkillCaster
	var def := caster.kit.charge as HaeilSkill
	if OS.get_environment("HH_POWER") != "":
		def.speed_size_power = float(OS.get_environment("HH_POWER"))
	await process_frame
	caster.cast(SkillCaster.Slot.CHARGE, c)
	var t0 := Time.get_ticks_msec()
	var times := [0.2, 0.4, 0.6]
	if OS.get_environment("HH_TIMES") != "":
		times = Array(OS.get_environment("HH_TIMES").split(",")).map(func(x: String) -> float: return float(x))
	for at in times:
		while (Time.get_ticks_msec() - t0) / 1000.0 < at:
			await process_frame
		root.get_texture().get_image().save_png("%s_t%03d.png" % [args[0], roundi(at * 1000)])
	print("[haeil-shot] power %.2f speed %.0f" % [def.speed_size_power, def.speed_at(c)])
	quit()
