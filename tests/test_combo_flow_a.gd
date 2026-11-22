extends GdUnitTestSuite
## 연계 선택지 (사용자 승인): F1 넷째 탭은 3타가 닿은 뒤에, M1 손 평타는 움직이는 중에도 보이고 휘두르는 동안 느리게,
## 대시는 휘두름을 끊고, 맞는 중에 친 타도 보인다.

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const YI := preload("res://data/heroes/yi_sun_sin.tres")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const DT := 1.0 / 60.0


func after_test() -> void:
	EnemyAttack.active_windups = 0
	GameTime.reset()


func _rig() -> Array:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	p.hero = YI
	add_child(p)
	p.set_physics_process(false)
	var a := AutoAttack.new()
	a.name = "AutoAttack"
	a.player = p
	a.data = YI.attack
	a.projectile_scene = PROJECTILE_SCENE
	a.projectile_parent = self
	p.add_child(a)
	a.set_physics_process(false)
	var c := SkillCaster.new()
	c.name = "SkillCaster"
	c.player = p
	c.kit = YI.kit
	c.projectile_scene = PROJECTILE_SCENE
	c.world = self
	var enemies: Array = []
	c.enemy_source = func() -> Array: return enemies
	p.add_child(c)
	c.set_physics_process(false)
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = Vector2(80, 0)
	e.health.max = 9999
	e.health.current = 9999
	enemies.append(e)
	return [p, a, c, enemies]


## F1: 3타를 친 직후 넷째 탭은 기억만 하고, 3타가 닿고 finisher_after_strike 뒤에 해룡참이 나간다.
func test_finisher_waits_for_third_hit_contact() -> void:
	var r := _rig()
	var a: AutoAttack = r[1]
	var c: SkillCaster = r[2]
	var t := 0.0
	var casts: Array = []
	c.skill_started.connect(func(s: SkillCaster.Slot, _d: SkillDef) -> void: casts.append([s, a._melee_left < 0.0, a._since_strike]))
	for i in 3:  # 1·2·3타
		while not a.can_manual(c.tap_gap()):
			t += DT
			a.tick(DT, r[3])
			c.tick(DT, t)
		c.combo_tap()
	assert_bool(a._melee_left >= 0.0).is_true()  # 3타가 아직 닿기 전
	assert_int(c.combo_tap()).is_equal(SkillCaster.Slot.NONE)  # 넷째 탭은 기억만
	for i in 60:
		t += DT
		a.tick(DT, r[3])
		c.tick(DT, t)
	assert_int(casts.size()).is_equal(1)
	assert_bool(casts[0][1]).is_true()  # 칼이 닿은 뒤
	assert_float(casts[0][2]).is_greater_equal(YI.kit.finisher_after_strike - 0.001)


## M1: 손으로 휘두르는 동안 걷기 속도가 swing_move_mult배.
func test_manual_swing_slows_walking() -> void:
	var r := _rig()
	var p: Player = r[0]
	var a: AutoAttack = r[1]
	p.move_input = Vector2.RIGHT
	for i in 30:
		p.compute_velocity(DT)
	var free_speed := p.compute_velocity(DT).length()
	a.manual_strike(1, false, r[3])
	for i in 7:  # 전진(step-in) 밀림이 끝난 뒤
		p.compute_velocity(DT)
	var slow_speed := p.compute_velocity(DT).length()
	assert_float(slow_speed).is_less(free_speed * (YI.attack.swing_move_mult + 0.15))


## 대시가 닿기 전 휘두름을 끊는다.
func test_dash_cancels_pending_swing() -> void:
	var r := _rig()
	var p: Player = r[0]
	var a: AutoAttack = r[1]
	var c: SkillCaster = r[2]
	c.auto_attack()  # 신호 연결
	a.manual_strike(1, false, r[3])
	assert_bool(a._melee_left >= 0.0).is_true()
	p.request_dash(Vector2.UP)
	assert_float(a._melee_left).is_less(0.0)


## 손으로 친 타는 움직이는 중에도, 맞는 동작 중에도 공격 동작이 보인다.
func test_view_shows_manual_swing_while_moving_and_hurt() -> void:
	var r := _rig()
	var p: Player = r[0]
	var a: AutoAttack = r[1]
	var v := PlayerView.new()
	v.player = p
	p.add_child(v)
	p.move_input = Vector2.RIGHT
	for i in 20:
		p.compute_velocity(DT)
	a.manual_strike(1, false, r[3])
	assert_str(v.current_anim()).starts_with("attack")
	p._take_hit(5)
	a._since_manual = 99.0
	a._melee_left = -1.0
	a._since_strike = 99.0
	a.manual_strike(2, false, r[3])
	assert_str(v.current_anim()).starts_with("attack")
