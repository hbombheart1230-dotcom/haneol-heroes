extends GdUnitTestSuite
## 강화 패 틀: 종류 색은 채도를 낮추되 서로 구별되고, 틀은 InkBatch 한 묶음이다 (패마다 그리기 호출 15번 → 묶음 하나).


func test_muted_keeps_hue_but_lowers_saturation_and_brightness() -> void:
	var c := Color(0.2, 0.6, 0.45)
	var m := UpgradeCardFrame.muted(c)
	assert_float(m.h).is_equal_approx(c.h, 0.01)
	assert_float(m.s).is_less(c.s)
	assert_float(m.v).is_less(c.v)


func test_kinds_stay_distinguishable_after_muting() -> void:
	var d := UpgradeReadout.data()
	var hues := []
	for k in d.kind_colors:
		hues.append(UpgradeCardFrame.muted(d.kind_colors[k]))
	for i in hues.size():
		for j in range(i + 1, hues.size()):
			var a: Color = hues[i]
			var b: Color = hues[j]
			var diff := absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			# 같은 계열 둘(순적색 제외 아홉 종류)은 가까울 수 있어 아주 작은 차이만 막는다
			assert_float(diff).is_greater(0.02)


func test_frame_fills_one_batch_with_fill_edges_and_inner_line() -> void:
	var b := InkBatch.new()
	UpgradeCardFrame.add(b, Rect2(10, 10, 200, 400), Color(0.08, 0.06, 0.06), Color(0.5, 0.5, 0.4))
	# 바탕 사각 1 + 붓 획 4 + 안쪽 가는 선 4 = 삼각형 18개
	assert_int(b.indices.size()).is_equal(18 * 3)
	for col in b.colors:
		assert_float(col.a).is_greater(0.0)


func test_card_band_and_edge_are_not_saturated_primaries() -> void:
	var d := UpgradeReadout.data()
	for k in d.kind_colors:
		assert_float(UpgradeCardFrame.muted(d.kind_colors[k]).s).is_less(0.5)
