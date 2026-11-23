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
