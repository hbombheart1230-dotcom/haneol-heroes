extends GdUnitTestSuite
## 적 예고 그리기 비용 (사용자 2026-11-26 "채움 만들 때 버벅거릴 수 있는지도 봐 줘"): 예고 하나(원·부채·띠 한 벌)를
## 그리는 스크립트 시간을 (가) 지금과 (바) 먹 붓 테 + 먹 번짐으로 견준다 ([tl-cost]). 화면 그리기 호출 수는
## tools/perf/telegraph_perf.gd (HH_PERF=1). 여기선 스크립트 쪽만: 예고가 뜰 때 노드·재질·그림을 새로 만들지 않고,
## 붓 테·채움 모양은 묶음으로 다시 써서 (가) 지금과 비슷한 시간이어야 한다.

const REPS := 200
var _us := 0.0


func after_test() -> void:
	TelegraphStyleData.default().look = TelegraphStyleData.BRUSH_WASH


func _cost(look: int, flash: bool) -> float:
	TelegraphStyleData.default().look = look
	var node := Node2D.new()
	add_child(node)
	_us = 0.0
	node.draw.connect(func() -> void:
		var t0 := Time.get_ticks_usec()
		for i in REPS:
			var k := float(i % 20) / 19.0
			TelegraphPaint.circle(node, Vector2.ZERO, 110.0, k, flash, true, true, 3.0)
			TelegraphPaint.cone(node, Vector2.ZERO, 0.4, 0.87, 190.0, k, flash, true, true)
			TelegraphPaint.band(node, Vector2.ZERO, Vector2(400, 0), Vector2(0, 45), k, flash, true, true)
		_us = float(Time.get_ticks_usec() - t0) / (REPS * 3.0))
	node.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	node.queue_free()
	return _us


func test_brush_telegraph_script_cost() -> void:
	var nodes_before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var now := await _cost(TelegraphStyleData.NOW, false)
	var brush := await _cost(TelegraphStyleData.BRUSH_WASH, false)
	var brush_flash := await _cost(TelegraphStyleData.BRUSH_WASH, true)
	print("[tl-cost] 예고 하나 스크립트 시간: (가) 지금 %.1fus / (바) 붓 테+먹 번짐 %.1fus / (바) 치기 직전 %.1fus" % [now, brush, brush_flash])
	# 묶음을 다시 쓰니 (가) 지금과 비슷해야 한다 (묶기 전 약 10배, 0.3ms). 다른 일로 바쁜 기계에서도 넘지 않게 넉넉히.
	assert_float(brush).is_less(maxf(now * 3.0, 100.0))
	assert_float(brush_flash).is_less(maxf(now * 3.0, 100.0))
	await get_tree().process_frame
	assert_float(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)).is_less_equal(nodes_before)  # 예고가 노드를 남기지 않는다
