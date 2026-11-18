extends GdUnitTestSuite
## P0-C 상황 반응형 단일 스킬 버튼: 입력 상태 머신, 해룡참·파도격·해일검기, 버튼 라우팅.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const DT := 1.0 / 60.0

var player: Player
var caster: SkillCaster
var enemies: Array = []


func before_test() -> void:
	enemies = []
	player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	add_child(player)
	player.global_position = Vector2.ZERO
	caster = auto_free(SkillCaster.new())
	caster.player = player
	caster.projectile_scene = PROJECTILE_SCENE
	caster.world = self
	caster.enemy_source = func() -> Array: return enemies
	add_child(caster)
	caster.set_physics_process(false)


func _enemy_at(pos: Vector2) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = pos
	enemies.append(e)
	return e


# --- SkillInput ---

func test_input_tap() -> void:
	var si := SkillInput.new()
	si.press(3, 0.0)
	assert_dict(si.release(3, 0.1)).is_equal({"kind": "tap", "charge": 0.0})
	assert_bool(si.is_down()).is_false()


func test_input_hold_becomes_charge_with_ratio() -> void:
	var si := SkillInput.new()
	si.press(1, 0.0)
	assert_bool(si.update(si.hold_threshold + 0.01)).is_true()
	assert_float(si.charge_ratio(si.hold_threshold + si.full_charge_time * 0.5)).is_equal_approx(0.5, 0.001)
	var r := si.release(1, si.hold_threshold + si.full_charge_time * 3)
	assert_str(r["kind"]).is_equal("charge")
	assert_float(r["charge"]).is_equal(1.0)


func test_input_other_finger_release_ignored() -> void:
	var si := SkillInput.new()
	si.press(1, 0.0)
	assert_str(si.release(2, 0.1)["kind"]).is_equal("none")
	assert_bool(si.is_down()).is_true()
	assert_bool(si.press(2, 0.1)).is_false()


func test_input_consumed_press_releases_nothing() -> void:
	var si := SkillInput.new()
	si.press(0, 0.0)
	si.consume()
	assert_str(si.release(0, 1.0)["kind"]).is_equal("none")


# --- 해룡참 ---

func test_tap_casts_haeryong_damage_and_knockback_in_radius() -> void:
	var near := _enemy_at(Vector2(100, 0))
	var far := _enemy_at(Vector2(400, 0))
	caster.on_press(0, 0.0)
	assert_int(caster.on_release(0, 0.1)).is_equal(SkillCaster.Skill.HAERYONG)
	assert_int(near.health.current).is_equal(near.health.max - caster.haeryong_damage)
	assert_float(near.knockback.x).is_greater(0.0)
	assert_int(far.health.current).is_equal(far.health.max)


func test_haeryong_cooldown_4s() -> void:
	var e := _enemy_at(Vector2(50, 0))
	e.health.max = 1000
	e.health.current = 1000
	caster.on_press(0, 0.0)
	caster.on_release(0, 0.05)
	caster.on_press(0, 0.1)
	assert_int(caster.on_release(0, 0.15)).is_equal(SkillCaster.Skill.NONE)
	caster.tick(caster.haeryong_cooldown, 4.5)
	caster.on_press(0, 4.5)
	assert_int(caster.on_release(0, 4.55)).is_equal(SkillCaster.Skill.HAERYONG)
	assert_int(e.health.current).is_equal(1000 - 2 * caster.haeryong_damage)


# --- 파도격 ---

func test_press_during_dash_casts_pado_multi_hit_along_path() -> void:
	var on_path := _enemy_at(Vector2(200, 10))
	var off_path := _enemy_at(Vector2(0, 200))
	on_path.health.max = 1000
	on_path.health.current = 1000
	player.request_dash(Vector2.RIGHT)
	var casts: Array = []
	caster.skill_cast.connect(func(s: SkillCaster.Skill, hits: int) -> void: casts.append([s, hits]))
	caster.on_press(0, 0.0)
	for i in 30:
		caster.tick(DT, 0.0 + DT * i)
	assert_int(on_path.health.current).is_equal(1000 - caster.pado_hits * caster.pado_damage_per_hit)
	assert_int(off_path.health.current).is_equal(off_path.health.max)
	assert_array(casts).is_equal([[SkillCaster.Skill.PADO, caster.pado_hits]])
	# 같은 누름은 손을 떼도 해룡참을 추가로 쓰지 않는다
	assert_int(caster.on_release(0, 0.6)).is_equal(SkillCaster.Skill.NONE)


func test_press_right_after_dash_still_pado() -> void:
	player.request_dash(Vector2.UP)
	for i in 12:  # 대시(0.16초) 종료 후 약 0.04초
		player.compute_velocity(DT)
	assert_bool(player.is_dashing()).is_false()
	assert_int(caster.preview_skill()).is_equal(SkillCaster.Skill.PADO)
	for i in 20:  # 연계 시간(0.25초) 지나면 해룡참
		player.compute_velocity(DT)
	assert_int(caster.preview_skill()).is_equal(SkillCaster.Skill.HAERYONG)


