extends GdUnitTestSuite
## 중간 우두머리 무리 등장 띠: 셋이 한꺼번에 나오면 이름이 셋 다 적히고, 긴 이름은 폭에 맞게 줄고, 위쪽 체력 띠는 "외 N".

const STAGES := ["hansan_1592", "manchuria_395", "gyeongbokgung_1433", "chochungdo"]


func _group(stage_id: String) -> Array:
	var st := load("res://data/stages/%s.tres" % stage_id) as StageTheme
	for w in st.waves.waves:
		if not (w as WaveData).elite_group.is_empty():
			return (w as WaveData).elite_group
	return []


func test_all_names_are_collected_for_every_stage() -> void:
	for id in STAGES:
		var sp: EnemySpawner = auto_free(EnemySpawner.new())
		var banner: BossBanner = auto_free(BossBanner.new())
		banner.spawner = sp
		add_child(sp)
		add_child(banner)
		var group := _group(id)
		assert_int(group.size()).is_equal(3)
		var first := Enemy.new()
		first.data = group[0]
		auto_free(first)
		banner.show_boss(first)
		banner._collect = 1.0
		for i in range(1, group.size()):
			var e := Enemy.new()
			e.data = group[i]
			auto_free(e)
			banner.add_name(e)
		assert_int(banner._names.size()).is_equal(3)
		for g in group:
			assert_bool(banner._names.has((g as EnemyData).display_name)).is_true()


func test_collect_window_closes() -> void:
	var banner: BossBanner = auto_free(BossBanner.new())
	add_child(banner)
	var e := Enemy.new()
	e.data = _group("hansan_1592")[0]
	auto_free(e)
	banner.show_boss(e)
	banner._collect = WaveBannerData.default().group_collect_time
	banner.step(WaveBannerData.default().group_collect_time + 0.1)
	assert_float(banner._collect).is_equal(0.0)


func test_long_names_shrink_to_fit_portrait_width() -> void:
	var w := 1080.0 - WaveBannerData.default().group_side_margin * 2.0
	for id in STAGES:
		for g in _group(id):
			var px := BossBanner.fit_px((g as EnemyData).display_name, WaveBannerData.default().group_name_px, w)
			var width := UiStyle.TITLE_FONT.get_string_size((g as EnemyData).display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			assert_float(width).is_less_equal(w)
