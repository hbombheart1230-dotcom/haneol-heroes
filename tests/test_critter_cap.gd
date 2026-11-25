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
