extends GdUnitTestSuite
## 세 번째·네 번째 영웅: 세종(글자·별·시간), 사임당(소환·먹·화폭). 공통: 느려짐, 글자 고리, 소환물.

const SJ := preload("res://data/heroes/sejong.tres")
const SA := preload("res://data/heroes/shin_saimdang.tres")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const HEAVY := preload("res://data/enemies/heavy.tres")
const DT := 1.0 / 60.0

var player: Player
var enemies: Array = []
var ctx: SkillContext


func before_test() -> void:
	enemies = []
	player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	player.hero = SJ
	add_child(player)
	player.global_position = Vector2.ZERO
	ctx = SkillContext.new()
	ctx.player = player
	ctx.world = self
	ctx.projectile_scene = PROJECTILE_SCENE
	ctx.hit_stop_enabled = false
	ctx.enemy_source = func() -> Array: return enemies


func after_test() -> void:
	for c in get_children():
		if c is DamageZone or c is Projectile or c is OrbitGlyphs or c is SummonCritter:
			remove_child(c)
			c.free()
	EnemyAttack.active_windups = 0


func _enemy_at(pos: Vector2) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = HEAVY
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = pos
	enemies.append(e)
	return e


## 박자 타격 (WaveRake: 성좌진 별빛·매화 꽃잎)을 다 끝날 때까지 돌린다.
func _rake_out(frames: int = 60) -> void:
	for i in frames:
		for n in get_children():
			if n is WaveRake and not n.is_queued_for_deletion():
				(n as WaveRake)._physics_process(DT)


func _of(t: Variant) -> Array:
	return get_children().filter(func(c: Node) -> bool: return is_instance_of(c, t))


# --- 공통 ---

func test_slow_reduces_enemy_speed_then_wears_off() -> void:
	var e := _enemy_at(Vector2(200, 0))
	e.target = player
	var v0 := e.compute_velocity([]).length()
	e.slow(0.3, 0.5)
	assert_float(e.compute_velocity([]).length()).is_equal_approx(v0 * 0.3, 0.01)
	for i in 40:
		e._physics_process(DT)
	assert_float(e.speed_scale()).is_equal(1.0)


func test_both_heroes_are_complete_and_playable() -> void:
	for h in [SJ, SA]:
		assert_bool(h.playable).is_true()
		assert_object(h.kit.tap).is_not_null()
		assert_object(h.kit.counter).is_not_null()
		assert_int(h.upgrade_pool.upgrades.size()).is_equal(14)
		assert_int(h.major_pool.upgrades.size()).is_equal(4)
	var b := RunBuild.new()
	for h in [SJ, SA]:
		player.hero = h
		b.begin(player, null, null)
		for pool in [h.upgrade_pool, h.major_pool]:
			for u in (pool as UpgradePool).upgrades:
				for m in u.mods:
					assert_bool(m.property in b.target_of(m.target)).override_failure_message("%s.%s" % [m.target, m.property]).is_true()


# --- 세종 ---

func test_jeongeum_orbit_hits_each_enemy_on_interval() -> void:
	var s: JeongeumSkill = SJ.kit.tap.duplicate()
	var e := _enemy_at(Vector2(s.radius, 0))
	s.cast(ctx, 0.0)
	var rings := _of(OrbitGlyphs)
	assert_int(rings.size()).is_equal(1)
	var o: OrbitGlyphs = rings[0]
	for i in 90:
		o._physics_process(DT)
	assert_int(o.hits).is_between(1, 4)  # 0.5초 간격 제한
	assert_int(e.health.current).is_less(e.health.max)
	s.outer_radius = 190.0
	s.cast(ctx, 0.0)
	assert_int(_of(OrbitGlyphs).size()).is_equal(3)


