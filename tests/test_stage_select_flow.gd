extends GdUnitTestSuite
## 전장 목록 (#106 다듬기, 사용자 2026-11-24 "영웅 선택은 할 수 있게 해 줘. 그 다음에 자기 거를 깨야 원정을 갈 수 있게"):
## 영웅 바꾸기 단추는 아래 줄 (톱니와 안 겹침, 한 손 자리), 다시 켜서 전장 목록에서 바로 영웅을 바꿀 수 있음,
## 원정은 영웅마다 자기 전장(HeroCampaign.expedition_needs, 만든 것만)을 이기면 열림, 잠기면 까닭 한 줄.

const HEROES := ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]
const STAGES := ["hansan_1592", "manchuria_395", "gyeongbokgung_1433", "chochungdo"]


func after_test() -> void:
	GameSettings.want_stage_list = false


func _real() -> Array[StageTheme]:
	var out: Array[StageTheme] = []
	for id in STAGES:
		out.append(load("res://data/stages/%s.tres" % id))
	return out


func _all() -> Array[HeroData]:
	var out: Array[HeroData] = []
	for id in HEROES:
		out.append(load("res://data/heroes/%s.tres" % id))
	return out


func _fake(id: StringName, title: String) -> StageTheme:
	var st := StageTheme.new()
	st.id = id
	st.title = title
	return st


func test_expedition_opens_on_own_stages_and_says_why_not() -> void:
	var yi: HeroData = load("res://data/heroes/yi_sun_sin.tres")
	var p := CampaignProgress.new(_real(), {})
	assert_bool(p.expedition_open(yi)).is_false()
	assert_str(p.expedition_reason(yi)).is_equal("순신의 전장(한산도)을 먼저 깨야 합니다")
	assert_bool(CampaignProgress.new(_real(), {"gwanggaeto": PackedStringArray(["hansan_1592"])}).expedition_open(yi)).is_false()  # 남의 기록은 안 셈
	p = CampaignProgress.new(_real(), {"yi_sun_sin": PackedStringArray(["hansan_1592"])})
	assert_bool(p.expedition_open(yi)).is_true()  # 지금은 자기 전장 하나 (명량·노량은 곧 열림)
	assert_str(p.expedition_reason(yi)).is_equal("")
	# 셋이 다 만들어지면 셋을 다 이겨야
	var more := _real()
	more.append(_fake(&"myeongnyang_1597", "명량"))
	more.append(_fake(&"noryang_1598", "노량"))
	p = CampaignProgress.new(more, {"yi_sun_sin": PackedStringArray(["hansan_1592"])})
	assert_bool(p.expedition_open(yi)).is_false()
	assert_str(p.expedition_reason(yi)).is_equal("순신의 전장(명량·노량)을 먼저 깨야 합니다")
	var c := yi.campaign.duplicate() as HeroCampaign  # 데이터로: 앞 하나만 이기면 열리게
	c.expedition_needs = 1
	var yi1 := yi.duplicate() as HeroData
	yi1.campaign = c
	assert_bool(p.expedition_open(yi1)).is_true()


func test_buttons_sit_low_and_clear_of_the_gear() -> void:
	for vp in [Vector2(720, 1280), Vector2(720, 1600)]:
		var sel: StageSelect = auto_free(StageSelect.new())
		sel.size = vp
		add_child(sel)
		sel.open(load("res://data/heroes/yi_sun_sin.tres"), CampaignProgress.new(_real(), {}), _all())
		var gear := Vector2(vp.x - 52.0, 112.0)
		var ch := sel.change_rect()
		var near := Vector2(clampf(gear.x, ch.position.x, ch.end.x), clampf(gear.y, ch.position.y, ch.end.y))
		assert_float(near.distance_to(gear)).is_greater(34.0 + 14.0)  # 톱니 누름 원 밖
		assert_float(ch.position.y).is_greater(vp.y / 3.0)  # 엄지 자리 (아래 2/3)
		assert_bool(ch.intersects(sel.expedition_rect())).is_false()
		for i in sel.slot_count():
			assert_bool(ch.intersects(sel.card_rect(i))).is_false()
		assert_float(ch.end.x).is_less_equal(vp.x)
		assert_float(sel.expedition_rect().end.x).is_less_equal(vp.x - 23.0)


func test_locked_reason_fits_the_expedition_button() -> void:
	var sel: StageSelect = auto_free(StageSelect.new())
	sel.size = Vector2(720, 1280)
	add_child(sel)
	var p := CampaignProgress.new(_real(), {})
	for h in _all():
		sel.open(h, p, _all())
		var line := sel.locked_line()
		assert_str(line).contains(h.display_name)
		var w := UiStyle.BODY_FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, StageSelect.SUB_PX).x
		assert_float(w).override_failure_message(line).is_less_equal(sel.expedition_rect().size.x - 16.0)


## 다시 켜면 마지막 영웅의 전장 목록 → "영웅 바꾸기" → 영웅 고르기 (네 영웅 모두 고를 수 있음) → 고른 영웅의 전장 목록.
func test_relaunch_list_can_change_hero() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.intro_seen = true
	GameSettings.tutorial_done = true
	GameSettings.story_enabled = false
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.hero_picked = true  # 입장 뒤 마지막 영웅 (StartFlow._on_title_entered)
	GameSettings.want_stage_list = true
	GameSettings.save_settings()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var sel: StageSelect = main.stage_select
	assert_bool(sel.is_open()).is_true()
	assert_str(String(sel.hero.id)).is_equal("yi_sun_sin")
	var c := sel.change_rect().get_center()
	assert_bool((main.get_node("HUD/SettingsButton") as SettingsButton).is_on(c)).is_false()  # 톱니가 먼저 가로채지 않음
	sel.handle_touch(0, c, true)
	sel.handle_touch(0, c, false)
	var hs: HeroSelect = main.hero_select
	assert_bool(hs.is_open()).is_true()
	for h in hs.heroes:
		assert_bool(h.playable).override_failure_message(String(h.id)).is_true()  # 영웅 잠금 없음
	var gw := -1
	for i in hs.heroes.size():
		if hs.heroes[i].id == &"gwanggaeto":
			gw = i
	var at := hs.slot_rect(gw).get_center()
	hs.handle_touch(0, at, true)
	hs.handle_touch(0, at, false)
	assert_bool(sel.is_open()).is_true()
	assert_str(String(sel.hero.id)).is_equal("gwanggaeto")
	get_tree().paused = false
	main.queue_free()
	GameSettings.story_enabled = true
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.save_settings()
