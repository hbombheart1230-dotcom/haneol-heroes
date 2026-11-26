extends GdUnitTestSuite
## 구역 차례 (ZonePlan): 어느 물결을 깨면 넘어가는지, 마지막 구역, 한산 데이터.


func _zone(waves: int, title: String = "") -> ZoneData:
	var z := ZoneData.new()
	z.waves = waves
	z.title = title
	return z


func test_single_or_no_zone_is_inactive() -> void:
	assert_bool(ZonePlan.new([]).active()).is_false()
	var one: Array[ZoneData] = [_zone(4)]
	var p := ZonePlan.new(one)
	assert_bool(p.active()).is_false()
	assert_bool(p.ends_zone(3)).is_false()


func test_ends_zone_after_its_last_wave_only() -> void:
	var list: Array[ZoneData] = [_zone(2, "a"), _zone(2, "b"), _zone(0, "c")]
	var p := ZonePlan.new(list)
	assert_bool(p.ends_zone(0)).is_false()
	assert_bool(p.ends_zone(1)).is_true()
	assert_object(p.advance()).is_same(list[1])
	assert_bool(p.ends_zone(1)).is_false()  # 이미 넘어온 구역의 끝은 다시 세지 않는다
	assert_bool(p.ends_zone(2)).is_false()
	assert_bool(p.ends_zone(3)).is_true()  # 마지막 물결 뒤 → 우두머리 구역으로
	p.advance()
	assert_bool(p.ends_zone(3)).is_false()  # 마지막 구역에서는 넘어가지 않는다
	assert_object(p.advance()).is_null()


func test_prompt_falls_back_to_next_title() -> void:
	var list: Array[ZoneData] = [_zone(1, "a"), _zone(1, "왜 적선")]
	var p := ZonePlan.new(list)
	assert_str(p.prompt()).is_equal("왜 적선 쪽으로 내닫기")
	list[0].prompt = "적선으로 내닫기"
	assert_str(p.prompt()).is_equal("적선으로 내닫기")


func test_hansan_zones_cover_all_waves() -> void:
	var st := load("res://data/stages/hansan_1592.tres") as StageTheme
	assert_int(st.zones.size()).is_equal(3)
	var n := 0
	for z in st.zones:
		n += z.waves
	assert_int(n).is_equal(st.waves.waves.size())  # 구역 물결 수 합 = 무대 물결 수 (우두머리는 마지막 구역)
	assert_int(st.zones[-1].waves).is_equal(0)
	for z in st.zones:
		assert_bool(WalkArea.clamp_point(st.walk_area, z.entry).is_equal_approx(z.entry)).is_true()  # 내려앉을 자리는 걸을 수 있는 곳 안
