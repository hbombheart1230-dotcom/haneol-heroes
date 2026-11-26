extends GdUnitTestSuite
## 4타 마무리 진동 지킴이 (2026-11-26, 폴드 7 0570b0b "연타 4타가 진동이랑 타격감이 없다").
## 마무리 기술은 누르는 순간 SkillContext.impact → 약한 진동(haptic_impact 15ms·0.5)을 내고, 칼이 닿을 때
## SkillContext.hit → HitImpact.on_swing(skill_step) 센 진동(30ms·0.7)을 낸다. 해룡참은 휘감기라 닿기가 0.08~0.17초 뒤라
## 진동 간격(haptic_min_gap 0.12초) 안에 들면 닿을 때 진동이 통째로 버려졌다 (PC 실측 13번 중 9번).

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const HERO := preload("res://data/heroes/yi_sun_sin.tres")

var _was := true


func before_test() -> void:
	_was = GameSettings.haptics_enabled
	GameSettings.haptics_enabled = true
	Haptics.last = []


func after_test() -> void:
	GameSettings.haptics_enabled = _was
	Feedback.instance = null
	GameTime.reset()
	SkillHitStop.reset()


func _feedback() -> Feedback:
	var f: Feedback = auto_free(Feedback.new())
	f.camera = auto_free(Camera2D.new())
	add_child(f.camera)
	f.fx = auto_free(FxLayer.new())
	add_child(f.fx)
	f.sfx_enabled = false
	add_child(f)
	return f


func test_gap_rule_lets_only_a_stronger_pulse_through() -> void:
	assert_bool(Haptics.passes_gap(0.2, 0.12, 1.0, 99.0)).is_true()  # 간격이 지났으면 늘
	assert_bool(Haptics.passes_gap(0.05, 0.12, 21.0, 7.5)).is_true()  # 간격 안이라도 더 세면
	assert_bool(Haptics.passes_gap(0.05, 0.12, 7.5, 21.0)).is_false()  # 간격 안, 약하면 버림
	assert_bool(Haptics.passes_gap(0.05, 0.12, 7.5, 7.5)).is_false()  # 같은 세기 연달아도 버림


func test_finisher_contact_buzz_survives_the_cast_buzz() -> void:
	var f := _feedback()
	var p: Player = auto_free(Player.new())
	add_child(p)
	p.hero = HERO
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = Vector2(80, 0)
	var ctx := SkillContext.new()
	ctx.player = p
	ctx.skill = HERO.kit.tap
	ctx.impact(p.global_position)  # 누르는 순간 (해룡참 cast)
	assert_array(Haptics.last).is_equal([f.feel.haptic_impact_ms, f.feel.haptic_impact_amp])
	Haptics.last = []
	assert_bool(ctx.hit(e, 10)).is_true()  # 바로 뒤 칼이 닿음 (간격 안)
	var d := HitImpact.data()
	assert_array(Haptics.last).is_equal(
		[HitImpactData.at_i(d.haptic_ms, d.skill_step, 0), HitImpactData.at_f(d.haptic_amp, d.skill_step, 0.0)])
	Haptics.last = []
	f.haptic(12, 0.35)  # 그 뒤 약한 1타 진동은 여전히 간격에 막힌다
	assert_array(Haptics.last).is_empty()


func test_first_tick_of_a_cast_buzzes_like_a_single_hit() -> void:
	# 세종 정음진(4타)은 도는 글자가 0.5초마다 tick_hit만 → 예전엔 닿아도 진동 없음 (마지막 타만 진동).
	var f := _feedback()
	var p: Player = auto_free(Player.new())
	add_child(p)
	p.hero = preload("res://data/heroes/sejong.tres")
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = Vector2(80, 0)
	var ctx := SkillContext.new()
	ctx.player = p
	ctx.skill = p.hero.kit.tap
	assert_bool(ctx.tick_hit(e, 6)).is_true()
	var d := HitImpact.data()
	assert_array(Haptics.last).is_equal(
		[HitImpactData.at_i(d.haptic_ms, d.skill_step, 0), HitImpactData.at_f(d.haptic_amp, d.skill_step, 0.0)])
	Haptics.last = []
	f._last_haptic = -INF
	assert_bool(ctx.tick_hit(e, 6)).is_true()  # 같은 발동의 다음 틱은 예전처럼 진동 없음
	assert_array(Haptics.last).is_empty()


func test_only_sejong_glyphs_buzz_on_first_tick() -> void:
	# 사용자: 사임당 4타는 지금이 좋다 → 물 때마다 impact 15ms 그대로, 첫 틱 30ms는 세종 정음진만.
	assert_bool(preload("res://data/heroes/sejong.tres").kit.tap.first_tick_buzz).is_true()
	assert_bool(preload("res://data/heroes/shin_saimdang.tres").kit.tap.first_tick_buzz).is_false()
	_feedback()
	var p: Player = auto_free(Player.new())
	add_child(p)
	p.hero = preload("res://data/heroes/shin_saimdang.tres")
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	add_child(auto_free(e))
	e.set_physics_process(false)
	var ctx := SkillContext.new()
	ctx.player = p
	ctx.skill = p.hero.kit.tap
	assert_bool(ctx.tick_hit(e, 6)).is_true()
	assert_array(Haptics.last).is_empty()
