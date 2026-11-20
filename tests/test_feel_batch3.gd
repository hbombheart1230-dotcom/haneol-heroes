extends GdUnitTestSuite
## 타격감 3단계 (docs/research/game_feel_benchmark.md B3·D3): 무게 등급 (정예 갑옷·보스 경직 게이지), 기술 명중 멈춤 공통 규칙.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const SOLDIER := preload("res://data/enemies/jurchen_soldier.tres")
const ELITE := preload("res://data/enemies/jurchen_elite.tres")
const BOSS := preload("res://data/enemies/boss_general.tres")


func after_test() -> void:
	Feedback.instance = null
	SkillHitStop.reset()
	GameTime.reset()


func _ai() -> EnemyAIData:
	return Enemy.ai_data()


func _enemy(data: EnemyData, hp_mult: float = 1.0) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = data
	e.hp_mult = hp_mult
	add_child(auto_free(e))
	e.set_physics_process(false)
	return e


func test_trash_has_no_bar_and_full_knockback() -> void:
	var p := EnemyPoise.new(HitReaction.Tier.TRASH, 30, _ai())
	assert_float(p.bar_ratio()).is_equal(-1.0)
	assert_float(p.knockback_mult()).is_equal(1.0)
	assert_int(p.on_damage(999)).is_equal(EnemyPoise.Event.NONE)


func test_elite_armor_blocks_knockback_until_broken_then_regrows() -> void:
	var ai := _ai()
	var p := EnemyPoise.new(HitReaction.Tier.ELITE, 600, ai)
	assert_float(p.armor_max).is_equal_approx(600 * ai.elite_armor_frac, 0.01)
	assert_float(p.knockback_mult()).is_equal(0.0)
	assert_int(p.on_damage(int(p.armor_max) - 1)).is_equal(EnemyPoise.Event.NONE)
	assert_int(p.on_damage(5)).is_equal(EnemyPoise.Event.ARMOR_BREAK)
	assert_float(p.knockback_mult()).is_equal(1.0)
	assert_int(p.on_damage(50)).is_equal(EnemyPoise.Event.NONE)  # 깨진 동안은 다시 깨지지 않음
	p.tick(ai.armor_regen_delay * 0.5)
	assert_bool(p.is_armored()).is_false()
	p.tick(ai.armor_regen_delay)
	assert_bool(p.is_armored()).is_true()
	assert_float(p.bar_ratio()).is_equal(1.0)


func test_boss_never_knocked_back_and_staggers_when_gauge_fills() -> void:
	var ai := _ai()
	var p := EnemyPoise.new(HitReaction.Tier.BOSS, 1000, ai)
	assert_float(p.knockback_mult()).is_equal(0.0)
	var first := p.gauge_max
	assert_int(p.on_damage(int(first) - 1)).is_equal(EnemyPoise.Event.NONE)
	assert_int(p.on_damage(1)).is_equal(EnemyPoise.Event.STAGGER)
	assert_float(p.gauge).is_equal(0.0)
	assert_float(p.gauge_max).is_equal_approx(first * ai.boss_stagger_growth, 0.01)  # 다음은 더 어렵게


func test_split_children_are_trash() -> void:
	assert_int(HitReaction.tier_of(ELITE, false, 0.3)).is_equal(HitReaction.Tier.TRASH)
	assert_int(HitReaction.tier_of(ELITE, true, 1.0)).is_equal(HitReaction.Tier.ELITE)
	var child := _enemy(ELITE, 0.3)
	assert_float(child.poise.bar_ratio()).is_equal(-1.0)


## 정예: 갑옷이 있는 동안 넉백 0, 깨지면 기절 + 그 뒤 넉백이 들어간다.
func test_elite_enemy_armor_break_stuns_and_unlocks_knockback() -> void:
	var e := _enemy(ELITE)
	e.apply_knockback(Vector2(100, 0))
	assert_vector(e.knockback).is_equal(Vector2.ZERO)
	e.health.damage(int(ceil(e.poise.armor_max)) + 1)
	assert_bool(e.is_stunned()).is_true()
	assert_bool(e.poise.is_armored()).is_false()
	e.apply_knockback(Vector2(100, 0))
	assert_float(e.knockback.x).is_greater(0.0)


func test_boss_enemy_ignores_knockback_and_staggers() -> void:
	var e := _enemy(BOSS)
	e.apply_knockback(Vector2(500, 0))
	assert_vector(e.knockback).is_equal(Vector2.ZERO)
	e.health.damage(int(ceil(e.poise.gauge_max)) + 1)
	assert_bool(e.is_stunned()).is_true()  # 보스 기절 저항과 무관하게 휘청


func test_skill_stop_duration_scales_caps_and_shrinks_for_crowds() -> void:
	var f: CombatFeelData = load("res://data/feel/combat_feel.tres")
	var small := SkillHitStop.duration(10, 1, f)
	var big := SkillHitStop.duration(40, 1, f)
	assert_float(big).is_greater(small)
	assert_float(SkillHitStop.duration(10000, 1, f)).is_equal_approx(f.skill_stop_cap, 0.0001)
	assert_float(SkillHitStop.duration(40, 5, f)).is_less(big)
	assert_float(SkillHitStop.duration(1, 50, f)).is_equal_approx(f.skill_stop_min, 0.0001)
	assert_float(SkillHitStop.duration(0, 1, f)).is_equal(0.0)


## 한 프레임의 명중은 한 번만 멈추고, 최소 간격 안의 다음 명중은 멈추지 않는다.
func test_skill_stop_one_per_frame_and_min_gap() -> void:
	var f: CombatFeelData = load("res://data/feel/combat_feel.tres")
	SkillHitStop.request(get_tree(), 40)
	SkillHitStop.request(get_tree(), 10)
	await get_tree().process_frame
	assert_bool(GameTime.is_stopped()).is_true()
	assert_float(Engine.time_scale).is_equal_approx(GameTime.base * f.skill_stop_scale, 0.0001)
	GameTime.reset()
	SkillHitStop.request(get_tree(), 40)
	await get_tree().process_frame
	assert_bool(GameTime.is_stopped()).is_false()  # 간격 안


func test_periodic_hits_do_not_stop() -> void:
	var e := _enemy(SOLDIER)
	var ctx := SkillContext.new()
	var p: Player = auto_free(Player.new())
	add_child(p)
	ctx.player = p
	assert_bool(ctx.hit(e, 1, false)).is_true()
	await get_tree().process_frame
	assert_bool(GameTime.is_stopped()).is_false()


func test_old_per_skill_hit_stops_are_gone() -> void:
	for id in ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]:
		var h: HeroData = load("res://data/heroes/%s.tres" % id)
		for k in [h.kit.tap, h.kit.dash, h.kit.charge, h.kit.counter]:
			assert_bool("hit_stop" in k).is_false()