func test_pado_on_cooldown_falls_back_to_normal_press() -> void:
	player.request_dash(Vector2.RIGHT)
	caster.on_press(0, 0.0)
	caster.on_release(0, 0.05)
	player.compute_velocity(DT)
	assert_int(caster.preview_skill()).is_equal(SkillCaster.Skill.HAERYONG)
	caster.on_press(1, 0.1)
	assert_int(caster.on_release(1, 0.15)).is_equal(SkillCaster.Skill.HAERYONG)


# --- 해일검기 ---

func test_hold_release_fires_haeil_scaled_by_charge() -> void:
	caster.on_press(0, 0.0)
	var t := caster.input.hold_threshold + caster.input.full_charge_time  # 최대 충전
	caster.tick(t, t)
	assert_int(caster.preview_skill()).is_equal(SkillCaster.Skill.HAEIL)
	var fired: Array = []
	caster.skill_cast.connect(func(s: SkillCaster.Skill, _h: int) -> void: fired.append(s))
	assert_int(caster.on_release(0, t)).is_equal(SkillCaster.Skill.HAEIL)
	var proj: Projectile = null
	for c in get_children():
		if c is Projectile:
			proj = c
	assert_object(proj).is_not_null()
	assert_bool(proj.pierce).is_true()
	assert_int(proj.damage).is_equal(caster.haeil_max_damage)
	assert_float(proj.size_scale).is_equal_approx(caster.haeil_max_scale, 0.001)
	proj.queue_free()


func test_haeil_min_charge_damage() -> void:
	caster.on_press(0, 0.0)
	var t := caster.input.hold_threshold + 0.001
	var p := caster.cast_haeil(0.0)
	assert_int(p.damage).is_equal(caster.haeil_min_damage)
	p.queue_free()
	caster.cancel_input()


func test_charging_while_moving() -> void:
	player.set_move_input(Vector2.LEFT)
	caster.on_press(0, 0.0)
	caster.tick(0.5, 0.5)
	var moved := Vector2.ZERO
	for i in 30:
		moved += player.compute_velocity(DT) * DT
	assert_float(moved.x).is_less(-100.0)
	assert_int(caster.input.state).is_equal(SkillInput.State.CHARGING)


func test_haeil_pierces_multiple_enemies() -> void:
	var a := _enemy_at(Vector2(120, 0))
	var b := _enemy_at(Vector2(220, 0))
	var c := _enemy_at(Vector2(320, 0))
	player.facing = Vector2.RIGHT
	var p := caster.cast_haeil(1.0)
	for i in 40:
		await get_tree().physics_frame
	for e in [a, b, c]:
		assert_bool(not is_instance_valid(e) or (e as Enemy).health.current < (e as Enemy).health.max).is_true()
	if is_instance_valid(p):
		assert_int(p.hits).is_equal(3)
		p.queue_free()


# --- 버튼 라우팅 (TouchController) ---

func _controller() -> TouchController:
	var c: TouchController = auto_free(TouchController.new())
	c.player = player
	c.skill_caster = caster
	return c


func _touch(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	return e


func test_touch_on_button_is_skill_not_move() -> void:
	var c := _controller()
	var btn := c.skill_button_center()
	c.handle_event(_touch(0, btn, true), 0.0)
	assert_bool(c.touch_input.is_active()).is_false()
	assert_bool(caster.input.is_down()).is_true()
	c.handle_event(_touch(0, btn, false), 0.05)
	assert_bool(caster.is_ready(SkillCaster.Skill.HAERYONG)).is_false()


func test_move_finger_and_skill_finger_together() -> void:
	var c := _controller()
	c.handle_event(_touch(0, Vector2(200, 900), true), 0.0)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(200, 990)
	c.touch_input.flick_min_distance = INF
	c.handle_event(drag, 0.5)
	c.handle_event(_touch(1, c.skill_button_center(), true), 0.6)
	c._physics_process(DT)
	assert_float(player.move_input.y).is_greater(0.9)
	assert_bool(caster.input.is_down()).is_true()
	# 스킬 손가락을 떼도 이동은 유지
	c.handle_event(_touch(1, c.skill_button_center(), false), 0.65)
	c._physics_process(DT)
	assert_float(player.move_input.y).is_greater(0.9)


func test_flick_dash_then_button_press_is_pado() -> void:
	var c := _controller()
	var e := _enemy_at(Vector2(150, 0))
	c.handle_event(_touch(0, Vector2(200, 900), true), 0.0)
	c.handle_event(_touch(0, Vector2(330, 900), false), 0.05)  # 오른쪽 플릭
	assert_bool(player.is_dashing()).is_true()
	c.handle_event(_touch(1, c.skill_button_center(), true), 0.08)
	assert_bool(caster.is_ready(SkillCaster.Skill.PADO)).is_false()
	assert_int(e.health.current).is_less(e.health.max)
