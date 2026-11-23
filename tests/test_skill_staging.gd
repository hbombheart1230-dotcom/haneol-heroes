extends GdUnitTestSuite
## 기술 연출 고도화: 휘감아 차례로 베기(SweepRun), 별 하나씩(StarChainRun), 조각 등장·바늘·눈금·자국(VfxPieces·VfxGround),
## 해일검기 잔상·물보라. 대상·피해·쿨타임(밸런스)은 그대로이고 맞는 "순간"과 그림만 바뀐다.

const YI := preload("res://data/heroes/yi_sun_sin.tres")
const SJ := preload("res://data/heroes/sejong.tres")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
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
	player.hero = YI
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
		if c is DamageZone or c is Projectile or c is VfxDecals:
			remove_child(c)
			c.free()
	EnemyAttack.active_windups = 0


func _enemy_at(pos: Vector2) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = pos
	e.health.max = 1000
	e.health.current = 1000
	enemies.append(e)
	return e


func _run(run: SkillRun, seconds: float) -> void:
	var t := 0.0
	while t < seconds and not run.finished:
		run.tick(DT)
		t += DT


# --- 휘감아 차례로 베기 ---

func test_sweep_delay_follows_angle_and_direction() -> void:
	var c := Vector2.ZERO
	assert_float(SweepRun.delay_of(c, Vector2(100, 0), 0.0, 1.0, 0.4)).is_equal_approx(0.0, 0.0001)
	assert_float(SweepRun.delay_of(c, Vector2(0, 100), 0.0, 1.0, 0.4)).is_equal_approx(0.1, 0.0001)  # 화면 시계 방향 1/4
	assert_float(SweepRun.delay_of(c, Vector2(-100, 0), 0.0, 1.0, 0.4)).is_equal_approx(0.2, 0.0001)
	assert_float(SweepRun.delay_of(c, Vector2(0, 100), 0.0, -1.0, 0.4)).is_equal_approx(0.3, 0.0001)  # 반대로 돌면 3/4
	assert_float(SweepRun.delay_of(c, c, 1.0, 1.0, 0.4)).is_equal(0.0)  # 한가운데는 바로


func test_haeryong_cuts_in_sweep_order_with_same_damage() -> void:
	var s: HaeryongSkill = YI.kit.tap.duplicate()
	ctx.skill = s
	var front := _enemy_at(Vector2(100, 0))  # 바라보는 방향 = 붓이 처음 지나는 자리
	var back := _enemy_at(Vector2(-100, 0))
	var far := _enemy_at(Vector2(600, 0))
	var run := s.cast(ctx, 0.0)
	assert_object(run).is_instanceof(SweepRun)
	assert_int(front.health.current).is_equal(1000 - s.damage)  # 누르는 순간
	assert_float(front.knockback.x + (front.launch._dir.x if front.launch.active() else 0.0)).is_greater(0.0)
	assert_int(back.health.current).is_equal(1000)  # 붓이 아직 안 왔다
	assert_bool(run.finished).is_false()
	_run(run, 1.0)
	assert_bool(run.finished).is_true()
	assert_int(back.health.current).is_equal(1000 - s.damage)
	assert_float(back.knockback.x + (back.launch._dir.x if back.launch.active() else 0.0)).is_less(0.0)
	assert_int(far.health.current).is_equal(1000)  # 범위 밖은 그대로
	assert_int(run.hits).is_equal(2)
	assert_float(s.vfx_impact.piece_sweep).is_less_equal(0.2)  # 휘감기가 반응을 늦추지 않게 짧게


func test_haeryong_with_no_enemies_finishes_after_sweep() -> void:
	var s: HaeryongSkill = YI.kit.tap.duplicate()
	ctx.skill = s
	var run := s.cast(ctx, 0.0)
	_run(run, 1.0)
	assert_bool(run.finished).is_true()
	assert_int(run.hits).is_equal(0)


