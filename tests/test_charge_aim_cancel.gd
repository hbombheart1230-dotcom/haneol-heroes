extends GdUnitTestSuite
## 모으며 조준하다 저절로 풀림 (사용자 7ce32eb S20: 순신 "기술을 누르고 각도를 돌리다가 취소되는 오류가 간간이",
## "그냥 돌리다가 180도가 넘었을 때쯤, 맞은 건 없었다", 세종 "기 모으기 기술이 취소가 많이 된다"). 네 영웅 모두.
## 한 손 제스처: 제자리 꾹 → 모으기, 끌면 조준만, 놓으면 발동, 끄는 중 세게 튕기면 모으기 버리고 내닫기 (6844d02 결정).
## 원인: 모으는 동안 손가락은 멈춰 있어 튕기기 판정이 "멈췄다 튕김" 쉬운 기준(70px·700px/s)을 썼다. 조준을 반대쪽으로
## 넘기는 손짓(누른 자리를 가로지름)은 짧고 빨라 내닫기로 읽혀 모으기가 버려졌다. 조준 각도 계산은 없다 (벡터라 ±180° 감김 없음).
## 고침: 모으는 중 튕김은 이동 중 기준(140px·1600px/s·급가속) + 누른 자리에서 바깥으로 멀어질 때만 (TouchMoveInput.charge_*).

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const HEROES := ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]
const DT := 1.0 / 60.0
const AT := Vector2(400, 900)

var player: Player
var caster: SkillCaster
var ctrl: TouchController
var casts: Array = []
var t := 0.0


func _setup(id: String) -> void:
	casts = []
	t = 0.0
	var hero: HeroData = load("res://data/heroes/%s.tres" % id)
	player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	player.hero = hero
	add_child(player)
	player.set_physics_process(false)
	player.facing = Vector2.RIGHT
	caster = auto_free(SkillCaster.new())
	caster.player = player
	caster.kit = hero.kit
	caster.projectile_scene = PROJECTILE_SCENE
	caster.world = self
	caster.hit_stop_enabled = false
	caster.enemy_source = func() -> Array: return []
	add_child(caster)
	caster.set_physics_process(false)
	caster.skill_started.connect(func(s: SkillCaster.Slot, _d: SkillDef) -> void: casts.append(s))
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


func _tick() -> void:
	caster.tick(DT, t)
	ctrl._physics_process(DT)
	ChargeView.tick(caster, DT)


## 한 프레임: 손가락을 p로 (60Hz 터치 샘플) + 물리 한 번 (조준 따라가기).
func _frame(p: Vector2) -> void:
	t += DT
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = p
	ctrl.handle_event(e, t)
	_tick()


func _hold_to_charge() -> void:
	_touch(AT, true)
	for i in 30:  # 0.5초 정지 → 모으기 (임계 0.3)
		t += DT
		_tick()
	assert_bool(caster.is_gesture_charging()).is_true()


func _still_charging(id: String, what: String) -> void:
	assert_bool(caster.is_gesture_charging()).override_failure_message("%s: charge dropped (%s)" % [id, what]).is_true()
	assert_bool(player.is_dashing()).override_failure_message("%s: dashed (%s)" % [id, what]).is_false()


## 멈춰 모으다가 오른쪽으로 휙 100px (0.1초, ~1000px/s): 조준만 바뀌고 모으기는 이어진다, 놓으면 발동.
func test_quick_aim_swipe_keeps_the_charge() -> void:
	for id in HEROES:
		_setup(id)
		_hold_to_charge()
		for i in 6:
			_frame(AT + Vector2(100.0 * (i + 1) / 6.0, 0))
		for i in 3:
			_frame(AT + Vector2(100, 0))
		_still_charging(id, "quick swipe")
		assert_float(caster.aim.aim_dir().angle_to(Vector2.RIGHT)).is_equal_approx(0.0, 0.05)
		_touch(AT + Vector2(100, 0), false)
		assert_array(casts).override_failure_message("%s: no charge cast" % id).contains([SkillCaster.Slot.CHARGE])


## 아래로 조준해 잠깐 멈췄다가 반대쪽(위)으로 휙 넘기기 (180° 넘김, ~1200px/s): 모으기 그대로, 조준은 위.
func test_flip_aim_to_the_other_side_keeps_the_charge() -> void:
	for id in HEROES:
		_setup(id)
		_hold_to_charge()
		for i in 10:
			_frame(AT + Vector2(0, 8.0 * (i + 1)))
		for i in 9:  # 0.15초 멈춤
			_frame(AT + Vector2(0, 80))
		for i in 8:  # 160px을 0.13초에
			_frame(AT + Vector2(-2, 80 - 20.0 * (i + 1)))
		for i in 3:
			_frame(AT + Vector2(-2, -80))
		_still_charging(id, "flip")
		assert_float(caster.aim.aim_dir().y).is_less(-0.9)


## 오른쪽에 조준해 멈췄다가 반지름 100px 둘레로 0.15초 만에 반 바퀴 (빠른 돌리기: 예전 기준이면 1700px/s 튕김).
func test_fast_half_turn_keeps_the_charge() -> void:
	for id in HEROES:
		_setup(id)
		_hold_to_charge()
		for i in 8:
			_frame(AT + Vector2(12.5 * (i + 1), 0))
		for i in 9:
			_frame(AT + Vector2(100, 0))
		for i in 9:
			_frame(AT + Vector2.from_angle(PI * (i + 1) / 9.0) * 100.0)
		_still_charging(id, "fast half turn")
		assert_float(caster.aim.aim_dir().x).is_less(-0.9)


## 앵커 둘레를 반지름 80px로 0.4초에 한 바퀴 (각도가 ±180°를 지난다): 내내 모으는 중, 조준이 손가락을 따라간다.
func test_circling_the_aim_keeps_the_charge() -> void:
	for id in HEROES:
		_setup(id)
		_hold_to_charge()
		for i in 8:
			_frame(AT + Vector2(10.0 * (i + 1), 0))
		var n := 24
		for i in n + 1:
			var a := TAU * i / n
			_frame(AT + Vector2.from_angle(a) * 80.0)
			_still_charging(id, "circle at %d°" % roundi(rad_to_deg(a)))
			assert_float(caster.aim.aim_dir().angle_to(Vector2.from_angle(a))).is_equal_approx(0.0, 0.3)


## 일부러 세게 바깥으로 튕기면 (멈춘 자리에서 200px을 0.08초, 조준해 둔 뒤 같은 쪽으로도) 예전처럼 모으기를 버리고 내닫는다.
func test_hard_outward_flick_still_cancels_into_a_dash() -> void:
	for id in HEROES:
		_setup(id)
		_hold_to_charge()
		for i in 5:
			_frame(AT + Vector2(40.0 * (i + 1), 0))
		assert_bool(caster.is_gesture_charging()).override_failure_message("%s: from hold" % id).is_false()
		assert_bool(player.is_dashing()).override_failure_message("%s: from hold" % id).is_true()
	for id in HEROES:
		_setup(id)
		_hold_to_charge()
		for i in 10:
			_frame(AT + Vector2(0, -8.0 * (i + 1)))
		for i in 9:
			_frame(AT + Vector2(0, -80))
		for i in 5:
			_frame(AT + Vector2(0, -80 - 45.0 * (i + 1)))
		assert_bool(player.is_dashing()).override_failure_message("%s: after aiming" % id).is_true()
