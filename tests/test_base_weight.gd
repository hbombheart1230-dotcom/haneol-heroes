extends GdUnitTestSuite
## 기본 무게감 (A·B·C): 보이는 무게 (먹 그림자·착지 눌림·멈칫·멈출 때 앞쏠림), 이동 수치 조금 (속도 −10~12%·감속·대시 충전),
## 영웅별 무게 차이 (순신 날렵 · 광개토 묵직 · 세종·사임당 중간). 대시 거리·충전 수·플릭 기준은 그대로.

const HEROES := ["yi_sun_sin", "gwanggaeto", "shin_saimdang", "sejong"]
## 바꾸기 전 이동 속도 (근거 비교용).
const OLD_SPEED := {"yi_sun_sin": 340.0, "gwanggaeto": 300.0, "shin_saimdang": 330.0, "sejong": 330.0}
const DT := 1.0 / 60.0


func _hero(id: String) -> HeroData:
	return load("res://data/heroes/%s.tres" % id) as HeroData


func test_speed_down_10_to_12_percent_and_softer_stops() -> void:
	for id in HEROES:
		var h := _hero(id)
		var drop := 1.0 - h.move_speed / float(OLD_SPEED[id])
		assert_float(drop).override_failure_message(id).is_between(0.08, 0.15)
		assert_float(h.move_decel_time).override_failure_message(id).is_greater_equal(0.08)
		assert_float(h.move_speed / 120.0).override_failure_message(id).is_greater(2.0)  # 잡몹(120)보다 두 배 넘게 빠름


func test_weight_order_nimble_to_heavy() -> void:
	var yi := _hero("yi_sun_sin")
	var gw := _hero("gwanggaeto")
	var sj := _hero("sejong")
	var sm := _hero("shin_saimdang")
	assert_float(yi.move_speed).is_greater(sj.move_speed)
	assert_float(sj.move_speed).is_greater(gw.move_speed)
	assert_float(gw.move_decel_time).is_greater(sm.move_decel_time)
	assert_float(sm.move_decel_time).is_greater(yi.move_decel_time)
	assert_float(gw.land_trauma).is_greater(0.0)  # 광개토만 착지 흔들림
	assert_float(yi.land_trauma).is_equal(0.0)
	assert_float(gw.land_hold).is_greater(yi.land_hold)
	assert_float(gw.shadow_alpha).is_greater(yi.shadow_alpha)
	assert_int(yi.max_dash_charges).is_equal(4)  # 연속 대시는 그대로
	assert_float(yi.dash_distance).is_equal(260.0)


func _view(id: String) -> PlayerView:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	p.hero = _hero(id)
	p.apply_hero(p.hero)
	var v := PlayerView.new()
	v.player = p
	p.add_child(v)
	add_child(p)
	return v


## 대시 착지: 발 기준 눌렸다가 돌아오고, 그림이 잠깐 멈춘다 (이동은 그대로).
func test_land_squashes_and_holds_then_recovers() -> void:
	var v := _view("gwanggaeto")
	var h := v.player.hero
	v.on_land()
	v._update_sprite(DT)
	assert_float(v._sprite.scale.y).is_less(h.sprite_scale)
	assert_float(v._sprite.speed_scale).is_equal(0.0)
	for i in ceili(h.land_time / DT) + 2:
		v._update_sprite(DT)
	assert_float(v._sprite.scale.y).is_equal_approx(h.sprite_scale, 0.001)
	assert_float(v._sprite.speed_scale).is_greater(0.0)


## 달리다 손을 떼면 몸이 걷던 쪽으로 살짝 쏠렸다가 돌아온다.
func test_stop_slide_leans_forward_then_settles() -> void:
	var v := _view("yi_sun_sin")
	var p := v.player
	var h := p.hero
	p.set_move_input(Vector2.RIGHT)
	for i in 20:
		p.compute_velocity(DT)
		v._update_sprite(DT)
	p.set_move_input(Vector2.ZERO)
	for i in 3:
		p.compute_velocity(DT)
		v._update_sprite(DT)
	assert_float(v._sprite.position.x).is_greater(h.sprite_offset.x)
	for i in ceili(h.stop_slide_time / DT) + 2:
		p.compute_velocity(DT)
		v._update_sprite(DT)
	assert_float(v._sprite.position.x).is_equal_approx(h.sprite_offset.x, 0.01)