func test_sundial_slows_everyone_at_once_then_ticks_hit_in_order() -> void:
	player.hero = SJ
	var s: SundialSkill = SJ.kit.counter.duplicate()
	ctx.skill = s
	var front := _enemy_at(Vector2(150, 0))
	var back := _enemy_at(Vector2(-150, 0))
	var run := s.cast(ctx, 0.0)
	assert_float(front.speed_scale()).is_less(1.0)
	assert_float(back.speed_scale()).is_less(1.0)  # 느려짐은 모두에게 바로 (지키는 힘 그대로)
	assert_int(front.health.current).is_equal(1000 - s.damage)
	assert_int(back.health.current).is_equal(1000)
	_run(run, 1.0)
	assert_int(back.health.current).is_equal(1000 - s.damage)
	assert_int(run.hits).is_equal(2)


func test_sweep_ticks_fire_once_each_in_order() -> void:
	var got: Array[int] = []
	var none: Array[Enemy] = []
	var run := SweepRun.new(func(_e: Enemy) -> bool: return true, Vector2.ZERO, none, 0.0, 1.0, 0.4, 12,
		func(i: int) -> void: got.append(i))
	assert_array(got).is_equal([0])  # 첫 눈금은 바로
	_run(run, 1.0)
	assert_int(got.size()).is_equal(12)
	for i in 12:
		assert_int(got[i]).is_equal(i)


func test_sundial_data_has_hand_and_twelve_ticks() -> void:
	var v: SkillVfxData = SJ.kit.counter.vfx_impact
	assert_bool(v.sweep_hand).is_true()
	assert_int(v.tick_count).is_equal(12)
	assert_int(v.piece_count).is_equal(12)
	assert_float(v.ground_time).is_greater(0.0)


func test_constellation_stars_land_one_by_one() -> void:
	var h: HeroData = SJ.duplicate()
	h.kit = SJ.kit.duplicate()
	h.kit.skills_at_target = false  # 예전 모양 (앞쪽 고정 거리)으로 별 순서만 본다 (적 기준은 test_sejong_aim)
	player.hero = h
	var s: ConstellationSkill = SJ.kit.charge.duplicate()
	ctx.skill = s
	var pts := s.star_points(Vector2.ZERO, Vector2.RIGHT, s.star_count(1.0))
	var first := _enemy_at(pts[0] * 0.5)
	var last := _enemy_at(pts[pts.size() - 1].lerp(pts[pts.size() - 2], 0.5))
	var run := s.cast(ctx, 1.0)
	assert_int(first.health.current).is_equal(1000 - s.damage)
	assert_int(last.health.current).is_equal(1000)  # 마지막 별은 아직
	_run(run, 2.0)
	assert_bool(run.finished).is_true()
	assert_int(last.health.current).is_equal(1000 - s.damage)
	assert_int(first.health.current).is_equal(1000 - s.damage)  # 같은 적은 한 번만


# --- 그림 연출 ---

func _piece_data() -> SkillVfxData:
	var d := SkillVfxData.new()
	d.decal = PlaceholderTexture2D.new()
	d.piece_count = 8
	d.piece_sweep = 0.2
	return d


func test_piece_progress_staggers_pieces() -> void:
	assert_float(VfxPieces.piece_progress(0.0, 0, 8, 0.2, 0.1)).is_equal(0.0)
	assert_float(VfxPieces.piece_progress(0.05, 0, 8, 0.2, 0.1)).is_equal_approx(0.5, 0.001)
	assert_float(VfxPieces.piece_progress(0.05, 4, 8, 0.2, 0.1)).is_equal(0.0)  # 뒤 조각은 아직
	assert_float(VfxPieces.piece_progress(0.5, 7, 8, 0.2, 0.1)).is_equal(1.0)


func test_piece_data_bursts_as_pieces_not_whole_image() -> void:
	var v: VfxDecals = auto_free(VfxDecals.new())
	var d := _piece_data()
	d.ground_time = 1.0
	d.sweep_hand = true
	v.burst(d, Vector2.ZERO, Vector2.RIGHT, 0)
	assert_int(v.count()).is_equal(0)  # 한 장 통째는 없다
	assert_int(v.pieces.set_count()).is_equal(1)
	assert_int(v.pieces.hand_count()).is_equal(1)
	assert_int(v.ground.count()).is_equal(1)
	v.pieces.step(5.0)
	v.ground.step(5.0)
	assert_int(v.pieces.set_count()).is_equal(0)
	assert_int(v.pieces.hand_count()).is_equal(0)
	assert_int(v.ground.count()).is_equal(0)


