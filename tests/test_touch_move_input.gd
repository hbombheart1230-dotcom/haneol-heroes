extends GdUnitTestSuite
## TouchMoveInput: 자유 영역 이동, 터치 ID 분리, 플릭 판정.

var input: TouchMoveInput


func before_test() -> void:
	input = TouchMoveInput.new()


## 이동만 검증하는 테스트에서 드문 샘플이 플릭으로 오인되지 않게 한다.
func _disable_flick() -> void:
	input.flick_min_distance = INF


func test_no_touch_means_no_movement() -> void:
	assert_bool(input.is_active()).is_false()
	assert_vector(input.get_move_vector()).is_equal(Vector2.ZERO)


func test_move_is_relative_to_touch_start_anywhere_on_screen() -> void:
	_disable_flick()
	input.touch_down(0, Vector2(500, 900), 0.0)
	input.touch_move(0, Vector2(500 + input.full_speed_radius, 900), 0.5)
	assert_vector(input.get_move_vector()).is_equal_approx(Vector2.RIGHT, Vector2(0.001, 0.001))


func test_dead_zone_gives_zero() -> void:
	input.touch_down(0, Vector2(100, 100), 0.0)
	input.touch_move(0, Vector2(100 + input.dead_zone - 1.0, 100), 0.5)
	assert_vector(input.get_move_vector()).is_equal(Vector2.ZERO)


func test_strength_scales_between_dead_zone_and_full_radius() -> void:
	input.touch_down(0, Vector2.ZERO, 0.0)
	var mid := (input.dead_zone + input.full_speed_radius) * 0.5
	input.touch_move(0, Vector2(0, mid), 0.5)
	assert_float(input.get_move_vector().length()).is_equal_approx(0.5, 0.01)
	assert_vector(input.get_move_vector().normalized()).is_equal_approx(Vector2.DOWN, Vector2(0.001, 0.001))


func test_direction_change_is_immediate() -> void:
	_disable_flick()
	input.touch_down(0, Vector2(300, 300), 0.0)
	input.touch_move(0, Vector2(400, 300), 0.5)
	input.touch_move(0, Vector2(200, 300), 1.0)
	assert_float(input.get_move_vector().x).is_less(0.0)


func test_release_stops_movement() -> void:
	_disable_flick()
	input.touch_down(0, Vector2(300, 300), 0.0)
	input.touch_move(0, Vector2(400, 300), 0.5)
	input.touch_up(0, Vector2(400, 300), 1.0)
	assert_bool(input.is_active()).is_false()
	assert_vector(input.get_move_vector()).is_equal(Vector2.ZERO)


func test_anchor_follows_when_finger_goes_far() -> void:
	_disable_flick()
	input.touch_down(0, Vector2(0, 0), 0.0)
	input.touch_move(0, Vector2(500, 0), 1.0)
	assert_float(input.get_anchor().distance_to(input.get_current())).is_equal_approx(input.anchor_follow_radius, 0.01)
	# 반대 방향으로 조금만 돌아와도 방향이 바뀐다
	input.touch_move(0, Vector2(500 - input.anchor_follow_radius - 30, 0), 2.0)
	assert_float(input.get_move_vector().x).is_less(0.0)


func test_second_finger_is_ignored_for_movement() -> void:
	_disable_flick()
	assert_bool(input.touch_down(0, Vector2(100, 100), 0.0)).is_true()
	assert_bool(input.touch_down(1, Vector2(600, 100), 0.1)).is_false()
	input.touch_move(1, Vector2(600, 400), 0.2)
	assert_vector(input.get_move_vector()).is_equal(Vector2.ZERO)
	# 두 번째 손가락을 떼도 첫 손가락 이동은 유지된다
	input.touch_move(0, Vector2(100, 300), 0.6)
	input.touch_up(1, Vector2(600, 400), 0.7)
	assert_bool(input.is_active()).is_true()
	assert_float(input.get_move_vector().y).is_greater(0.0)


