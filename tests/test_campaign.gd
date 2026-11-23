extends GdUnitTestSuite
## 전장 목록 (CampaignProgress): 시간 순으로 앞을 이겨야 다음이 열림, 아직 없는 무대는 곧 열림,
## 자기 전장을 다 이기면 원정, 옛 저장(cleared_stages) 옮기기, 영웅별 이긴 기록 저장.

const HEROES := ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]


func _stages(ids: Array) -> Array[StageTheme]:
	var out: Array[StageTheme] = []
	for id in ids:
		var st := StageTheme.new()
		st.id = StringName(id)
		out.append(st)
	return out


func test_every_hero_has_three_slots_starting_at_home() -> void:
	for id: String in HEROES:
		var h: HeroData = load("res://data/heroes/%s.tres" % id)
		assert_object(h.campaign).override_failure_message(id).is_not_null()
		assert_int(h.campaign.slots.size()).is_greater_equal(3)
		assert_str(String(h.campaign.slots[0].id)).is_equal(String(h.home_stage))


func test_states_follow_the_timeline() -> void:
	var yi: HeroData = load("res://data/heroes/yi_sun_sin.tres")
	var ids := yi.campaign.ids()
	var p := CampaignProgress.new(_stages([ids[0], ids[1], ids[2]]), {})
	assert_int(p.state(yi, 0)).is_equal(CampaignProgress.State.OPEN)
	assert_int(p.state(yi, 1)).is_equal(CampaignProgress.State.LOCKED)
	p.cleared = {"yi_sun_sin": PackedStringArray([String(ids[0])])}
	assert_int(p.state(yi, 0)).is_equal(CampaignProgress.State.CLEARED)
	assert_int(p.state(yi, 1)).is_equal(CampaignProgress.State.OPEN)
	assert_int(p.state(yi, 2)).is_equal(CampaignProgress.State.LOCKED)
	assert_str(String(p.current(yi))).is_equal(String(ids[1]))
	assert_bool(p.expedition_open(yi)).is_false()
	p.cleared = {"yi_sun_sin": PackedStringArray([String(ids[0]), String(ids[1]), String(ids[2])])}
	assert_bool(p.expedition_open(yi)).is_true()
	assert_str(String(CampaignProgress.next_of(yi, ids[0]))).is_equal(String(ids[1]))
	assert_str(String(CampaignProgress.next_of(yi, ids[2]))).is_equal("")


func test_unbuilt_stages_are_coming_and_do_not_block_expedition() -> void:
	var yi: HeroData = load("res://data/heroes/yi_sun_sin.tres")
	var ids := yi.campaign.ids()
	var p := CampaignProgress.new(_stages([ids[0]]), {})
	assert_int(p.state(yi, 1)).is_equal(CampaignProgress.State.COMING)
	assert_bool(p.expedition_open(yi)).is_false()  # 아무것도 안 이김
	p.cleared = {"yi_sun_sin": PackedStringArray([String(ids[0])])}
	assert_bool(p.expedition_open(yi)).is_true()  # 만든 전장을 다 이김
	assert_bool(p.has_cleared(load("res://data/heroes/sejong.tres"), ids[0])).is_false()  # 기록은 영웅마다


func test_old_save_moves_to_the_owner_hero() -> void:
	var heroes: Array[HeroData] = []
	for id: String in HEROES:
		heroes.append(load("res://data/heroes/%s.tres" % id))
	var got := CampaignProgress.migrate(heroes, PackedStringArray(["hansan_1592", "chochungdo"]), {})
	assert_bool(PackedStringArray(got["yi_sun_sin"]).has("hansan_1592")).is_true()
	assert_bool(PackedStringArray(got["shin_saimdang"]).has("chochungdo")).is_true()
	assert_bool(got.has("sejong")).is_false()


func test_hero_cleared_is_saved_and_loaded() -> void:
	var path := GameSettings.test_path()
	GameSettings.hero_cleared = {}
	assert_bool(GameSettings.mark_hero_cleared(&"sejong", &"gyeongbokgung_1433")).is_true()
	assert_bool(GameSettings.mark_hero_cleared(&"sejong", &"gyeongbokgung_1433")).is_false()
	GameSettings.save_settings(path)
	GameSettings.hero_cleared = {}
	GameSettings.load_settings(path)
	assert_bool(PackedStringArray(GameSettings.hero_cleared.get("sejong", PackedStringArray())).has("gyeongbokgung_1433")).is_true()
	GameSettings.hero_cleared = {}


func test_records_keep_best_level_and_fastest_win() -> void:
	GameSettings.stage_records = {}
	GameSettings.record_run(&"sejong", &"gyeongbokgung_1433", 6, false, 120.0)
	GameSettings.record_run(&"sejong", &"gyeongbokgung_1433", 9, true, 250.0)
	GameSettings.record_run(&"sejong", &"gyeongbokgung_1433", 7, true, 230.0)
	var r := GameSettings.record_of(&"sejong", &"gyeongbokgung_1433")
	assert_int(int(r["level"])).is_equal(9)
	assert_float(float(r["time"])).is_equal(230.0)
	var sejong: HeroData = load("res://data/heroes/sejong.tres")
	assert_str(StageCardDrawer.record_line(sejong, &"gyeongbokgung_1433")).is_equal("가장 높은 경지 9  ·  가장 빨리 3:50")
	GameSettings.stage_records = {}


func test_result_buttons_are_two_and_separate() -> void:
	var v := Vector2(720, 1280)
	assert_bool(ResultDrawer.replay_rect(v).intersects(ResultDrawer.list_rect(v))).is_false()
	assert_str(String(RunEnd.action_at(v, ResultDrawer.list_rect(v).get_center()))).is_equal("list")
	assert_str(String(RunEnd.action_at(v, ResultDrawer.replay_rect(v).get_center()))).is_equal("replay")
	assert_str(String(RunEnd.action_at(v, Vector2(10, 10)))).is_equal("")


func test_stage_select_locks_coming_and_expedition_views_other_heroes() -> void:
	var yi: HeroData = load("res://data/heroes/yi_sun_sin.tres")
	var all: Array[HeroData] = []
	for id: String in HEROES:
		all.append(load("res://data/heroes/%s.tres" % id))
	var real: Array[StageTheme] = []
	for id in ["hansan_1592", "manchuria_395", "gyeongbokgung_1433", "chochungdo"]:
		real.append(load("res://data/stages/%s.tres" % id))
	var sel: StageSelect = auto_free(StageSelect.new())
	sel.size = Vector2(720, 1280)
	add_child(sel)
	var picked := []
	sel.stage_picked.connect(func(id: StringName) -> void: picked.append(id))
	sel.open(yi, CampaignProgress.new(real, {}), all)
	assert_bool(sel.highlight(0)).is_true()
	assert_bool(sel.press(1)).is_false()  # 곧 열림
	assert_bool(sel.press(-2)).is_false()  # 원정은 아직
	sel.open(yi, CampaignProgress.new(real, {"yi_sun_sin": PackedStringArray(["hansan_1592"])}), all)
	assert_bool(sel.highlight(0)).is_false()  # 이겼으면 더 빛나지 않는다
	assert_bool(sel.press(-2)).is_true()  # 만든 전장을 다 이김 → 원정
	assert_bool(sel.expedition).is_true()
	assert_object(sel.view_hero).is_not_same(yi)
	var other: StringName = sel.view_hero.campaign.slots[0].id
	assert_bool(sel.press(0)).is_true()  # 다른 영웅의 첫 전장을 지금 영웅으로
	assert_str(String(picked[0])).is_equal(String(other))