func test_pieces_marks_ticks_gather_are_capped() -> void:
	var p: VfxPieces = auto_free(VfxPieces.new())
	var d := _piece_data()
	d.hit_mark_size = 100.0
	d.tick_count = 12
	d.gather_time = 0.3
	d.sweep_hand = true
	for i in 100:
		p.pieces(d, Vector2.ZERO, Vector2.RIGHT, 6)
		p.hit_mark(d, Vector2.ZERO, Vector2.RIGHT, 6)
		p.tick_glint(d, Vector2.ZERO, 0.0, i % 12, 6)
		p.gather(d, Vector2.ZERO, 6)
	assert_int(p.set_count()).is_equal(p.stage.max_piece_sets)
	assert_int(p.hand_count()).is_equal(p.stage.max_hands)
	assert_int(p.mark_count()).is_equal(p.stage.max_hit_marks)
	assert_int(p.glint_count()).is_equal(p.stage.max_ticks)
	assert_int(p.gather_count()).is_equal(p.stage.max_gather)


func test_no_marks_without_data() -> void:
	var p: VfxPieces = auto_free(VfxPieces.new())
	var d := SkillVfxData.new()
	p.hit_mark(d, Vector2.ZERO, Vector2.RIGHT, 0)
	p.gather(d, Vector2.ZERO, 0)
	p.tick_glint(d, Vector2.ZERO, 0.0, 0, 0)
	p.pieces(d, Vector2.ZERO, Vector2.RIGHT, 0)
	p.hit_mark(null, Vector2.ZERO, Vector2.RIGHT, 0)
	assert_int(p.mark_count() + p.gather_count() + p.glint_count() + p.set_count()).is_equal(0)


func test_everything_draws_in_tree_without_errors() -> void:
	var v := VfxDecals.new()
	add_child(v)
	var d := _piece_data()
	d.sweep_hand = true
	d.tick_count = 12
	d.hit_mark_size = 90.0
	d.gather_time = 0.3
	d.ground_time = 0.5
	d.glow = 0.5
	v.burst(d, Vector2(50, 50), Vector2.RIGHT, 4)
	v.pieces.hit_mark(d, Vector2.ZERO, Vector2.UP, 0)
	v.pieces.tick_glint(d, Vector2.ZERO, 0.0, 3, 0)
	v.pieces.gather(d, Vector2.ZERO, 0)
	v.strip(PlaceholderTexture2D.new(), Vector2.ZERO, Vector2(300, 0), 100.0, 0.5, 0.15)
	for i in 6:
		await get_tree().process_frame
		v._process(0.06)
	assert_int(v.strip_count()).is_greater_equal(0)


# --- 순신 데이터 ---

func test_yi_skills_are_staged() -> void:
	assert_int(YI.kit.tap.vfx_impact.piece_count).is_greater(0)  # 해룡참: 휘감기
	assert_int(YI.kit.counter.vfx_impact.piece_count).is_greater(0)  # 반격: 터지며 펼침
	assert_float(YI.kit.tap.vfx_hit.hit_mark_size).is_greater(0.0)  # 맞은 적마다 베인 자국
	var h: HaeilSkill = YI.kit.charge
	assert_object(h.wave_wake).is_not_null()
	assert_int(h.wave_ghosts).is_greater(0)


func test_haeil_wave_carries_ghosts_and_wake() -> void:
	var s: HaeilSkill = YI.kit.charge.duplicate()
	ctx.skill = s
	var run := s.cast(ctx, 1.0)
	var p: Projectile = run.get_meta(&"projectile")
	assert_int(p.ghosts).is_equal(s.wave_ghosts)
	assert_object(p.wake).is_same(s.wave_wake)
	assert_float(p.launch_stretch).is_greater(0.0)
	for i in 10:
		p._physics_process(DT)  # Feedback 없이도 안전
	p._surge_scale()


func test_stage_kick_scales_with_damage_and_caps() -> void:
	var st := SkillStageFeel.new()
	assert_float(st.kick_for(10)).is_less(st.kick_for(40))
	assert_float(st.kick_for(100000)).is_equal(st.kick_cap)
	assert_float(st.trauma_for(100000)).is_equal(st.trauma_cap)
	assert_float(st.kick_for(-5)).is_equal(0.0)
	assert_object(SkillStageFeel.get_default()).is_not_null()
