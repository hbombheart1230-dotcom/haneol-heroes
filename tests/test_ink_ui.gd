extends GdUnitTestSuite
## 전투 화면 먹·붓 그림 (InkPaint, InkUiStyle): 그림이 있고, 범위를 넘지 않고, 그리기가 오류 없이 돈다.

class Painter:
	extends Node2D
	var ratio := 0.6

	func _draw() -> void:
		var st := InkUiStyle.default()
		InkPaint.bar(self, Rect2(10, 10, 52, st.enemy_bar_height), ratio, st.enemy_fill, st.bar_back)
		InkPaint.ring(self, Vector2(100, 100), 40.0, Color.WHITE)
		InkPaint.wash(self, Vector2(100, 100), 40.0, Color(1, 1, 1, 0.3))
		InkPaint.wash_rect(self, Rect2(0, 200, 300, 80), Color(1, 0, 0, 0.3))
		draw_texture_rect(InkPaint.ARROW, Rect2(-96.0, -15.0, 120.0, 30.0), false)


func test_style_loads_with_sane_multipliers() -> void:
	var st := InkUiStyle.default()
	assert_float(st.wash_alpha_mult).is_between(0.5, 2.0)  # 예고 겉모습 알파 배율 (범위와 무관, 보이는 정도만)
	assert_float(st.ring_alpha_mult).is_between(0.5, 2.0)
	assert_float(st.enemy_bar_height).is_greater(6.0)


func test_ring_and_wash_stay_inside_their_radius() -> void:
	# 판정 범위 = 그림 사각형의 반 (반지름). 그림이 사각형 모서리까지 칠하면 범위 밖이 보인다.
	for tex in [InkPaint.RING, InkPaint.WASH]:
		var img: Image = tex.get_image()
		var n := img.get_width()
		assert_float(img.get_pixel(1, 1).a).is_less(0.05)  # 모서리는 비어 있다
		assert_float(img.get_pixel(n - 2, n - 2).a).is_less(0.05)
		assert_float(img.get_pixel(0, n / 2).a).is_less(0.05)  # 가장자리 한 줄은 거의 비어 있음 (반지름 바깥)
	var rect_img: Image = InkPaint.WASH_RECT.get_image()  # 사각 판은 가장자리가 안쪽으로 흔들릴 뿐 가운데는 꽉 차 있다
	assert_float(rect_img.get_pixel(rect_img.get_width() / 2, rect_img.get_height() / 2).a).is_greater(0.6)


func test_painting_runs_for_partial_and_empty_bars() -> void:
	var p: Painter = auto_free(Painter.new())
	add_child(p)
	await get_tree().process_frame
	p.ratio = 0.0
	p.queue_redraw()
	await get_tree().process_frame
	p.ratio = 1.0
	p.queue_redraw()
	await get_tree().process_frame
	assert_bool(is_instance_valid(p)).is_true()
