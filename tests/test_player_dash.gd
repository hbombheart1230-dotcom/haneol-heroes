extends GdUnitTestSuite
## Player 이동·대시 로직 + TouchController 연동 (실제 InputEventScreen* 사용).

const DT := 1.0 / 60.0

var player: Player


func before_test() -> void:
	player = auto_free(Player.new())


func _run(seconds: float) -> Vector2:
	var total := Vector2.ZERO
	var steps := int(round(seconds / DT))
	for i in steps:
		total += player.compute_velocity(DT) * DT
	return total


func test_moves_with_input() -> void:
	player.set_move_input(Vector2.RIGHT)
	var moved := _run(1.0)
	assert_float(moved.x).is_equal_approx(player.move_speed, 1.0)


func test_input_is_clamped_to_unit_length() -> void:
	player.set_move_input(Vector2(5, 0))
	assert_float(player.move_input.length()).is_equal_approx(1.0, 0.0001)


func test_dash_travels_dash_distance_in_dash_duration() -> void:
	assert_bool(player.request_dash(Vector2.UP)).is_true()
	assert_bool(player.is_dashing()).is_true()
	var moved := _run(player.dash_duration + DT * 3)
	assert_bool(player.is_dashing()).is_false()
	assert_float(moved.y).is_equal_approx(-player.dash_distance, 1.0)
	assert_float(moved.x).is_equal_approx(0.0, 0.01)


func test_dash_direction_ignores_move_input_while_dashing() -> void:
	player.request_dash(Vector2.RIGHT)
	player.set_move_input(Vector2.LEFT)
	var v := player.compute_velocity(DT)
	assert_float(v.x).is_greater(0.0)


func test_invulnerable_only_during_dash() -> void:
	assert_bool(player.is_invulnerable()).is_false()
	player.request_dash(Vector2.RIGHT)
	assert_bool(player.is_invulnerable()).is_true()
	_run(player.dash_duration + DT)
	assert_bool(player.is_invulnerable()).is_false()


func test_two_charges_then_blocked_until_recharge() -> void:
	assert_bool(player.request_dash(Vector2.RIGHT)).is_true()
	_run(player.dash_duration + DT)
	assert_bool(player.request_dash(Vector2.RIGHT)).is_true()
	_run(player.dash_duration + DT)
	assert_bool(player.request_dash(Vector2.RIGHT)).is_false()
	_run(player.dash_recharge_time)
	assert_bool(player.request_dash(Vector2.RIGHT)).is_true()


func test_dash_request_while_dashing_without_charge_is_rejected() -> void:
	player.request_dash(Vector2.RIGHT)
	player.request_dash(Vector2.RIGHT)
	assert_int(player.dash.charges).is_equal(0)
	assert_bool(player.request_dash(Vector2.LEFT)).is_false()


func test_zero_direction_dash_uses_move_then_facing() -> void:
	player.set_move_input(Vector2.LEFT)
	player.request_dash(Vector2.ZERO)
	assert_vector(player.get_dash_direction()).is_equal_approx(Vector2.LEFT, Vector2(0.001, 0.001))
	_run(player.dash_duration + DT)
	player.set_move_input(Vector2.ZERO)
	player.request_dash()
	assert_vector(player.get_dash_direction()).is_equal_approx(Vector2.LEFT, Vector2(0.001, 0.001))


func test_dash_signals() -> void:
	var events: Array = []
	player.dash_started.connect(func(_d: Vector2) -> void: events.append("start"))
	player.dash_ended.connect(func() -> void: events.append("end"))
	player.request_dash(Vector2.DOWN)
	_run(player.dash_duration + DT)
	assert_array(events).is_equal(["start", "end"])


# --- TouchController 연동 ---

func _touch(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	return e


func _drag(index: int, pos: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	return e


func _controller() -> TouchController:
	var c: TouchController = auto_free(TouchController.new())
	c.player = player
	return c


func test_controller_drag_moves_player() -> void:
	var c := _controller()
	c.touch_input.rest_min_distance = INF  # 드문 샘플이 플릭으로 오인되지 않게
	c.touch_input.move_min_distance = INF
	c.handle_event(_touch(0, Vector2(360, 900), true), 0.0)
	c.handle_event(_drag(0, Vector2(360, 1000)), 0.5)
	c._physics_process(DT)
	assert_float(player.move_input.y).is_greater(0.9)
	c.handle_event(_touch(0, Vector2(360, 1000), false), 1.0)
	c._physics_process(DT)
	assert_vector(player.move_input).is_equal(Vector2.ZERO)


func test_controller_flick_triggers_dash() -> void:
	var c := _controller()
	c.handle_event(_touch(0, Vector2(360, 900), true), 0.0)
	c.handle_event(_drag(0, Vector2(420, 900)), 0.03)
	c.handle_event(_touch(0, Vector2(480, 900), false), 0.06)
	assert_bool(player.is_dashing()).is_true()
	assert_vector(player.get_dash_direction()).is_equal_approx(Vector2.RIGHT, Vector2(0.01, 0.01))


func test_controller_ignores_other_touch_ids() -> void:
	var c := _controller()
	c.handle_event(_touch(0, Vector2(100, 900), true), 0.0)
	assert_bool(c.handle_event(_touch(1, Vector2(600, 900), true), 0.1)).is_false()
	# 두 번째 손가락의 빠른 플릭은 대시를 일으키지 않는다
	c.handle_event(_drag(1, Vector2(600, 700)), 0.13)
	c.handle_event(_touch(1, Vector2(600, 600), false), 0.15)
	assert_bool(player.is_dashing()).is_false()
	assert_bool(c.touch_input.is_active()).is_true()


func test_controller_canceled_touch_resets_without_dash() -> void:
	var c := _controller()
	c.handle_event(_touch(0, Vector2(360, 900), true), 0.0)
	c.handle_event(_drag(0, Vector2(380, 900)), 0.02)
	var up := _touch(0, Vector2(480, 900), false)
	up.canceled = true
	c.handle_event(up, 0.05)
	assert_bool(player.is_dashing()).is_false()
	assert_bool(c.touch_input.is_active()).is_false()


func test_flick_during_dash_dashes_immediately() -> void:
	# 연속 대시: 대시 중 새 요청은 기다리지 않고 즉시 새 방향으로
	assert_bool(player.request_dash(Vector2.RIGHT)).is_true()
	player.compute_velocity(DT)
	assert_bool(player.request_dash(Vector2.UP)).is_true()
	assert_bool(player.is_dashing()).is_true()
	assert_vector(player.get_dash_direction()).is_equal_approx(Vector2.UP, Vector2(0.001, 0.001))
	assert_int(player.dash.charges).is_equal(0)
	var moved := _run(player.dash_duration + DT)
	assert_float(moved.y).is_equal_approx(-player.dash_distance, 1.0)


func test_flick_during_dash_without_charge_is_ignored() -> void:
	player.request_dash(Vector2.RIGHT)
	player.request_dash(Vector2.UP)  # 2회째 (즉시)
	assert_bool(player.request_dash(Vector2.LEFT)).is_false()  # 충전 없음
	assert_vector(player.get_dash_direction()).is_equal_approx(Vector2.UP, Vector2(0.001, 0.001))
