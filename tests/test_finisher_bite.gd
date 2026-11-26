extends GdUnitTestSuite
## 4타 마무리 칼 박힘 (FinisherBite, 사용자 (가) 2026-11-26 "1<2<3<4"): 순신 해룡참이 처음 닿는 순간
## 멈춤 0.12초·0.05배 + 흔들림 0.40 + w_heavy + 진동 40ms·0.8, 휘감기 끝 0.3배 느려짐 없음, 마무리 멈춤 사이 0.2초.
## 예전 (0570b0b): 휘감기라 적마다 멈추지 않고(defer_stop) 칼 박힘 멈춤(force_next)은 쓰이지 않아, 닿을 때 멈춤 없음 → 끝 0.3배.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const YI := preload("res://data/heroes/yi_sun_sin.tres")

var _was := true


func before_test() -> void:
	_was = GameSettings.haptics_enabled
	GameSettings.haptics_enabled = true
	Haptics.last = []
	FinisherBite.reset()


func after_test() -> void:
	GameSettings.haptics_enabled = _was
	Feedback.instance = null
	GameTime.reset()
	GameTime.clock = Callable()
	SkillHitStop.reset()
	FinisherBite.reset()


func _rig() -> Array:
	var f: Feedback = auto_free(Feedback.new())
	f.camera = auto_free(Camera2D.new())
	add_child(f.camera)
	f.fx = auto_free(FxLayer.new())
	add_child(f.fx)
	f.sfx_enabled = false
	add_child(f)
	var p: Player = auto_free(Player.new())
	add_child(p)
	p.hero = YI
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = Vector2(80, 0)
	var ctx := SkillContext.new()
	ctx.player = p
	ctx.skill = YI.kit.tap
	ctx.finisher_bite = YI.blade_bite
	return [f, p, e, ctx]


func test_values_rank_fourth_above_third() -> void:
	var b: BladeBiteData = YI.blade_bite
	var d := HitImpact.data()
	assert_float(b.finisher_stop).is_equal_approx(0.12, 0.001)
	assert_float(b.finisher_stop_scale).is_equal_approx(0.05, 0.001)
	assert_float(b.finisher_min_gap).is_equal_approx(0.2, 0.001)
	assert_float(b.finisher_cast_trauma).is_equal_approx(0.12, 0.001)
	assert_float(b.finisher_contact_trauma).is_greater(0.3)  # 3타 흔들림 0.30
	assert_str(String(b.finisher_contact_sfx)).is_equal("w_heavy")
	assert_float(b.finisher_haptic_ms * b.finisher_haptic_amp).is_greater(
		HitImpactData.at_i(d.haptic_ms, 3, 0) * HitImpactData.at_f(d.haptic_amp, 3, 0.0))  # 3타 진동보다 세게
	assert_bool(b.finisher_skip_sweep_slow).is_true()


func test_gap_rule() -> void:
	assert_bool(FinisherBite.gap_ok(1000, 700, 0.2)).is_true()
	assert_bool(FinisherBite.gap_ok(1000, 900, 0.2)).is_false()


func test_first_contact_bites_once() -> void:
	var r := _rig()
	var f: Feedback = r[0]
	var e: Enemy = r[2]
	var ctx: SkillContext = r[3]
	assert_bool(ctx.hit(e, 10)).is_true()
	assert_bool(GameTime.is_stopped()).is_true()
	assert_float(Engine.time_scale).is_equal_approx(YI.blade_bite.finisher_stop_scale, 0.001)
	assert_array(Haptics.last).is_equal([YI.blade_bite.finisher_haptic_ms, YI.blade_bite.finisher_haptic_amp])
	assert_float(f.trauma).is_greater_equal(YI.blade_bite.finisher_contact_trauma - 0.001)
	var t := f.trauma
	GameTime.reset()
	assert_bool(ctx.hit(e, 10)).is_true()  # 같은 발동의 다음 적: 다시 멈추지 않는다
	assert_bool(GameTime.is_stopped()).is_false()
	assert_float(f.trauma - t).is_less(YI.blade_bite.finisher_contact_trauma * 0.5)  # 적마다 나던 작은 흔들림(약 0.05)만
	assert_bool(FinisherBite.skips_sweep_slow(ctx)).is_true()


func test_back_to_back_finishers_respect_min_gap() -> void:
	var r := _rig()
	var e: Enemy = r[2]
	assert_bool(FinisherBite.on_contact(r[3], e)).is_true()
	GameTime.reset()
	var ctx2 := SkillContext.new()  # 0.2초 안의 다음 마무리 (다른 발동)
	ctx2.player = r[1]
	ctx2.skill = YI.kit.tap
	ctx2.finisher_bite = YI.blade_bite
	assert_bool(FinisherBite.on_contact(ctx2, e)).is_false()
	assert_bool(GameTime.is_stopped()).is_false()


func test_plain_skill_cast_keeps_old_rules() -> void:
	var r := _rig()
	var ctx: SkillContext = r[3]
	ctx.finisher_bite = null  # 단추로 쓴 해룡참·다른 영웅 = 예전대로
	assert_bool(ctx.hit(r[2], 10)).is_true()
	assert_bool(FinisherBite.skips_sweep_slow(ctx)).is_false()
	assert_array(Haptics.last).is_equal([30, HitImpactData.at_f(HitImpact.data().haptic_amp, 3, 0.0)])


func test_min_gap_uses_game_clock() -> void:
	# 간격은 GameTime.now_ms() (시뮬레이션 판 시각과 같게, 통합 검토 4589ae0f ②)
	var now := [5000]
	GameTime.clock = func() -> int: return now[0]
	var r := _rig()
	var e: Enemy = r[2]
	assert_bool(FinisherBite.on_contact(r[3], e)).is_true()
	GameTime.reset()
	var mk := func() -> SkillContext:
		var c := SkillContext.new()
		c.player = r[1]
		c.skill = YI.kit.tap
		c.finisher_bite = YI.blade_bite
		return c
	now[0] = 5100
	assert_bool(FinisherBite.on_contact(mk.call(), e)).is_false()
	GameTime.reset()
	now[0] = 5250
	assert_bool(FinisherBite.on_contact(mk.call(), e)).is_true()
