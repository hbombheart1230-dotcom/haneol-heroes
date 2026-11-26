extends GdUnitTestSuite
## 적 예고 그림새 (TelegraphStyleData·TelegraphPaint, 사용자 2026-11-26 "테두리가 쨍한 게 문제"): 기본은 (바) 먹 붓 테 + 먹 번짐 채움,
## 인주색은 적 위험 계열 그대로 (색 규칙), 세 그림새 모두 원·부채·띠를 오류 없이 그린다.

var _drawn := 0


func after_test() -> void:
	TelegraphStyleData.default().look = TelegraphStyleData.BRUSH_WASH


func test_default_is_ink_bleed_and_seal_stays_enemy_red() -> void:
	var s := TelegraphStyleData.default()
	assert_int(s.look).is_equal(TelegraphStyleData.BRUSH_WASH)
	for c: Color in [s.seal_bright, s.seal_dull]:  # 인주 계열 (test_color_rules와 같은 범위): 적 위험 전용 색
		assert_bool(c.r >= 0.6 and c.g <= 0.35 and c.b <= 0.3).is_true()
	assert_float(s.seal_dull.s).is_less(s.seal_bright.s)  # (바)는 덜 쨍하다
	s.look = TelegraphStyleData.NOW
	assert_that(s.seal()).is_equal(s.seal_bright)
	s.look = TelegraphStyleData.BRUSH_WASH_TINT
	assert_that(s.seal()).is_equal(s.seal_dull)
	assert_float(s.tint()).is_equal(s.tint_alt)
	s.look = TelegraphStyleData.BRUSH_WASH
	assert_float(s.tint()).is_equal(s.tint_main)  # 기본 70% (사용자 결정)


## 어두운 바닥 (한산 갑판)에선 붓 테 밑획을 키운다: 바닥 밝기는 무대 floor_base로.
func test_dark_floor_by_stage() -> void:
	var s := TelegraphStyleData.default()
	var hansan := load("res://data/stages/hansan_1592.tres") as StageTheme
	var chochung := load("res://data/stages/chochungdo.tres") as StageTheme
	TelegraphStyleData.floor_luma = hansan.floor_base.get_luminance()
	assert_bool(s.dark_floor()).is_true()
	TelegraphStyleData.floor_luma = chochung.floor_base.get_luminance()
	assert_bool(s.dark_floor()).is_false()
	TelegraphStyleData.floor_luma = 1.0


## 붓 테의 끊김·굵기는 자리마다 고정 (프레임마다 같은 모양 — 깜빡이지 않게).
func test_brush_pattern_is_stable() -> void:
	for i in 20:
		assert_float(TelegraphPaint._hash(i, 3.0)).is_equal(TelegraphPaint._hash(i, 3.0))
		assert_float(TelegraphPaint._hash(i, 3.0)).is_between(0.0, 1.0)


func test_every_look_draws_all_shapes() -> void:
	var node := Node2D.new()
	add_child(node)
	node.draw.connect(func() -> void:
		for flash in [false, true]:
			TelegraphPaint.circle(node, Vector2.ZERO, 120.0, 0.5, flash, true, true, 3.0)
			TelegraphPaint.cone(node, Vector2.ZERO, 0.0, 0.8, 180.0, 0.5, flash, true, true)
			TelegraphPaint.band(node, Vector2.ZERO, Vector2(300, 0), Vector2(0, 40), 0.5, flash, true, true)
			TelegraphPaint.circle(node, Vector2.ZERO, 120.0, 0.0, flash, true, false, 4.0)  # 차오름 0 (번짐 시작 크기)
		_drawn += 1)
	for look in [TelegraphStyleData.NOW, TelegraphStyleData.BRUSH_WASH, TelegraphStyleData.BRUSH_WASH_TINT]:
		TelegraphStyleData.default().look = look
		var before := _drawn
		node.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		assert_int(_drawn).is_greater(before)
	node.queue_free()
