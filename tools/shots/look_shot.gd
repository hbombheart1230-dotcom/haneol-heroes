extends SceneTree
## 무대 조명(StageLook) 비교: 순신 + 왜군 몇 + 해룡참 고리를 한 화면에 세워 찍는다.
## godot --path . --resolution 540x1200 -s res://tools/shots/look_shot.gd -- <look .tres 경로 | none> <출력 png> [ring|plain] [카메라 확대, 0이면 무대 값] [무대 id]
## 폰 비율(논리 720×1680)로 보려면 --resolution 450x1050. 영웅 키 비율(화면 높이 대비)을 출력한다.
## none이면 무대 데이터 그대로 (지금 모습). plain이면 기술 없이 (바닥 측정용). 화톳불이 있으면 그 옆에 선다.

const SPOTS := [Vector2(-210, -150), Vector2(230, -90), Vector2(-160, 220), Vector2(250, 260), Vector2(30, -330)]


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
	GameSettings.stage_id = StringName(args[4]) if args.size() > 4 else &"hansan_1592"
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.tutorial_enabled = false
	GameSettings.show_stats = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	var arena := main.get_node("Arena") as Arena
	if args[0] != "none":
		var st := arena.theme.duplicate() as StageTheme
		st.look = load(args[0]) as StageLook
		arena.apply_theme(st)
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var player := main.get_node("Player") as Node2D
	var cam := player.get_node("Camera2D") as Camera2D
	if args.size() > 3 and float(args[3]) > 0.0:
		cam.zoom = Vector2.ONE * float(args[3])
		cam.set_meta(&"base_zoom", cam.zoom)
	for it in arena.props.items:  # 화톳불 빛이 화면에 들어오게 가장 가까운 화톳불 옆으로
		if it[1] == 2 and arena.theme.prop_textures[it[3]].resource_path.get_file() == "brazier.png":
			player.global_position = (it[0] as Vector2) + Vector2(-150 if it[0].x > 0 else 150, 160)
			break
	var list: Array = [spawner.spawn_table[0], spawner.spawn_table[0], spawner.spawn_table[1],
		spawner.spawn_table[0], spawner.spawn_table[2]]
	for i in list.size():
		var e: Node2D = spawner._spawn_special(list[i])
		e.global_position = player.global_position + SPOTS[i]
		e.set_physics_process(false)
	var end := Time.get_ticks_msec() + 3800  # 무대 이름 띠가 사라질 때까지
	while Time.get_ticks_msec() < end:
		await process_frame
	var caster := player.get_node("SkillCaster") as SkillCaster
	if args.size() < 3 or args[2] != "plain":
		caster.cast(SkillCaster.Slot.TAP)
	end = Time.get_ticks_msec() + 380
	while Time.get_ticks_msec() < end:
		await process_frame
	await RenderingServer.frame_post_draw
	var spr: AnimatedSprite2D = player.get_node("PlayerView")._sprite
	var body := spr.sprite_frames.get_frame_texture(&"idle" if spr.sprite_frames.has_animation(&"idle") else spr.animation, 0)
	var used := body.get_image().get_used_rect().size.y if body else 0
	print("HERO_HEIGHT %.3f (zoom %.3f)" % [used * spr.scale.y * cam.zoom.y / root.get_visible_rect().size.y, cam.zoom.y])
	root.get_texture().get_image().save_png(args[1])
	quit()
