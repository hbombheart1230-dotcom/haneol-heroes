extends GdUnitTestSuite
## 먹 획·덩어리 한 번에 그리기 (InkBatch): Ink.stroke·Ink.blob와 같은 점·같은 색을 모아 한 번에 낸다 (초충도 풀숲 그리기 호출 약 480 → 1).


func test_stroke_has_the_same_four_points_as_ink_stroke() -> void:
	var b := InkBatch.new()
	var a := Vector2(10, 20)
	var e := Vector2(10, -40)
	b.stroke(a, e, 7.0, Color.RED)
	var d := e - a
	var n := d.orthogonal().normalized() * 3.5
	var mid := a + d * 0.35
	assert_array(Array(b.points)).is_equal([a, mid + n, e, mid - n * 0.7])
	assert_int(b.indices.size()).is_equal(6)
	assert_array(Array(b.colors)).is_equal([Color.RED, Color.RED, Color.RED, Color.RED])


func test_blob_is_a_fan_of_eighteen_and_flush_clears() -> void:
	var b := InkBatch.new()
	b.blob(Vector2.ZERO, 50.0, Color.GREEN, 1.0, 0.2, 0.6)
	b.stroke(Vector2.ZERO, Vector2(0, 5), 2.0, Color.BLUE)
	assert_int(b.points.size()).is_equal(19 + 4)
	assert_int(b.indices.size()).is_equal(18 * 3 + 6)
	var host: Node2D = auto_free(Node2D.new())
	add_child(host)
	b.flush(host)
	assert_int(b.points.size()).is_equal(0)


func test_zero_length_stroke_is_skipped_like_ink_stroke() -> void:
	var b := InkBatch.new()
	b.stroke(Vector2(3, 3), Vector2(3, 3), 5.0, Color.WHITE)
	assert_int(b.points.size()).is_equal(0)


func test_quad_line_and_circle_match_the_draw_calls_they_replace() -> void:
	var b := InkBatch.new()
	var q := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 5), Vector2(0, 5)])
	b.quad(q, Color.RED)
	assert_array(Array(b.points)).is_equal(Array(q))  # draw_colored_polygon(네 점)과 같은 점
	b.clear()
	b.line(Vector2(0, 0), Vector2(10, 0), 2.0, Color.WHITE)  # draw_line(굵기 2): 위아래 1px
	assert_array(Array(b.points)).is_equal([Vector2(0, -1), Vector2(10, -1), Vector2(10, 1), Vector2(0, 1)])
	b.clear()
	b.circle(Vector2(5, 5), 3.0, Color.BLUE)
	assert_int(b.points.size()).is_equal(InkBatch.SEGMENTS + 1)
	for k in range(1, b.points.size()):
		assert_float(b.points[k].distance_to(Vector2(5, 5))).is_equal_approx(3.0, 0.001)
	b.circle(Vector2.ZERO, 0.0, Color.BLUE)  # 반지름 0은 건너뜀
	assert_int(b.points.size()).is_equal(InkBatch.SEGMENTS + 1)
