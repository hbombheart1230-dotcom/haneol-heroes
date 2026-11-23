extends GdUnitTestSuite
## 정예 보상 큰 변형: 소용돌이, 물보라, 세 갈래, 사방 검기가 실제 전투에서 동작한다.

const HERO := preload("res://data/heroes/yi_sun_sin.tres")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")

var player: Player
var enemies: Array = []
var ctx: SkillContext


func before_test() -> void:
	enemies = []
	player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	add_child(player)
	player.global_position = Vector2.ZERO
	ctx = SkillContext.new()
	ctx.player = player
	ctx.world = self
	ctx.projectile_scene = PROJECTILE_SCENE
	ctx.hit_stop_enabled = false
	ctx.enemy_source = func() -> Array: return enemies


## 기술이 테스트 스위트(월드)에 붙인 소용돌이·투사체를 다음 테스트로 넘기지 않는다.
func after_test() -> void:
	for c in get_children():
		if c is DamageZone or c is Projectile:
			remove_child(c)
			c.free()


func _enemy_at(pos: Vector2) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = pos
	enemies.append(e)
	return e


func _projectiles() -> Array:
	return get_children().filter(func(c: Node) -> bool: return c is Projectile and not c.is_queued_for_deletion())


func test_whirlpool_lingers_and_keeps_hitting() -> void:
	var s: HaeryongSkill = HERO.kit.tap.duplicate()
	s.whirl_time = 1.0
	s.whirl_interval = 0.2
	var e := _enemy_at(Vector2(60, 0))
	var hp0: int = e.health.current
	s.cast(ctx, 0.0)
	var zones := get_children().filter(func(c: Node) -> bool: return c is DamageZone)
	assert_int(zones.size()).is_equal(1)
	var z: DamageZone = zones[0]
	var after_cast: int = e.health.current
	assert_int(after_cast).is_less(hp0)
	for i in 30:
		z._physics_process(1.0 / 60.0)
	assert_int(z.ticks).is_greater_equal(2)
	assert_int(e.health.current).is_less(after_cast)  # 소용돌이가 추가 피해


func test_zone_ignores_dead_enemies() -> void:
	# Codex c2a822b 회귀: 소용돌이가 죽은 적을 끌어당기지 않는다
	var dead := _enemy_at(Vector2(60, 0))
	dead.health.kill()
	var z := DamageZone.new()
	z.ctx = ctx
	z.pull = 100.0
	add_child(z)
	z._physics_process(1.0 / 60.0)
	assert_vector(dead.knockback).is_equal(Vector2.ZERO)


func test_no_whirlpool_without_mutation() -> void:
	HERO.kit.tap.cast(ctx, 0.0)
	assert_int(get_children().filter(func(c: Node) -> bool: return c is DamageZone).size()).is_equal(0)


func test_pado_end_burst_hits_at_path_end() -> void:
	var s: PadoSkill = HERO.kit.dash.duplicate()
	s.end_burst_radius = 150.0
	player.facing = Vector2.RIGHT
	var far := _enemy_at(Vector2(s.length + 120.0, 0))  # 물길 밖, 폭발 범위 안
	var hp0: int = far.health.current
	var run := s.cast(ctx, 0.0)
	while not run.tick(1.0 / 60.0):
		pass
	assert_int(far.health.current).is_equal(hp0 - s.end_burst_damage)


func test_haeil_triple_waves_fan_out() -> void:
	var s: HaeilSkill = HERO.kit.charge.duplicate()
	player.facing = Vector2.RIGHT
	s.cast(ctx, 1.0)
	assert_int(_projectiles().size()).is_equal(1)
	for p in _projectiles():
		p.queue_free()
	s.extra_waves = 2
	s.cast(ctx, 1.0)
	var dirs := _projectiles().map(func(p: Projectile) -> float: return rad_to_deg(p.direction.angle()))
	dirs.sort()
	assert_int(dirs.size()).is_equal(3)
	assert_float(dirs[0]).is_equal_approx(-s.spread_degrees, 0.01)
	assert_float(dirs[1]).is_equal_approx(0.0, 0.01)
	assert_float(dirs[2]).is_equal_approx(s.spread_degrees, 0.01)


func test_counter_radial_blades() -> void:
	var s: CounterSlashSkill = HERO.kit.counter.duplicate()
	s.radial_blades = 8
	s.cast(ctx, 0.0)
	var ps := _projectiles()
	assert_int(ps.size()).is_equal(8)
	for p in ps:
		assert_bool((p as Projectile).pierce).is_true()
		var r := WaveRake.of(p as Projectile)  # 검기 긁기: 타마다 나눈 합 = 검기 피해
		assert_int(r.total_damage() if r else (p as Projectile).damage).is_equal(s.blade_damage)
