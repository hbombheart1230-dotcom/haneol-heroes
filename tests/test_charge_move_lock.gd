extends GdUnitTestSuite
## 모으는 기술 중 이동 (사용자 2026-11-24: "기 모으기 중에 이동 가능한 것도 개선 안 됐어"): 모으는 동안 걷지 않고,
## 끌기는 조준만, 취소는 내닫기(튕기기)나 손 떼기로만. 네 영웅, 손가락·버튼 모두 같은 규칙.

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const HEROES := ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]
const DT := 1.0 / 60.0

var player: Player
var caster: SkillCaster
var ctrl: TouchController
var casts: Array = []


func _setup(id: String) -> void:
	casts = []
	var hero: HeroData = load("res://data/heroes/%s.tres" % id)
	player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	player.hero = hero
	add_child(player)
	caster = auto_free(SkillCaster.new())
	caster.player = player
	caster.kit = hero.kit
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
			c.free()


func _touch(i: int, p: Vector2, t: float, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = p
	e.pressed = pressed
	ctrl.handle_event(e, t)


func _drag(i: int, p: Vector2, t: float) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = p
	ctrl.handle_event(e, t)


func _step(t: float) -> void:
	caster.tick(DT, t)
	ctrl._physics_process(DT)
	player.compute_velocity(DT)


## 꾹 눌러 모으기 시작 → 반환: 그때 시각.
func _charge(at: Vector2) -> float:
	_touch(0, at, 0.0, true)
	var t := 0.0
	for i in 24:
		t += DT
		_step(t)
	assert_bool(caster.is_charging()).is_true()
	return t


func test_drag_while_charging_aims_but_does_not_walk() -> void:
	for id in HEROES:
		_setup(id)
		var t := _charge(Vector2(400, 900))
		for i in 30:
			t += DT
			_drag(0, Vector2(400 - i * 5, 900), t)
			_step(t)
		assert_float(player.move_input.x).override_failure_message(id).is_less(-0.5)
		assert_vector(player.walk_velocity()).override_failure_message(id).is_equal(Vector2.ZERO)
		assert_bool(caster.is_charging()).override_failure_message(id).is_true()
		_touch(0, Vector2(250, 900), t + DT, false)
		assert_bool(player.is_dashing()).override_failure_message(id).is_false()  # 손 떼기 = 발동 (쓸 대상이 없으면 세종·사임당은 안 나감), 내닫기 아님


func test_flick_while_charging_cancels_and_dashes() -> void:
	for id in HEROES:
		_setup(id)
		var t := _charge(Vector2(400, 900))
		_drag(0, Vector2(430, 900), t + 0.02)
		_drag(0, Vector2(560, 900), t + 0.06)  # 0.04초에 130px = 튕기기
		assert_bool(caster.is_charging()).override_failure_message(id).is_false()
		assert_bool(player.is_dashing()).override_failure_message(id).is_true()
		_touch(0, Vector2(560, 900), t + 0.1, false)
		assert_bool(casts.has(SkillCaster.Slot.CHARGE)).override_failure_message(id).is_false()


func test_walk_comes_back_after_charge() -> void:
	_setup("yi_sun_sin")
	var t := _charge(Vector2(400, 900))
	_touch(0, Vector2(400, 900), t + DT, false)
	t += DT
	for i in 10:
		t += DT
		caster.tick(DT, t)
		player.set_move_input(Vector2.LEFT)
		player.compute_velocity(DT)
	assert_float(player.walk_velocity().x).is_less(0.0)


## 실제 터치 끌기로: 모으는 중 끌어도 그림은 모으는 자세 그대로 (뛰기·서기로 바뀌지 않음), 몸은 끄는 쪽을 본다 (사용자 6d0635c 결함).
func test_drag_while_charging_keeps_the_charge_pose() -> void:
	for id in HEROES:
		_setup(id)
		remove_child(caster)  # 게임처럼 SkillCaster는 Player 아래 (그림이 모으는 중인지 거기서 읽는다)
		caster.name = "SkillCaster"
		player.add_child(caster)
		var view := PlayerView.new()
		view.player = player
		player.add_child(view)
		view.set_physics_process(false)
		var pose := CastAnim.charge_pose(caster.def_of(SkillCaster.Slot.CHARGE), player.hero.sprite_sheet)
		var t := _charge(Vector2(400, 900))
		assert_str(view.current_anim()).override_failure_message(id + " before drag").is_equal(pose)
		for i in 30:
			t += DT
			_drag(0, Vector2(400 - i * 5, 900 + i * 2), t)
			_step(t)
			assert_str(view.current_anim()).override_failure_message("%s drag %d: %s" % [id, i, view.current_anim()]).is_equal(pose)
		assert_bool(view.is_moving()).override_failure_message(id).is_false()
		assert_float(player.facing.x).override_failure_message(id + " faces the drag").is_less(-0.5)
		_touch(0, Vector2(250, 960), t + DT, false)
		player.remove_child(view)
		view.free()
