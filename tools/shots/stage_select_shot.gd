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
	var gear := SettingsButton.new()  # 오른쪽 위 톱니 (영웅 바꾸기와 겹치지 않는지 보이게)
	gear.size = Vector2(720, 1280)
	var ss := SettingsScreen.new()
	ss.visible = false
	gear.screen = ss
	sv.add_child(gear)
	await process_frame
	var real: Array[StageTheme] = []
	for id in ["hansan_1592", "manchuria_395", "gyeongbokgung_1433", "chochungdo"]:
		real.append(load("res://data/stages/%s.tres" % id))
	var yi: HeroData = load("res://data/heroes/yi_sun_sin.tres")
	var saimdang: HeroData = load("res://data/heroes/shin_saimdang.tres")
	var all: Array[HeroData] = []
	for id in ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]:
		all.append(load("res://data/heroes/%s.tres" % id))
	GameSettings.hero_clears = {}
	GameSettings.hero_cleared = {}
	screen.open(yi, CampaignProgress.new(real, {}), all)
	await _shot(dir.path_join("stage_select_a.png"))
	var more := real.duplicate()
	more.append(_fake(&"myeongnyang_1597", "명량", "1597년", "열두 척으로 울돌목을 지킨다"))
	more.append(_fake(&"noryang_1598", "노량", "1598년", "마지막 바다"))
	GameSettings.hero_clears = {"yi_sun_sin": 1}
	GameSettings.hero_cleared = {"yi_sun_sin": PackedStringArray(["hansan_1592"])}
	GameSettings.stage_records = {"yi_sun_sin/hansan_1592": {"level": 11, "time": 231.0}, "yi_sun_sin/myeongnyang_1597": {"level": 6, "time": 0.0}}
	screen.open(yi, CampaignProgress.new(more, {"yi_sun_sin": PackedStringArray(["hansan_1592"])}), all)
	await _shot(dir.path_join("stage_select_b.png"))
	GameSettings.hero_clears = {"shin_saimdang": 1}
	GameSettings.hero_cleared = {"shin_saimdang": PackedStringArray(["chochungdo"])}
	screen.open(saimdang, CampaignProgress.new(real, {"shin_saimdang": PackedStringArray(["chochungdo"])}), all)
	await _shot(dir.path_join("stage_select_c.png"))
	screen.press(-2)  # 원정: 다른 영웅(순신)의 전장을 사임당으로
	await _shot(dir.path_join("stage_select_d.png"))
	GameSettings.stage_records = {}
	GameSettings.hero_cleared = {}
	quit()
