extends GdUnitTestSuite
## DashCharges: 2회 충전, 순차 회복.


func test_starts_full() -> void:
	var d := DashCharges.new(2, 1.0)
	assert_int(d.charges).is_equal(2)
	assert_bool(d.is_full()).is_true()


func test_two_consumes_then_empty() -> void:
	var d := DashCharges.new(2, 1.0)
	assert_bool(d.try_consume()).is_true()
	assert_bool(d.try_consume()).is_true()
	assert_bool(d.try_consume()).is_false()
	assert_int(d.charges).is_equal(0)


func test_recharges_one_at_a_time() -> void:
	var d := DashCharges.new(2, 1.0)
	d.try_consume()
	d.try_consume()
	d.update(0.99)
	assert_int(d.charges).is_equal(0)
	d.update(0.02)
	assert_int(d.charges).is_equal(1)
	d.update(1.0)
	assert_int(d.charges).is_equal(2)


func test_large_delta_does_not_overfill() -> void:
	var d := DashCharges.new(2, 1.0)
	d.try_consume()
	d.update(10.0)
	assert_int(d.charges).is_equal(2)
	assert_float(d.get_recharge_ratio()).is_equal(0.0)


func test_recharge_ratio_progresses() -> void:
	var d := DashCharges.new(2, 2.0)
	d.try_consume()
	d.update(0.5)
	assert_float(d.get_recharge_ratio()).is_equal_approx(0.25, 0.001)


func test_no_progress_banked_while_full() -> void:
	var d := DashCharges.new(2, 1.0)
	d.update(5.0)
	d.try_consume()
	d.update(0.5)
	assert_int(d.charges).is_equal(1)


func test_changed_signal() -> void:
	var d := DashCharges.new(2, 1.0)
	var seen: Array = []
	d.charges_changed.connect(func(c: int) -> void: seen.append(c))
	d.try_consume()
	d.update(1.0)
	assert_array(seen).is_equal([1, 2])
