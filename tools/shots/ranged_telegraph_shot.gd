extends SceneTree
## 원거리 예고 찍기: 실제 main 장면의 무대 바닥 위에 사수 여럿을 세우고, 예고 진행률 0.3 · 0.75 · 번쩍(마지막 순간)에 한 장씩.
## godot --path . --resolution 540x1000 -s res://tools/shots/ranged_telegraph_shot.gd -- <무대 id> <사수 tres 이름들(쉼표)> <출력 접두어(절대 경로)> [화면 밖 사수 1] [모양 0~2]


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_settings.cfg"
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.stage_picked = true
	GameSettings.stage_id = StringName(args[0])
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.tutorial_done = true
	GameSettings.tutorial_enabled = false
	GameSettings.hero_picked = true
	GameSettings.opening_seen = true
	GameSettings.story_enabled = false
	if args.size() > 4:
		RangedTelegraphData.default().style = int(args[4])
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	if main.run_stage_id() != StringName(args[0]):
		StageApply.stage(main, main.stage_by_id(StringName(args[0])))
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var player := main.get_node("Player") as Player
	await _wait(3.4)
	spawner.active = false  # 다른 적이 더 나오지 않게
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	player.grant_invulnerability(999.0)
	player.global_position = player.global_position  # 가만히
	var names: PackedStringArray = args[1].split(",")
	var far := args.size() > 3 and args[3] == "1"
	var shooters: Array[Enemy] = []
	for i in names.size():
		var d := load("res://data/enemies/%s.tres" % names[i]) as EnemyData
		var ang := deg_to_rad(-60.0 - 60.0 * i)
		var dist := 640.0 if (far and i == names.size() - 1) else 330.0 + 40.0 * i
		var e := spawner.spawn_at(d, player.global_position + Vector2.from_angle(ang) * dist)
		if e:
			shooters.append(e)
	for k in [0.15, 0.3, 0.75, 0.97]:
		await _until(shooters, k)
		_save("%s_k%d.png" % [args[2], int(k * 100)])
	quit()


func _until(shooters: Array[Enemy], k: float) -> void:
	var guard := 0
	while guard < 600:
		guard += 1
		await process_frame
		for e in shooters:
			if is_instance_valid(e) and e.attack and e.attack.state == EnemyAttack.State.WINDUP and e.attack.windup_ratio() >= k:
				return


func _wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout


func _save(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("[rt-shot] ", path)
