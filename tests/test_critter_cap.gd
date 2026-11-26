extends GdUnitTestSuite
## 사임당 1번 풀벌레 (사용자 9e19cfb "나비 너무 세. 사기야" → 결정 (다) 수명을 줄임): 풀벌레 수명이 4타 마무리 쿨타임보다 짧아
## 시전끼리 겹쳐 쌓이지 않는다. 예전 수명 8초 > 쿨타임 4.5초라 겹겹이 쌓여 우두머리전 피해의 약 44%였다
## (HH_TICK_SUMMONS=1 test_boss_balance_sim, 다른 영웅 1번 8~20%). 마릿수 상한(max_alive)은 남겨 두되 끔.

const HERO := preload("res://data/heroes/shin_saimdang.tres")


func test_critters_die_before_the_next_finisher() -> void:
	var d := HERO.kit.tap as CritterSkill
	var finisher_cd := d.cooldown * HERO.kit.combo_finisher_cd_ratio
	assert_float(d.lifetime).is_less(finisher_cd)
	assert_int(d.max_alive).is_equal(0)


## 수명 상한 (사용자 결정 2026-11-26): 긴 숨·빠른 붓 패로도 수명이 다음 마무리 간격 − 0.3초를 넘지 않는다.
## 상한에 닿아 헛된 긴 숨 패는 후보에서 빠지고, 패 글은 실제 수명을 보인다.
func test_lifetime_capped_below_the_finisher_gap() -> void:
	var b := RunBuild.new()
	b.hero = HERO.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
	var kit := b.hero.kit
	var d := kit.tap as CritterSkill
	var long_up: UpgradeDef = null
	var quick_up: UpgradeDef = null
	for u in b.hero.upgrade_pool.upgrades:
		if u.id == &"critter_long":
			long_up = u
		elif u.id == &"critter_quick":
			quick_up = u
	var gap := d.cooldown * kit.combo_finisher_cd_ratio
	assert_float(d.lifetime_cap(kit)).is_equal_approx(gap - d.lifetime_margin, 0.001)
	b.apply(long_up)
	assert_float(float(d.effective(&"lifetime", d.lifetime, kit))).is_less(gap)
	assert_bool(UpgradeEffect.useful(b, long_up)).is_false()  # 이미 상한: 둘째 긴 숨은 후보에서 빠진다
	var pool := b.hero.upgrade_pool
	var stacks := {long_up.id: 1}
	var rng := RandomNumberGenerator.new()
	for i in 30:
		var picks := pool.roll(rng, stacks, 3, func(u: UpgradeDef) -> bool: return UpgradeEffect.useful(b, u))
		assert_bool(picks.has(long_up)).is_false()
	for i in 3:  # 빠른 붓으로 간격이 줄면 상한도 같이 준다
		b.apply(quick_up)
		var cap := d.lifetime_cap(kit)
		assert_float(cap).is_less(d.cooldown * kit.combo_finisher_cd_ratio)
		assert_float(float(d.effective(&"lifetime", d.lifetime, kit))).is_less_equal(cap)


func _alive() -> int:
	return get_tree().get_nodes_in_group(CritterSkill.GROUP).filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).size()


## 상한 스위치는 그대로 쓸 수 있다 (켜면 오래된 것부터 사라짐).
func test_max_alive_switch_still_works() -> void:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	p.hero = HERO
	add_child(p)
	var caster: SkillCaster = auto_free(SkillCaster.new())
	caster.player = p
	caster.world = self
	caster.enemy_source = func() -> Array: return []
	add_child(caster)
	var d := (HERO.kit.tap as CritterSkill).duplicate() as CritterSkill
	d.count = 4
	d.extra_butterflies = 3
	d.max_alive = 2
	caster.kit = HERO.kit.duplicate() as SkillKit
	caster.kit.tap = d
	for i in 4:
		caster.cast(SkillCaster.Slot.TAP)
		await get_tree().process_frame
		assert_int(_alive()).is_less_equal(2)
	for n in get_tree().get_nodes_in_group(CritterSkill.GROUP):
		n.queue_free()
