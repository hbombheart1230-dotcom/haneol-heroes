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


func test_combo_text_hides_under_boss_banner() -> void:
	var hud: Control = auto_free(Control.new())
	var banner: BossBanner = BossBanner.new()
	banner.name = "BossBanner"
	var combo: ComboCounter = ComboCounter.new()
	hud.add_child(banner)
	hud.add_child(combo)
	add_child(hud)
	combo.add_hits(3)
	assert_bool(combo.text_rect().has_area()).is_true()
	var e := Enemy.new()
	e.data = _group("hansan_1592")[0]
	auto_free(e)
	banner.show_boss(e)
	assert_bool(combo.text_rect().has_area()).is_false()
	banner.step(10.0)
	assert_bool(combo.text_rect().has_area()).is_true()


func test_combo_text_hides_under_wave_banner() -> void:
	var hud: Hud = auto_free(Hud.new())
	var combo: ComboCounter = ComboCounter.new()
	hud.add_child(combo)
	add_child(hud)
	combo.add_hits(2)
	assert_bool(combo.text_rect().has_area()).is_true()
	hud._wave_banner.request(0, false)
	hud._wave_banner.tick(0.0, false)
	assert_bool(combo.text_rect().has_area()).is_false()
	hud._wave_banner.tick(10.0, false)
	assert_bool(combo.text_rect().has_area()).is_true()


## 띠가 빠지는 마지막 장 뒤에 한 번 더 지워 그린다 (전에는 끝 무렵 흐린 띠가 그대로 남았다: 폰 끊김 120ms에서 투명도 0.2).
func test_banner_is_redrawn_empty_after_it_ends() -> void:
	var banner: BossBanner = auto_free(BossBanner.new())
	banner.size = Vector2(720, 1280)
	add_child(banner)
	var e := Enemy.new()
	e.data = _group("hansan_1592")[0]
	auto_free(e)
	banner.show_boss(e)
	banner.mood = 0.0
	banner._t = banner._len - 0.2  # 빠지는 끝 무렵 (투명도 0.4)
	var last := [-1.0, 0]
	banner.draw.connect(func() -> void:
		last[1] += 1
		last[0] = clampf((banner._len - banner._t) / 0.5, 0.0, 1.0) if banner.banner_visible() else 0.0)
	await get_tree().process_frame
	banner.step(0.19)  # 큰 끊김 한 장
	for i in 20:
		await get_tree().process_frame
	assert_bool(banner.banner_visible()).is_false()
	assert_int(last[1]).is_greater(1)
	assert_float(last[0]).is_equal(0.0)