func test_new_finger_takes_over_after_move_finger_released() -> void:
	_disable_flick()
	input.touch_down(0, Vector2(100, 100), 0.0)
	input.touch_down(1, Vector2(600, 600), 0.1)
	input.touch_up(0, Vector2(100, 100), 0.2)
	# 이미 눌려 있던 1번은 자동 승격하지 않는다 (의도치 않은 이동 방지). 새 터치만 채택.
	assert_bool(input.is_active()).is_false()
	assert_bool(input.touch_down(2, Vector2(300, 300), 0.3)).is_true()
	assert_int(input.get_move_index()).is_equal(2)


func test_slow_drag_is_not_a_flick() -> void:
	input.touch_down(0, Vector2(300, 600), 0.0)
	var t := 0.0
	var x := 300.0
	var flicks := 0
	for i in 60:  # 1초간 300px/s
		t += 1.0 / 60.0
		x += 5.0
		if input.touch_move(0, Vector2(x, 600), t) != Vector2.ZERO:
			flicks += 1
	if input.touch_up(0, Vector2(x, 600), t + 0.016) != Vector2.ZERO:
		flicks += 1
	assert_int(flicks).is_equal(0)


func test_fast_swipe_during_drag_is_a_flick() -> void:
	input.touch_down(0, Vector2(300, 600), 0.0)
	var t := 0.0
	var x := 300.0
	for i in 30:  # 60Hz로 오른쪽 천천히 이동 중 (120px/s)
		t += 1.0 / 60.0
		x += 2.0
		assert_vector(input.touch_move(0, Vector2(x, 600), t)).is_equal(Vector2.ZERO)
	var dir := Vector2.ZERO
	var y := 600.0
	for i in 5:  # 약 83ms 동안 위로 150px
		t += 1.0 / 60.0
		y -= 30.0
		var d := input.touch_move(0, Vector2(x, y), t)
		if d != Vector2.ZERO:
			dir = d
	assert_float(dir.dot(Vector2.UP)).is_greater(0.95)
	assert_bool(input.is_active()).is_true()


func test_first_move_event_after_holding_still_can_flick() -> void:
	input.touch_down(0, Vector2(300, 600), 0.0)
	# 1초간 정지(이벤트 없음) 후 한 프레임에 크게 이동
	var dir := input.touch_move(0, Vector2(300, 480), 1.0)
	dir = dir if dir != Vector2.ZERO else input.touch_move(0, Vector2(300, 440), 1.016)
	assert_vector(dir).is_equal_approx(Vector2.UP, Vector2(0.01, 0.01))


func test_quick_flick_and_release_dashes_on_release() -> void:
	input.touch_down(0, Vector2(300, 600), 0.0)
	input.touch_move(0, Vector2(340, 600), 0.03)
	var dir := input.touch_up(0, Vector2(400, 600), 0.06)
	assert_vector(dir).is_equal_approx(Vector2.RIGHT, Vector2(0.01, 0.01))


func test_tap_is_not_a_flick() -> void:
	input.touch_down(0, Vector2(300, 600), 0.0)
	assert_vector(input.touch_up(0, Vector2(303, 601), 0.08)).is_equal(Vector2.ZERO)


func test_flick_cooldown_prevents_double_trigger() -> void:
	input.touch_down(0, Vector2(300, 600), 0.0)
	var count := 0
	var t := 0.0
	var x := 300.0
	for i in 6:  # 100ms 동안 계속 빠르게 이동
		t += 1.0 / 60.0
		x += 40.0
		if input.touch_move(0, Vector2(x, 600), t) != Vector2.ZERO:
			count += 1
	if input.touch_up(0, Vector2(x + 40, 600), t + 0.016) != Vector2.ZERO:
		count += 1
	assert_int(count).is_equal(1)


func test_flicked_signal_emitted() -> void:
	var got: Array = []
	input.flicked.connect(func(d: Vector2) -> void: got.append(d))
	input.touch_down(0, Vector2(300, 600), 0.0)
	input.touch_up(0, Vector2(300, 700), 0.05)
	assert_int(got.size()).is_equal(1)


func test_reset_clears_state() -> void:
	input.touch_down(3, Vector2(10, 10), 0.0)
	input.reset()
	assert_bool(input.is_active()).is_false()
	assert_int(input.get_move_index()).is_equal(-1)
