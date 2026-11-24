extends GdUnitTestSuite
## 넓히기 (2026-11-24, 사용자 승인): 한 번에 끝나던 기술은 성격대로 몇 타로 (BeatHits), 충전 기술은 마디가 계단으로 (ChargeScaling.stepped).
## 타마다 피해 한 번, 총 피해는 그대로, 멈춤은 모든 타 뒤 한 번 (SkillMultiHit.finale). 다 모은 세기는 예전 직선의 끝과 같다.

const GW := preload("res://data/heroes/gwanggaeto.tres")
const SJ := preload("res://data/heroes/sejong.tres")
const SA := preload("res://data/heroes/shin_saimdang.tres")
const YI := preload("res://data/heroes/yi_sun_sin.tres")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const HEAVY := preload("res://data/enemies/heavy.tres")
const DT := 1.0 / 60.0

var player: Player
var enemies: Array = []
var ctx: SkillContext


func before_test() -> void:
	enemies = []
	SkillMultiHit.reset()
	player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	player.hero = GW
	add_child(player)
	player.global_position = Vector2.ZERO
	player.facing = Vector2.RIGHT
	ctx = SkillContext.new()
	ctx.player = player
	ctx.world = self
	ctx.projectile_scene = PROJECTILE_SCENE
	ctx.hit_stop_enabled = false
	ctx.enemy_source = func() -> Array: return enemies


func after_test() -> void:
	for c in get_children():
		if c is DamageZone or c is Projectile or c is WaveRake:
			remove_child(c)
			c.free()
	EnemyAttack.active_windups = 0
	SkillMultiHit.reset()


func _enemy_at(pos: Vector2) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = HEAVY
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = pos
	e.health.max = 9999
	e.health.current = 9999
	enemies.append(e)
	return e


## 맞을 때마다 피해를 적는다.
func _log(e: Enemy) -> Array:
	var got: Array = []
	e.health.damaged.connect(func(_n: Node, _t: int, _a: int, _i: int, _m: float, applied: int) -> void: got.append(applied))
	return got


