extends GdUnitTestSuite
## 순신 해일검기 조준 중 저절로 풀림 (사용자 7ce32eb S20: "기술을 누르고 각도를 돌리다가 취소되는 오류가 간간이").
## 한 손 제스처: 제자리 꾹 → 모으기, 끌면 조준만, 놓으면 발동, 끄는 중 튕기면(내닫기) 모으기 버리고 내닫기 (6844d02 결정).
## 원인: 모으는 동안 손가락은 멈춰 있으므로 튕기기 판정이 "멈췄다 튕김" 쉬운 기준(70px·700px/s)을 써서,
## 조준을 빨리 휙 돌리는 손짓도 내닫기로 읽혀 모으기가 버려졌다. 모으는 중 내닫기는 이동 중 기준 이상으로만.

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const HERO := preload("res://data/heroes/yi_sun_sin.tres")
const DT := 1.0 / 60.0
const AT := Vector2(400, 900)

var player: Player
var caster: SkillCaster
var ctrl: TouchController
var casts: Array = []
var t := 0.0


func before_test() -> void:
	casts = []
	t = 0.0
	player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	player.hero = HERO
	add_child(player)
	player.set_physics_process(false)
	caster = auto_free(SkillCaster.new())
	caster.player = player
	caster.kit = HERO.kit
	caster.projectile_scene = PROJECTILE_SCENE
	caster.world = self
	caster.enemy_source = func() -> Array: return []
	add_child(caster)
	caster.set_physics_process(false)
	caster.skill_cast.connect(func(s: SkillCaster.Slot, _h: int) -> void: casts.append(s))
	ctrl = auto_free(TouchController.new())
	ctrl.player = player
	ctrl.skill_caster = caster


func after_test() -> void:
	for c in get_children():
		if c is Projectile:
			remove_child(c)
			c.free()


func _touch(p: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = p
	e.pressed = pressed
	ctrl.handle_event(e, t)


## 한 프레임: 손가락을 p로 (60Hz 터치 샘플) + 물리 한 번 (조준 따라가기).
func _frame(p: Vector2) -> void:
	t += DT
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = p
	ctrl.handle_event(e, t)
	caster.tick(DT, t)
	ctrl._physics_process(DT)
	ChargeView.tick(caster, DT)


func _hold_to_charge() -> void:
	_touch(AT, true)
	for i in 24:  # 0.4초 정지 → 모으기 (임계 0.3)
		t += DT
		caster.tick(DT, t)
		ctrl._physics_process(DT)
		ChargeView.tick(caster, DT)
	assert_bool(caster.is_gesture_charging()).is_true()


## 멈춰 모으다가 오른쪽으로 휙 100px (0.1초, ~1000px/s): 조준만 바뀌고 모으기는 이어진다.
func test_quick_aim_swipe_keeps_the_charge() -> void:
	_hold_to_charge()
	for i in 6:
		_frame(AT + Vector2(100.0 * (i + 1) / 6.0, 0))
	for i in 3:
		_frame(AT + Vector2(100, 0))
	assert_bool(caster.is_gesture_charging()).is_true()
	assert_bool(player.is_dashing()).is_false()
	assert_float(caster.aim.aim_dir().angle_to(Vector2.RIGHT)).is_equal_approx(0.0, 0.05)
	_touch(AT + Vector2(100, 0), false)
	assert_array(casts).is_equal([SkillCaster.Slot.CHARGE])


## 아래로 조준해 잠깐 멈췄다가 반대쪽(위)으로 휙 넘기기 (±180° 넘어감): 모으기 그대로, 조준은 위.
func test_flip_aim_to_the_other_side_keeps_the_charge() -> void:
	_hold_to_charge()
	for i in 10:
		_frame(AT + Vector2(0, 8.0 * (i + 1)))
	for i in 9:  # 0.15초 멈춤
		_frame(AT + Vector2(0, 80))
	for i in 8:  # 160px을 0.13초에 (~1200px/s)
		_frame(AT + Vector2(-2, 80 - 20.0 * (i + 1)))
	for i in 3:
		_frame(AT + Vector2(-2, -80))
	assert_bool(caster.is_gesture_charging()).is_true()
	assert_bool(player.is_dashing()).is_false()
	assert_float(caster.aim.aim_dir().y).is_less(-0.9)


## 앵커 둘레를 반지름 80px로 0.4초에 한 바퀴 (조준 돌리기, 각도가 ±180°를 지난다): 내내 모으는 중, 조준이 손가락을 따라간다.
func test_circling_the_aim_keeps_the_charge() -> void:
	_hold_to_charge()
	for i in 8:
		_frame(AT + Vector2(10.0 * (i + 1), 0))
	var n := 24
	for i in n + 1:
		var a := TAU * i / n
		_frame(AT + Vector2.from_angle(a) * 80.0)
		assert_bool(caster.is_gesture_charging()).override_failure_message("cancelled at %d°" % roundi(rad_to_deg(a))).is_true()
		assert_float(caster.aim.aim_dir().angle_to(Vector2.from_angle(a))).is_equal_approx(0.0, 0.3)
	assert_bool(player.is_dashing()).is_false()


## 일부러 세게 튕기면 (200px을 0.08초, 2500px/s) 예전처럼 모으기를 버리고 내닫는다 (의도된 취소).
func test_hard_flick_still_cancels_into_a_dash() -> void:
	_hold_to_charge()
	for i in 5:
		_frame(AT + Vector2(40.0 * (i + 1), 0))
	assert_bool(caster.is_gesture_charging()).is_false()
	assert_bool(player.is_dashing()).is_true()
