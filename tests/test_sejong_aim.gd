extends GdUnitTestSuite
## 세종 기술이 영웅 자리 대신 겨눈 적 자리에 떨어진다 (SkillAim, SkillKit.skills_at_target).

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const SEJONG := preload("res://data/heroes/sejong.tres")

var enemies: Array = []


func before_test() -> void:
	enemies = []


func _ctx(hero: HeroData, skill: SkillDef = null) -> SkillContext:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	add_child(p)
	p.hero = hero
	p.global_position = Vector2.ZERO
	p.facing = Vector2.RIGHT
	var ctx := SkillContext.new()
	ctx.player = p
	ctx.world = self
	ctx.skill = skill
	ctx.enemy_source = func() -> Array: return enemies
	return ctx


func _enemy_at(pos: Vector2) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = pos
	enemies.append(e)
	return e


func test_only_sejong_aims_at_enemies() -> void:
	assert_bool(SEJONG.kit.skills_at_target).is_true()
	for id in ["yi_sun_sin", "gwanggaeto", "shin_saimdang"]:
		var h: HeroData = load("res://data/heroes/%s.tres" % id)
		assert_bool(h.kit.skills_at_target).is_false()  # 다른 세 영웅은 예전 그대로
	assert_bool(SkillAim.enabled(_ctx(load("res://data/heroes/yi_sun_sin.tres")))).is_false()


func test_point_is_the_nearest_enemy() -> void:
	var ctx := _ctx(SEJONG)
	_enemy_at(Vector2(0, -400))
	var near := _enemy_at(Vector2(300, 0))
	assert_vector(SkillAim.point(ctx)).is_equal_approx(near.global_position, Vector2(0.01, 0.01))


func test_point_is_clipped_to_range() -> void:
	var ctx := _ctx(SEJONG)
	_enemy_at(Vector2(700, 0))  # 찾는 거리 안, 사거리 밖
	var p := SkillAim.point(ctx)
	assert_float(p.length()).is_equal_approx(SEJONG.kit.target_range, 0.01)
	assert_float(p.normalized().x).is_equal_approx(1.0, 0.001)


func test_no_enemy_goes_forward_default_distance() -> void:
	var ctx := _ctx(SEJONG)
	assert_vector(SkillAim.point(ctx)).is_equal_approx(Vector2.RIGHT * SEJONG.kit.target_default, Vector2(0.01, 0.01))


func test_counter_prefers_the_attacker() -> void:
	var ctx := _ctx(SEJONG)
	_enemy_at(Vector2(100, 0))
	var attacker := _enemy_at(Vector2(0, 250))
	attacker.attack.state = EnemyAttack.State.WINDUP
	assert_object(SkillAim.target(ctx, true)).is_same(attacker)
	assert_object(SkillAim.target(ctx, false)).is_not_same(attacker)


func test_meteor_lands_on_the_enemy() -> void:
	var skill := SEJONG.kit.dash as MeteorSkill
	var ctx := _ctx(SEJONG, skill)
	var e := _enemy_at(Vector2(0, -320))
	var run := skill.cast(ctx, 0.0) as MeteorSkill.StarRun
	assert_vector(run.at).is_equal_approx(e.global_position, Vector2(0.01, 0.01))


func test_meteor_stays_on_hero_for_other_kits() -> void:
	var skill := SEJONG.kit.dash as MeteorSkill
	var ctx := _ctx(load("res://data/heroes/yi_sun_sin.tres"), skill)
	_enemy_at(Vector2(0, -320))
	var run := skill.cast(ctx, 0.0) as MeteorSkill.StarRun
	assert_vector(run.at).is_equal(Vector2.ZERO)


func test_constellation_last_star_on_enemy() -> void:
	var skill := SEJONG.kit.charge as ConstellationSkill
	var e := _enemy_at(Vector2(350, 0))
	var pts := skill.star_points(Vector2.ZERO, Vector2.RIGHT, 5, 350.0)
	assert_vector(pts[pts.size() - 1]).is_equal_approx(e.global_position, Vector2(0.01, 0.01))


func test_jeongeum_ring_follows_the_enemy() -> void:
	var skill := SEJONG.kit.tap as JeongeumSkill
	var ctx := _ctx(SEJONG, skill)
	var e := _enemy_at(Vector2(200, 0))
	skill.cast(ctx, 0.0)
	var ring: OrbitGlyphs = null
	for c in get_children():
		if c is OrbitGlyphs:
			ring = c
	assert_object(ring).is_not_null()
	assert_object(ring.follow).is_same(e)
	assert_vector(ring.global_position).is_equal_approx(e.global_position, Vector2(0.01, 0.01))
	ring.queue_free()


func test_jeongeum_ring_hits_the_enemy_it_sits_on() -> void:
	var skill := SEJONG.kit.tap as JeongeumSkill
	var ctx := _ctx(SEJONG, skill)
	var e := _enemy_at(Vector2(200, 0))
	e.health.max = 1000
	e.health.current = 1000
	skill.cast(ctx, 0.0)
	for c in get_children():
		if c is OrbitGlyphs:
			(c as OrbitGlyphs)._physics_process(0.016)
			c.queue_free()
	assert_int(e.health.current).is_less(1000)  # 가운데 적도 맞는다
