extends SceneTree
## 무대마다 적을 플레이어 둘레에 세워 놓고 화면을 찍는다 (적 가독성 비교용).
## godot --path . --resolution 540x960 -s res://tools/shots/stage_shot.gd -- <무대 id> <출력 png 절대 경로>

func _initialize() -> void:
	_run()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_settings.cfg"
	GameSettings.hero_picked = true
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.stage_picked = true
	GameSettings.stage_id = StringName(args[0])
	GameSettings.hero_id = &"sejong"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var player := main.get_node("Player") as Node2D
	var list: Array = []
	for d in spawner.spawn_table:
		list.append(d)
	if spawner.elite_data: list.append(spawner.elite_data)
	if spawner.boss_data: list.append(spawner.boss_data)
	var n := list.size()
	for i in n:
		var e := spawner._spawn_special(list[i]) if spawner.has_method("_spawn_special") else spawner.spawn_one()
		var a := TAU * i / n
		e.global_position = player.global_position + Vector2(cos(a) * 230, sin(a) * 300)
		e.set_physics_process(false)
	var end := Time.get_ticks_msec() + 4500
	while Time.get_ticks_msec() < end:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[1])
	quit()
