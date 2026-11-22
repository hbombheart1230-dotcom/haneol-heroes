extends GdUnitTestSuite
## 영웅 역할 (사용자: "근접은 근접만 원거리는 세종만", 사임당 중거리): 순신·광개토는 사거리 밖 적에게 자동으로 아무것도
## 안 하고 (다가가야 한다), 세종은 붙은 적에게도 글자를 쏘며, 사임당은 230px 안을 붓으로 털어 친다 (탄 없음).

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const DT := 1.0 / 60.0


func after_test() -> void:
	EnemyAttack.active_windups = 0


## [플레이어, 자동 평타, 적]. 적은 움직이지 않는다.
func _rig(hero_id: String, at: Vector2) -> Array:
	var hero: HeroData = load("res://data/heroes/%s.tres" % hero_id)
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	p.hero = hero
	add_child(p)
	p.set_physics_process(false)
	var a: AutoAttack = auto_free(AutoAttack.new())
	a.player = p
	a.data = hero.attack
	a.projectile_scene = PROJECTILE_SCENE
	a.projectile_parent = self
	p.add_child(a)
	a.set_physics_process(false)
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = at
	e.health.max = 9999
	e.health.current = 9999
	return [p, a, e]


func _tick(a: AutoAttack, e: Enemy, seconds: float) -> Array:
	var shots := [0]
	a.projectile_fired.connect(func(_pr: Projectile) -> void: shots[0] += 1)
	var t := 0.0
	while t < seconds:
		t += DT
		a.tick(DT, [e])
		for c in get_children():
			if c is Projectile:
				(c as Projectile)._physics_process(DT)
	return [shots[0], 9999 - e.health.current]


func test_melee_heroes_ignore_out_of_reach_enemies() -> void:
	for id in ["yi_sun_sin", "gwanggaeto"]:
		var r := _rig(id, Vector2(320, 0))
		var hero: HeroData = (r[0] as Player).hero
		assert_bool(hero.attack.use_ranged).is_false()
		var res := _tick(r[1], r[2], 2.0)
		assert_int(res[0]).override_failure_message(id + " shot").is_equal(0)
		assert_int(res[1]).override_failure_message(id + " damage").is_equal(0)
		assert_float((r[0] as Player).global_position.length()).is_equal(0.0)  # 끌려가지 않는다
		(r[2] as Enemy).free()


func test_sejong_shoots_even_point_blank() -> void:
	var r := _rig("sejong", Vector2(45, 0))
	assert_bool((r[0] as Player).hero.attack.use_melee).is_false()
	var a: AutoAttack = r[1]
	var e: Enemy = r[2]
	var shots := [0]
	a.projectile_fired.connect(func(_pr: Projectile) -> void: shots[0] += 1)
	for i in 72:  # 글자는 물리 겹침으로 맞으니 실제 물리 프레임으로 돌린다
		await get_tree().physics_frame
		a.tick(DT, [e])
	assert_int(shots[0]).is_greater(0)
	assert_int(9999 - e.health.current).is_greater(0)  # 바로 앞 적도 맞는다


func test_saimdang_brush_flick_reaches_mid_range_without_projectiles() -> void:
	var r := _rig("shin_saimdang", Vector2(200, 0))
	var d := (r[0] as Player).hero.attack
	assert_float(d.melee_range).is_between(200.0, 260.0)
	var res := _tick(r[1], r[2], 1.5)
	assert_int(res[0]).is_equal(0)
	assert_int(res[1]).is_greater(0)
	# 3타는 둘레 원 (360° 이상), 2타는 좁고 길게
	assert_float(d.melee_arc_degrees * ComboSteps.at(d.step_arc_mults, 3, 1.0)).is_greater_equal(360.0)
	assert_float(d.melee_range * ComboSteps.at(d.step_range_mults, 2, 1.0)).is_greater(d.melee_range)


## 사임당 중거리 자리 (약 210px, 사거리 230 안): 1·2·3타 모두 닿는다 (3타 원 붓질도 230 × 1.0, 검증 지적 4).
func test_saimdang_every_step_reaches_mid_range() -> void:
	var sa: HeroData = load("res://data/heroes/shin_saimdang.tres")
	for dist in [210.0, 225.0]:
		for step in [1, 2, 3]:
			assert_float(sa.attack.melee_range * ComboSteps.at(sa.attack.step_range_mults, step, 1.0)) \
				.override_failure_message("step %d" % step).is_greater_equal(dist)
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	p.hero = sa
	add_child(p)
	p.set_physics_process(false)
	var a := AutoAttack.new()
	a.player = p
	a.data = sa.attack
	p.add_child(a)
	a.set_physics_process(false)
	var e: Enemy = preload("res://scenes/enemy.tscn").instantiate()
	e.data = preload("res://data/enemies/waegun_soldier.tres")
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = Vector2(215, 0)
	e.health.max = 9999
	e.health.current = 9999
	a.manual_strike(3, false, [e])
	for i in 60:
		a.tick(1.0 / 60.0, [e])
	assert_int(e.health.current).is_less(9999)
	EnemyAttack.active_windups = 0
