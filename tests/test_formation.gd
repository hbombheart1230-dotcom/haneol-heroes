extends GdUnitTestSuite
## 대형 뼈대 (FormationLayout·FormationCycle·물결 차례 넣기): 자리 모양, 사격 주기, 한산 2물결 대형 자리.


func _data(shape: FormationData.Shape, n: int = 5) -> FormationData:
	var d := FormationData.new()
	d.shape = shape
	d.count = n
	d.spacing = 70.0
	d.radius = 300.0
	return d


func test_line_is_perpendicular_to_facing_and_centered() -> void:
	var o := FormationLayout.offsets(_data(FormationData.Shape.LINE), 5, Vector2.DOWN)
	assert_int(o.size()).is_equal(5)
	for p in o:
		assert_float(p.y).is_equal_approx(0.0, 0.001)  # 영웅 쪽(아래)에 수직인 가로 줄
	assert_float(o[0].x + o[4].x).is_equal_approx(0.0, 0.001)
	assert_float(o[1].x - o[0].x).is_equal_approx(70.0, 0.001)


func test_arc_wings_reach_toward_the_hero() -> void:
	var o := FormationLayout.offsets(_data(FormationData.Shape.ARC), 5, Vector2.DOWN)
	assert_float(o[2].length()).is_equal_approx(0.0, 0.001)  # 가운데가 맨 뒤
	assert_float(o[0].y).is_greater(o[1].y)  # 양 날개가 영웅 쪽(아래)으로 더 나온다 (학익진)
	assert_float(o[4].y).is_greater(o[3].y)


func test_ring_keeps_radius() -> void:
	for p in FormationLayout.offsets(_data(FormationData.Shape.RING, 6), 6, Vector2.DOWN):
		assert_float(p.length()).is_equal_approx(300.0, 0.01)


func test_cycle_form_move_halt_aim_reload() -> void:
	var d := _data(FormationData.Shape.LINE)
	d.form_time = 0.2
	d.move_time = 1.0
	d.halt_time = 0.3
	d.reload_time = 0.5
	var c := FormationCycle.new(d)
	c.tick(0.1, false, false)
	assert_int(c.phase).is_equal(FormationCycle.Phase.FORM)
	c.tick(0.2, false, false)
	assert_int(c.phase).is_equal(FormationCycle.Phase.FORM)  # 다 모이기 전엔 안 움직인다
	c.tick(0.01, false, true)
	assert_int(c.phase).is_equal(FormationCycle.Phase.MOVE)
	c.tick(0.1, true)  # 멈출 거리에 닿음
	assert_int(c.phase).is_equal(FormationCycle.Phase.HALT)
	c.tick(0.31)
	assert_int(c.phase).is_equal(FormationCycle.Phase.AIM)
	assert_int(c.entered).is_equal(FormationCycle.Phase.AIM)
	c.tick(5.0)
	assert_int(c.phase).is_equal(FormationCycle.Phase.AIM)  # 바깥이 다 쐈다고 할 때까지
	c.aim_done()
	assert_int(c.phase).is_equal(FormationCycle.Phase.RELOAD)
	c.tick(0.51)
	assert_int(c.phase).is_equal(FormationCycle.Phase.MOVE)


func test_hansan_wave2_queues_one_gunner_line() -> void:
	var st := load("res://data/stages/hansan_1592.tres") as StageTheme
	var r := WaveRunner.new(st.waves, 0.0)
	r._start(1)
	var marks := r._queue.filter(func(x: Variant) -> bool: return x is FormationData)
	assert_int(marks.size()).is_equal(1)
	assert_int(r._queue.find(marks[0])).is_equal(st.waves.waves[1].formation_after[0])
	var f := marks[0] as FormationData
	assert_int(f.count).is_equal(8)
	assert_int(f.shape).is_equal(FormationData.Shape.LINE)
	assert_str(String(f.member.id)).is_equal(String((load("res://data/enemies/waegun_gunner.tres") as EnemyData).id))


func test_join_before_ready_still_holds_solo_aim() -> void:
	# 생성기 configure는 add_child 전에 join을 부른다 (attack은 _ready에서 생긴다): 그래도 혼자 겨누면 안 된다.
	var d := _data(FormationData.Shape.LINE)
	d.member = load("res://data/enemies/waegun_gunner.tres")
	var b := FormationBrain.new(d, null, Vector2.ZERO, Vector2.DOWN)
	var e: Enemy = (load("res://scenes/enemy.tscn") as PackedScene).instantiate()
	e.data = d.member
	b.join(e, 0)
	assert_object(e.attack).is_null()
	add_child(auto_free(e))
	e.set_physics_process(false)
	assert_object(e.attack).is_not_null()
	assert_bool(e.attack.start_check.is_valid()).is_true()
	assert_bool(bool(e.attack.start_check.call(Vector2.ZERO))).is_false()
	assert_str(b.why_not(e)).is_equal("")
