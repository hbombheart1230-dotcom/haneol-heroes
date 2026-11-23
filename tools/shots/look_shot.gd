extends SceneTree
## 무대 조명(StageLook) 비교: 순신 + 왜군 몇 + 해룡참 고리를 한 화면에 세워 찍는다.
## godot --path . --resolution 540x1200 -s res://tools/shots/look_shot.gd -- <look .tres 경로 | none | off> <출력 png> [ring|plain] [카메라 확대, 0이면 무대 값] [무대 id]
## 폰 비율(논리 720×1680)로 보려면 --resolution 450x1050. 영웅 키 비율(화면 높이 대비)을 출력한다.
## none이면 무대 데이터 그대로 (지금 모습). plain이면 기술 없이 (바닥 측정용), 아니면 무대 주인공의 탭 기술. 화톳불이 있으면 그 옆에 선다.

const HERO := {"hansan_1592": "yi_sun_sin", "manchuria_395": "gwanggaeto", "gyeongbokgung_1433": "sejong",
	"chochungdo": "shin_saimdang"}
const SPOTS := [Vector2(-210, -150), Vector2(230, -90), Vector2(-160, 220), Vector2(250, 260), Vector2(30, -330)]


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	GameSettings.settings_path = OS.get_user_data_dir() + "/look_shot_settings.cfg"  # 저장된 영웅·무대를 읽지 않게 빈 설정
	DirAccess.remove_absolute(GameSettings.settings_path)
	GameSettings.hero_picked = true
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.stage_picked = true
	var stage_id := StringName(args[4]) if args.size() > 4 else &"hansan_1592"
	GameSettings.stage_id = stage_id
	GameSettings.hero_id = StringName(HERO.get(String(stage_id), "yi_sun_sin"))  # 무대 주인공으로 시작 (스킬·단추까지)
	GameSettings.tutorial_enabled = false
	GameSettings.show_stats = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	var arena := main.get_node("Arena") as Arena
	if arena.theme == null or arena.theme.id != stage_id:  # 저장된 설정이 무대를 바꿨으면 되돌린다
		StageApply.stage(main, load("res://data/stages/%s.tres" % stage_id))
		await process_frame
	if args[0] != "none":  # off = 조명 없는 예전 모습 (확대 1, 비네트 없음)
		var st := arena.theme.duplicate() as StageTheme
		st.look = null if args[0] == "off" else load(args[0]) as StageLook
		if args[0] == "off":
			st.camera_zoom = 1.0
			st.vignette = 0.0
		arena.apply_theme(st)
		arena.clamp_camera(main.get_node("Player/Camera2D") as Camera2D)
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var player := main.get_node("Player") as Node2D
	if (player as Player).hero.id != GameSettings.hero_id:
		push_warning("look_shot: hero %s, wanted %s" % [(player as Player).hero.id, GameSettings.hero_id])
	var cam := player.get_node("Camera2D") as Camera2D
	if args.size() > 3 and float(args[3]) > 0.0:
		cam.zoom = Vector2.ONE * float(args[3])
		cam.set_meta(&"base_zoom", cam.zoom)
	for it in arena.props.items:  # 소품 빛(화톳불·석등)이 화면에 들어오게 그 옆으로
		var lit := arena.theme.look.lit_props if arena.theme.look else PackedStringArray(["brazier"])
		if it[1] == 2 and lit.has(arena.theme.prop_textures[it[3]].resource_path.get_file().get_basename()):
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
