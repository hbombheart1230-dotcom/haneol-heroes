extends SceneTree
## 전장 고르기 화면 시안: (가) 순신 처음 (한산만 열림, 나머지 곧 열림), (나) 한산을 이긴 뒤 — 명량·노량이 만들어졌다고
## 치고 (가짜 무대) 명량 열림·노량 잠김, (다) 사임당 자기 전장을 다 이겨 원정 열림.
## godot --path . -s res://tools/shots/stage_select_shot.gd -- <출력 폴더>


func _initialize() -> void:
	_run()


var sv: SubViewport


func _shot(path: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	sv.get_texture().get_image().save_png(path)


func _fake(id: StringName, title: String, year: String, sub: String) -> StageTheme:
	var st := StageTheme.new()
	st.id = id
	st.title = title
	st.year_label = year
	st.subtitle = sub
	return st


func _run() -> void:
	var dir: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://"
	sv = SubViewport.new()
	sv.size = Vector2i(720, 1280)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var screen := StageSelect.new()
	screen.size = Vector2(720, 1280)
	sv.add_child(screen)
	await process_frame
	var real: Array[StageTheme] = []
	for id in ["hansan_1592", "manchuria_395", "gyeongbokgung_1433", "chochungdo"]:
		real.append(load("res://data/stages/%s.tres" % id))
	var yi: HeroData = load("res://data/heroes/yi_sun_sin.tres")
	var saimdang: HeroData = load("res://data/heroes/shin_saimdang.tres")
	GameSettings.hero_clears = {}
	screen.open(yi, CampaignProgress.new(real, {}))
	await _shot(dir.path_join("stage_select_a.png"))
	var more := real.duplicate()
	more.append(_fake(&"myeongnyang_1597", "명량", "1597년", "열두 척으로 울돌목을 지킨다"))
	more.append(_fake(&"noryang_1598", "노량", "1598년", "마지막 바다"))
	GameSettings.hero_clears = {"yi_sun_sin": 1}
	screen.open(yi, CampaignProgress.new(more, {"yi_sun_sin": PackedStringArray(["hansan_1592"])}))
	await _shot(dir.path_join("stage_select_b.png"))
	GameSettings.hero_clears = {"shin_saimdang": 1}
	screen.open(saimdang, CampaignProgress.new(real, {"shin_saimdang": PackedStringArray(["chochungdo"])}))
	await _shot(dir.path_join("stage_select_c.png"))
	quit()
