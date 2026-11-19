extends GdUnitTestSuite
## "팍팍팍팍": 손 떼고 붙이기를 빠르게 반복하면 그 횟수만큼 연속 대시 (실기기 피드백).

const HERO := preload("res://data/heroes/yi_sun_sin.tres")
const DT := 1.0 / 60.0

var player: Player
var ctrl: TouchController
var dashes: Array = []
var t := 0.0


func before_test() -> void:
	dashes = []
	t = 0.0
	player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	player.hero = HERO
	add_child(player)
	player.dash_started.connect(func(d: Vector2) -> void: dashes.append(d))
	ctrl = auto_free(TouchController.new())
	ctrl.player = player


func _touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = pos
	e.pressed = pressed
	ctrl.handle_event(e, t)


func _drag(pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = pos
	ctrl.handle_event(e, t)


func _step(frames: int) -> void:
	for i in frames:
		t += DT
		player.compute_velocity(DT)


## 짧은 튕기기 한 번: 대고 → 2프레임 동안 dir로 length 이동 → 떼기.
func _flick(dir: Vector2, length: float) -> void:
	var p := Vector2(360, 900)
	_touch(p, true)
	_step(1)
	_drag(p + dir * length * 0.5)
	_step(1)
	_touch(p + dir * length, false)


func test_hero_has_four_charges() -> void:
	assert_int(player.dash.max_charges).is_equal(4)


func test_four_rapid_reflicks_give_four_dashes() -> void:
	_flick(Vector2.RIGHT, 110.0)  # 첫 대시 (멈춘 상태 기준)
	for i in 3:  # 약 0.1초 간격으로 다시 대고 짧게 튕기기
		_step(3)
		_flick(Vector2.RIGHT, 55.0)
	assert_int(dashes.size()).is_equal(4)
	assert_int(player.dash.charges).is_equal(0)


func test_rapid_reflicks_any_direction() -> void:
	var dirs := [Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.DOWN]
	_flick(dirs[0], 110.0)
	for i in range(1, 4):
		_step(3)
		_flick(dirs[i], 55.0)
	assert_int(dashes.size()).is_equal(4)
	assert_float((dashes[3] as Vector2).dot(Vector2.DOWN)).is_greater(0.9)


func test_fifth_rapid_flick_waits_for_recharge() -> void:
	_flick(Vector2.RIGHT, 110.0)
	for i in 4:
		_step(3)
		_flick(Vector2.RIGHT, 55.0)
	assert_int(dashes.size()).is_equal(4)
	_step(int(ceil(HERO.dash_recharge_time / DT)) + 1)
	_flick(Vector2.RIGHT, 110.0)
	assert_int(dashes.size()).is_equal(5)
