extends SceneTree
## 영웅 대사 장면 사진 (1080×1920): 네 영웅이 자기 전장에 들어설 때, 순신 원정, 우두머리 앞(광개토), 쓰러졌을 때(세종, 결과 판 위).
## godot --path . -s res://tools/shots/hero_lines_shot.gd -- <출력 폴더>

var out := "user://lines"
var sv: SubViewport
var cur: Node


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if not a.is_empty():
		out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	sv = SubViewport.new()
	sv.size = Vector2i(1080, 1920)
	sv.size_2d_override = Vector2i(720, 1280)
	sv.size_2d_override_stretch = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	_run()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	sv.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("shot ", name)


func _open(hero: StringName, stage: StringName = &"") -> Node:
	GameSettings.hero_id = hero
	GameSettings.stage_picked = stage != &""
	GameSettings.stage_id = stage
	GameSettings.save_settings()
	if cur:
		paused = false
		cur.free()
	cur = load("res://scenes/main.tscn").instantiate()
	sv.add_child(cur)
	await _wait(5)
	cur.player.health.damageable = false
	return cur


## 대사가 뜰 때까지 기다렸다가 (조금 떠오른 뒤) 찍는다.
func _until_line(m: Node, name: String) -> void:
	for i in 600:
		if m.hero_lines.text != "" and m.hero_lines.alpha() > 0.9:
			break
		await process_frame
	await _wait(10)
	await _shot(name)


func _run() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.opening_seen = true
	GameSettings.title_seen = true
	GameSettings.hero_picked = true
	GameSettings.want_stage_list = false
	GameSettings.story_enabled = true
	GameSettings.tutorial_enabled = false
	GameSettings.tutorial_done = true
	for h in [&"yi_sun_sin", &"gwanggaeto", &"sejong", &"shin_saimdang"]:
		await _until_line(await _open(h), "enter_" + String(h))
	await _until_line(await _open(&"yi_sun_sin", &"manchuria_395"), "away_yi_sun_sin")
	var m := await _open(&"gwanggaeto")
	await _until_line(m, "skip")
	m.hero_lines.step(m.hero_lines.show_time)
	m.spawner.spawn_boss()
	await _until_line(m, "boss_gwanggaeto")
	m = await _open(&"sejong")
	await _until_line(m, "skip")
	m.hero_lines.step(m.hero_lines.show_time)
	m.player.health.damageable = true
	m.state.player_died()
	await _until_line(m, "defeat_sejong")
	DirAccess.remove_absolute(out.path_join("skip.png"))
	quit()
