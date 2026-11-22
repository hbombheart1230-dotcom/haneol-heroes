extends GdUnitTestSuite
## 평타 검기 궤적 (SwingArc 계산, SwingTrail 색·연결, 초승달 대체 규칙).

const DATA := preload("res://data/feel/swing_trail.tres")
const YI := preload("res://data/heroes/yi_sun_sin.tres")
const SEJONG := preload("res://data/heroes/sejong.tres")


func _arc(pause: float = 0.0, flip: float = 1.0) -> SwingArc:
	var a := SwingArc.new()
	a.setup(0.0, deg_to_rad(60), flip, 120.0, 40.0, pause, 0.2, DATA)
	return a


func _buffers() -> Array:
	var n := DATA.segments + 1
	var o := PackedVector2Array()
	var i := PackedVector2Array()
	var f := PackedFloat32Array()
	o.resize(n)
	i.resize(n)
	f.resize(n)
	return [o, i, f]


func test_timeline_waits_for_windup_and_brackets_the_strike() -> void:
	var a := _arc(0.3)
	assert_float(a.strike).is_equal_approx(0.5, 0.0001)
	assert_float(a.start).is_equal_approx(0.5 - DATA.lead, 0.0001)
	assert_float(a.finish).is_equal_approx(0.5 + DATA.follow, 0.0001)
	var short := SwingArc.new()  # 닿기까지가 lead보다 짧아도 모으기 전에는 시작하지 않는다
	short.setup(0.0, 1.0, 1.0, 100.0, 30.0, 0.25, 0.02, DATA)
	assert_float(short.start).is_equal(0.25)


func test_head_sweeps_side_to_side_past_centre_at_strike() -> void:
	var a := _arc()
	assert_float(a.angle_at(a.start)).is_equal_approx(-a.half, 0.0001)
	assert_float(a.angle_at(a.finish)).is_equal_approx(a.half, 0.0001)
	assert_float(a.angle_at(a.strike)).is_greater(0.0)  # 닿는 순간 가운데를 조금 지남
	var b := _arc(0.0, -1.0)  # 2타: 반대쪽에서
	assert_float(b.angle_at(b.start)).is_equal_approx(b.half, 0.0001)


func test_fill_tapers_from_head_and_draws_nothing_before_start() -> void:
	var a := _arc()
	var buf := _buffers()
	a.fill(a.start - 0.01, DATA, buf[0], buf[1], buf[2])
	for v in buf[2]:
		assert_float(v).is_equal(0.0)
	a.fill(a.finish, DATA, buf[0], buf[1], buf[2])
	var o: PackedVector2Array = buf[0]
	var inn: PackedVector2Array = buf[1]
	var n := o.size() - 1
	var head_w := o[n].length() - inn[n].length()
	assert_float(head_w).is_greater(o[n / 2].length() - inn[n / 2].length())
	assert_float(buf[2][n]).is_equal(1.0)


func test_trail_ends_after_life() -> void:
	var a := _arc()
	assert_bool(a.alive(a.finish + DATA.life * 0.5, DATA)).is_true()
	assert_bool(a.alive(a.finish + DATA.life + 0.01, DATA)).is_false()


func test_band_colour_goes_ink_to_hero_to_white() -> void:
	var hero := Color(0.15, 0.45, 0.85)
	var tail := SwingTrail.body_color(0.02, hero, DATA)
	var mid := SwingTrail.body_color(0.5, hero, DATA)
	var head := SwingTrail.body_color(1.0, hero, DATA)
	assert_float(tail.get_luminance()).is_less(mid.get_luminance())
	assert_float(head.get_luminance()).is_greater(0.8)  # 앞머리는 거의 흰빛
	assert_float(mid.b).is_greater(mid.r)  # 가운데는 영웅색
	assert_float(head.a).is_equal(1.0)


func test_trail_covers_listed_heroes_only() -> void:
	var p: Player = auto_free(Player.new())
	p.hero = YI
	assert_bool(SwingTrail.covers(p)).is_false()  # 궤적 노드가 없으면 초승달 그대로
	p.set_meta(&"swing_trail", DATA)
	assert_bool(SwingTrail.covers(p)).is_true()
	p.hero = SEJONG
	assert_bool(SwingTrail.covers(p)).is_false()


func test_main_scene_has_trail_wired_to_auto_attack() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var st := scene.get_state()
	var found := false
	for i in st.get_node_count():
		if st.get_node_name(i) == &"SwingTrail":
			found = true
	assert_bool(found).is_true()