func test_meteor_falls_after_delay_and_stuns() -> void:
	var s: MeteorSkill = SJ.kit.dash.duplicate()
	var e := _enemy_at(Vector2(60, 0))
	var run := s.cast(ctx, 0.0)
	assert_int(e.health.current).is_equal(e.health.max)
	for i in 20:
		run.tick(DT)
	assert_int(e.health.current).is_equal(e.health.max - s.damage)
	assert_bool(e.is_stunned()).is_true()


func test_constellation_star_count_and_lines() -> void:
	var s: ConstellationSkill = SJ.kit.charge.duplicate()
	assert_int(s.star_count(0.0)).is_equal(s.min_stars)
	assert_int(s.star_count(1.0)).is_equal(s.max_stars)
	player.facing = Vector2.RIGHT
	var pts := s.star_points(Vector2.ZERO, Vector2.RIGHT, 5)
	var e := _enemy_at(pts[0] * 0.5)  # 첫 선 위
	var run := s.cast(ctx, 0.5)
	assert_int(run.hits).is_greater_equal(1)
	_rake_out()
	assert_int(e.health.current).is_less(e.health.max)


func test_sundial_slows_and_major_freezes() -> void:
	var s: SundialSkill = SJ.kit.counter.duplicate()
	var e := _enemy_at(Vector2(200, 0))
	s.cast(ctx, 0.0)
	assert_float(e.speed_scale()).is_less(1.0)
	assert_bool(e.is_stunned()).is_false()
	s.freeze_time = 0.8
	s.cast(ctx, 0.0)
	assert_bool(e.is_stunned()).is_true()


# --- 사임당 ---

func test_critters_summon_and_bite() -> void:
	player.hero = SA
	var s: CritterSkill = SA.kit.tap.duplicate()
	var e := _enemy_at(Vector2(120, 0))
	s.cast(ctx, 0.0)
	var cs := _of(SummonCritter)
	assert_int(cs.size()).is_equal(s.count)
	for i in 120:
		for c in cs:
			(c as SummonCritter)._physics_process(DT)
	assert_int(e.health.current).is_less(e.health.max)
	s.extra_butterflies = 3
	s.cast(ctx, 0.0)
	assert_int(_of(SummonCritter).size()).is_equal(s.count * 2 + 3)


func test_ink_bleed_lays_slowing_zones_on_dash_path() -> void:
	var s: InkBleedSkill = SA.kit.dash.duplicate()
	player.request_dash(Vector2.RIGHT)
	player.global_position = Vector2(300, 0)
	var e := _enemy_at(Vector2(150, 0))
	s.cast(ctx, 0.0)
	var zones := _of(DamageZone)
	assert_int(zones.size()).is_greater_equal(2)
	for z in zones:
		(z as DamageZone)._physics_process(DT)
	assert_float(e.speed_scale()).is_less(1.0)


func test_canvas_traps_then_damages() -> void:
	var s: CanvasSkill = SA.kit.charge.duplicate()
	var e := _enemy_at(Vector2(150, 0))
	var far := _enemy_at(Vector2(400, 0))
	var run := s.cast(ctx, 0.0)
	assert_bool(e.is_stunned()).is_true()
	assert_bool(far.is_stunned()).is_false()
	for i in 45:
		run.tick(DT)
		for n in get_children():  # 조이는 타 (WaveRake)
			if n is WaveRake:
				(n as WaveRake)._physics_process(DT)
	assert_int(e.health.current).is_equal(e.health.max - s.damage)
	assert_float(s.radius_for(1.0)).is_equal(s.max_radius)


func test_plum_blossom_heals_and_hits() -> void:
	var s: PlumBlossomSkill = SA.kit.counter.duplicate()
	player.health.current = 40
	var e := _enemy_at(Vector2(100, 0))
	s.cast(ctx, 0.0)
	assert_int(player.health.current).is_equal(40 + s.heal)
	_rake_out()  # 꽃잎 여러 번 (BeatHits), 총 피해는 그대로
	assert_int(e.health.current).is_equal(e.health.max - s.damage)
