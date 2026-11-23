extends GdUnitTestSuite
## 기술의 연속 타격 (SkillMultiHit, SkillHitFeelData, SkillContext.tick_hit · on_projectile_hit).

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")

var enemies: Array = []


func before_test() -> void:
	enemies = []
	SkillMultiHit.reset()


func _ctx() -> SkillContext:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	add_child(p)
	p.hero = load("res://data/heroes/yi_sun_sin.tres")
	var ctx := SkillContext.new()
	ctx.player = p
	ctx.world = self
	ctx.projectile_scene = PROJECTILE_SCENE
	ctx.hit_stop_enabled = false
	ctx.enemy_source = func() -> Array: return enemies
	return ctx


func _enemy_at(pos: Vector2) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = pos
	e.health.max = 1000
	e.health.current = 1000
	enemies.append(e)
	return e


func test_tick_hit_damages_without_finale() -> void:
	var ctx := _ctx()
	var e := _enemy_at(Vector2(50, 0))
	assert_bool(ctx.tick_hit(e, 7)).is_true()
	assert_int(e.health.current).is_equal(993)
	assert_bool(SkillMultiHit.finale(ctx)).is_true()  # 아직 마지막 타가 없었으니 바로 멈출 수 있다


func test_last_tick_does_one_big_stop() -> void:
	var ctx := _ctx()
	var e := _enemy_at(Vector2(50, 0))
	assert_bool(ctx.tick_hit(e, 7, true)).is_true()
	assert_bool(SkillMultiHit.finale(ctx)).is_false()  # 방금 크게 멈췄다 → 간격 안에선 다시 안 멈춤
	assert_int(e.health.current).is_equal(993)


func test_zone_last_tick_is_the_finale() -> void:
	var ctx := _ctx()
	var e := _enemy_at(Vector2(30, 0))
	var z: DamageZone = DamageZone.new()
	z.ctx = ctx
	z.radius = 100.0
	z.duration = 0.5
	z.interval = 0.3
	z.damage = 5
	add_child(z)
	z.set_physics_process(false)
	z._physics_process(0.01)  # 첫 틱: 가볍게
	assert_bool(SkillMultiHit.finale(ctx)).is_true()
	SkillMultiHit.reset()
	z._physics_process(0.3)  # 둘째 틱이 마지막 (다음 틱 전에 사라짐) → 크게 한 번
	assert_bool(SkillMultiHit.finale(ctx)).is_false()
	assert_int(e.health.current).is_equal(990)
	z.queue_free()


func test_skill_projectiles_are_watched() -> void:
	var ctx := _ctx()
	var p := ctx.spawn_projectile_configured(func(pr: Projectile) -> void: pr.direction = Vector2.RIGHT)
	var n := 0
	for c in p.action_applied.get_connections():
		n += 1
	assert_int(n).is_greater_equal(2)  # 탄 자신 + 기술 타격감
	var e := _enemy_at(Vector2(80, 0))
	ctx.on_projectile_hit(p, e.get_node("HurtBox2D") as HurtBox2D)  # Feedback 없이도 안전
	p.queue_free()


func test_finale_length_comes_from_data() -> void:
	var d := SkillHitFeelData.new()
	var feel := CombatFeelData.new()
	assert_float(d.finale_seconds(feel)).is_equal_approx(feel.skill_stop_cap * d.finale_stop, 0.0001)
	assert_object(SkillHitFeelData.get_default()).is_not_null()
	assert_int(d.tick_step).is_less(HitImpactData.new().skill_step)  # 틱은 한 번에 끊어 치는 명중보다 작게