## 기술 진행 + 박자 타격을 seconds초 돌린다.
func _play(run: SkillRun, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		if run:
			run.tick(DT)
		for n in get_children():
			if n is WaveRake and not n.is_queued_for_deletion():
				(n as WaveRake)._physics_process(DT)
		t += DT


func _sum(a: Array) -> int:
	var s := 0
	for v in a:
		s += int(v)
	return s


## 광개토는 적은 타수에 무게 (쿵-쾅, 쿵-쿵-쾅), 마지막 타가 가장 크다. 날리기는 마지막 타에.
func test_gwanggaeto_slams_are_few_heavy_beats() -> void:
	var cases := [[GW.kit.tap, 2], [GW.kit.counter, 3]]
	for c in cases:
		var s: SkillDef = c[0]
		var e := _enemy_at(Vector2(100, 0))
		var got := _log(e)
		var run := s.cast(ctx, 0.0)
		assert_int(run.hits).is_equal(1)
		assert_array(got).is_empty()  # 첫 쿵은 다음 물리 틱
		_play(null, 1.0)
		assert_int(got.size()).is_equal(int(c[1]))
		assert_int(_sum(got)).is_equal(int(s.get("damage")))
		assert_int(int(got[got.size() - 1])).is_greater(int(got[0]))
		enemies.clear()
		e.queue_free()


func test_thunder_trail_rumbles_then_cracks() -> void:
	var s: ThunderTrailSkill = GW.kit.dash
	player.request_dash(Vector2.RIGHT)
	player.global_position = Vector2(300, 0)
	var e := _enemy_at(Vector2(150, 10))
	var got := _log(e)
	_play(s.cast(ctx, 0.0), 1.0)
	assert_int(got.size()).is_equal(s.beats)
	assert_int(_sum(got)).is_equal(s.damage)


## 사임당 매화: 꽃잎처럼 가볍게 여러 번, 바깥 적은 조금 늦게.
func test_plum_petals_many_light_hits_outer_later() -> void:
	player.hero = SA
	var s: PlumBlossomSkill = SA.kit.counter
	var near := _enemy_at(Vector2(40, 0))
	var far := _enemy_at(Vector2(240, 0))
	var gn := _log(near)
	var gf := _log(far)
	s.cast(ctx, 0.0)
	_play(null, 0.06)
	assert_int(gn.size()).is_greater(gf.size())  # 꽃잎이 바깥에 늦게 닿는다
	_play(null, 1.0)
	assert_int(gn.size()).is_equal(s.beats)
	assert_int(gn.size()).is_greater_equal(5)
	assert_int(_sum(gn)).is_equal(s.damage)
	assert_int(_sum(gf)).is_equal(s.damage)


## 세종 성좌진: 선이 긋고 별빛이 한 번 더 (두 타), 같은 적은 별자리 하나에 한 번만.
func test_constellation_line_then_twinkle() -> void:
	player.hero = SJ
	var h: HeroData = SJ.duplicate()
	h.kit = SJ.kit.duplicate()
	h.kit.skills_at_target = false
	player.hero = h
	var s: ConstellationSkill = SJ.kit.charge
	var pts := s.star_points(Vector2.ZERO, Vector2.RIGHT, s.star_count(1.0))
	var e := _enemy_at(pts[0] * 0.5)
	var got := _log(e)
	_play(s.cast(ctx, 1.0), 2.0)
	assert_int(got.size()).is_equal(s.twinkle_hits)
	assert_int(_sum(got)).is_equal(s.damage)


## 멈춤은 모든 타가 끝난 뒤 한 번 (그 전엔 없음).
func test_one_finale_after_all_beats() -> void:
	var s: ConquerorSkill = GW.kit.counter
	_enemy_at(Vector2(100, 0))
	s.cast(ctx, 0.0)
	_play(null, s.beat_interval * (s.beats - 1) - 0.03)
	assert_int(SkillMultiHit._last_finale_ms).is_equal(-1000000)
	_play(null, 0.5)
	assert_int(SkillMultiHit._last_finale_ms).is_not_equal(-1000000)


## 박자를 1로 두면 예전처럼 한 번에 (데이터로 끌 수 있다).
func test_beats_one_is_the_old_single_hit() -> void:
	var s: QuakeSkill = GW.kit.tap.duplicate()
	s.beats = 1
	var e := _enemy_at(Vector2(100, 0))
	s.cast(ctx, 0.0)
	assert_int(e.health.current).is_equal(9999 - s.damage)


## 충전 마디: 넷 다 마디 3, 다른 셋은 계단. 바로 놓음 = 예전 최소, 다 모음 = 예전 최대, 마디 사이는 같은 값, 다 모은 순간 뛴다.
func test_charge_steps_keep_ends_and_jump_at_marks() -> void:
	var lt: LightningSkill = GW.kit.charge
	var cs: ConstellationSkill = SJ.kit.charge
	var cv: CanvasSkill = SA.kit.charge
	assert_int(lt.bolt_count(0.0)).is_equal(lt.min_bolts)
	assert_int(lt.bolt_count(1.0)).is_equal(lt.max_bolts)
	assert_int(cs.star_count(0.0)).is_equal(cs.min_stars)
	assert_int(cs.star_count(1.0)).is_equal(cs.max_stars)
	assert_float(cv.radius_for(0.0)).is_equal(cv.min_radius)
	assert_float(cv.radius_for(1.0)).is_equal(cv.max_radius)
	assert_float(cv.hold_for(1.0)).is_equal(cv.max_hold)
	for sk in [lt, cs, cv]:
		var sc: ChargeScaling = (sk as SkillDef).charge_scaling
		assert_bool(sc.stepped).is_true()
		assert_int(sc.stages).is_equal(3)
	# 마디 안에서는 같다, 마디를 넘으면 오른다, 다 모은 순간 한 번 더 뛴다
	assert_int(lt.bolt_count(0.4)).is_equal(lt.bolt_count(0.6))
	assert_int(lt.bolt_count(0.7)).is_greater(lt.bolt_count(0.6))
	assert_int(lt.bolt_count(1.0)).is_greater(lt.bolt_count(0.98))
	assert_float(cv.radius_for(1.0)).is_greater(cv.radius_for(0.98))
	assert_int(cs.star_count(1.0)).is_greater(cs.star_count(0.98))
	# 해일검기는 이어서 (계단 아님): 그대로
	assert_bool(YI.kit.charge.charge_scaling.stepped).is_false()


## 놓는 순간 공통 연출: 다 모았을 때만 true (번쩍임·고리).
func test_release_full_only() -> void:
	var lt: LightningSkill = GW.kit.charge
	assert_bool(ChargeRelease.play(ctx, lt, 0.5, Vector2.ZERO, Vector2.RIGHT)).is_false()
	assert_bool(ChargeRelease.play(ctx, lt, 1.0, Vector2.ZERO, Vector2.RIGHT)).is_true()
	var bare := SkillDef.new()
	assert_bool(ChargeRelease.play(ctx, bare, 1.0, Vector2.ZERO, Vector2.RIGHT)).is_false()


## 세종 유성: 본 충격(가장 크다) 뒤 여진, 총 피해는 그대로, 기절은 본 충격에.
func test_meteor_impact_then_aftershocks() -> void:
	player.hero = SJ
	var s: MeteorSkill = SJ.kit.dash.duplicate()
	var e := _enemy_at(Vector2(40, 0))
	var got := _log(e)
	_play(s.cast(ctx, 0.0), 1.5)
	assert_int(got.size()).is_equal(s.beats)
	assert_int(_sum(got)).is_equal(s.damage)
	assert_int(int(got[0])).is_greater(int(got[got.size() - 1]))
	assert_bool(e.is_stunned()).is_true()


## 나눠도 판정은 누른 순간 하나: 맡긴 순간의 받는 피해 배율(처벌 창 등)이 뒤 타에도 그대로.
func test_beats_keep_the_cast_moment_multiplier() -> void:
	var e := _enemy_at(Vector2(100, 0))
	var got := _log(e)
	e._damage_mult = 1.5  # 처벌 창 (경직 중)
	var mod := HealthModifier.new(0, 1.5)
	e.health.modifiers[HealthActionType.Enum.NONE] = mod
	e.health.modifiers[HealthActionType.Enum.KINETIC] = mod
	var s: QuakeSkill = GW.kit.tap
	s.cast(ctx, 0.0)
	e._damage_mult = 1.0  # 첫 쿵 전에 처벌 창이 닫힘
	var plain := HealthModifier.new(0, 1.0)
	e.health.modifiers[HealthActionType.Enum.NONE] = plain
	e.health.modifiers[HealthActionType.Enum.KINETIC] = plain
	_play(null, 1.0)
	assert_int(_sum(got)).is_equal(roundi(s.damage * 1.5))
