extends SceneTree
## 부르기 단추 자리 확인: 원정 전장에서 우두머리 이름 띠·경지 오름·행동 점수·단추 안내 줄이 한꺼번에 떠 있는 순간을 찍는다.
## 단추 누름 영역(반지름 + 12px)은 하늘색 테로 덧그린다 (게임 그림 아님).
## godot --path . -s res://tools/shots/summon_button_layout_shot.gd -- <출력 png> <게임 폭>x<게임 높이> [고른 영웅] [전장]
## (창이 화면보다 커도 되게 그 크기 SubViewport에 판을 띄운다 = aspect expand 뒤 게임 좌표 크기.)
## 화면 비율: 세로 9:16 720x1280, S20 9:20 720x1600, 폴드 7 펼침 (≈1968x2184) 1151x1280 (aspect expand로 폭이 늘어남).

var main: Node
var sv: SubViewport


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://summon_layout.png"
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_settings.cfg"
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.stage_picked = true
	GameSettings.tutorial_done = true
	GameSettings.hero_picked = true
	GameSettings.opening_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	var wh: PackedStringArray = (args[1] if args.size() > 1 else "720x1280").split("x")
	GameSettings.hero_id = StringName(args[2] if args.size() > 2 else "sejong")
	GameSettings.stage_id = StringName(args[3] if args.size() > 3 else "hansan_1592")
	GameSettings.tutorial_enabled = false
	GameSettings.story_enabled = true
	GameSettings.want_stage_list = false
	GameSettings.save_settings()
	main = load("res://scenes/main.tscn").instantiate()
	sv = SubViewport.new()
	sv.size = Vector2i(int(wh[0]), int(wh[1]))
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	sv.add_child(main)
	for i in 40:
		await process_frame
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var player := main.get_node("Player") as Player
	spawner.active = false
	player.grant_invulnerability(9999.0)
	for i in 160:
		await process_frame
	if main.is_choosing():
		main.seal_choice.pick(0)
	paused = false
	var button: HomeSummonButton = null
	for c in main.hud.get_children():
		if c is HomeSummonButton:
			button = c
	if button == null or not button.rules.active():
		push_error("no summon button")
		quit(1)
		return
	main.state.elapsed = 74.0
	var boss := spawner.spawn_boss()  # 우두머리 이름 띠 + 단추 안내 "한 번 더"
	boss.speed_mult = 0.0
	for i in 40:
		await process_frame
	main.progress.add_xp(main.progress.xp_to_next() - 4)
	main.progress.add_xp(2, &"combo")
	main.progress.add_xp(4, &"counter")  # 경지 오름 + 행동 점수
	for i in 8:
		await process_frame
	var ring := _TouchRing.new()
	ring.button = button
	main.hud.add_child(ring)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	sv.get_texture().get_image().save_png(out)
	var vp := button.get_viewport_rect().size
	print("[summon-layout] vp %s  button center %s r %.0f  badge bottom %.0f" % [vp, button.center(),
		button.data.button_radius, HeroBadge.BOTTOM])
	quit()


class _TouchRing extends Control:
	var button: HomeSummonButton

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_arc(button.center(), button.data.button_radius + 12.0, 0.0, TAU, 48, Color(0.3, 0.9, 1.0, 0.9), 2.0)
