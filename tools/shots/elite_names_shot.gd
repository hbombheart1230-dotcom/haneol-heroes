extends SceneTree
## 중간 우두머리 셋 등장 띠 + 위쪽 체력 띠 이름 찍기: 실제 main 장면에서 무대의 우두머리 무리를 한꺼번에 세운다.
## godot --path . --resolution 540x1000 -s res://tools/shots/elite_names_shot.gd -- <무대 id> <출력 폴더 절대 경로>


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
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	if main.run_stage_id() != StringName(args[0]):  # 시작 흐름이 강제 무대를 지웠으면 직접 입힌다
		StageApply.stage(main, main.stage_by_id(StringName(args[0])))
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var player := main.get_node("Player") as Player
	await _wait(3.2)
	player.grant_invulnerability(999.0)
	var group: Array = []
	for w in spawner.waves.data.waves:
		if not (w as WaveData).elite_group.is_empty():
			group = (w as WaveData).elite_group
			break
	for i in group.size():
		var a := Vector2.from_angle(TAU * (i + 0.25) / group.size()) * 260.0
		var e := spawner.spawn_elite(player.global_position + a, group[i])
		e.set_physics_process(false)
	await _wait(1.0)
	_save(args[1] + "/" + args[0] + "_banner.png")
	await _wait(3.6)
	_save(args[1] + "/" + args[0] + "_bar.png")
	quit()


func _wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout


func _save(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("[elite-shot] ", path)
