extends GdUnitTestSuite
## P0-D 성능 기록.


func test_avg_and_low_fps() -> void:
	var p := PerfStats.new()
	for i in 99:
		p.sample(1.0 / 60.0, 10)
	p.sample(0.1, 30)  # 끊긴 프레임 1개
	assert_float(p.avg_fps()).is_equal_approx(100.0 / (99.0 / 60.0 + 0.1), 0.01)
	assert_float(p.low_1pct_fps()).is_equal_approx(10.0, 0.01)
	assert_float(p.worst_frame).is_equal_approx(0.1, 0.0001)
	assert_int(p.max_enemies).is_equal(30)


func test_empty_is_zero() -> void:
	var p := PerfStats.new()
	assert_float(p.avg_fps()).is_equal(0.0)
	assert_float(p.low_1pct_fps()).is_equal(0.0)
	p.sample(0.0, 5)
	assert_int(p.frames).is_equal(0)


func test_summary_text() -> void:
	var p := PerfStats.new()
	p.sample(1.0 / 60.0, 30)
	assert_str(p.summary()).contains("60 FPS").contains("최대 적 30")
