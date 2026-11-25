extends GdUnitTestSuite
## 사임당 1번 풀벌레 (사용자 9e19cfb "나비 너무 세. 사기야"): 한꺼번에 max_alive마리까지만 남는다 — 새로 부르면 오래된 것부터 사라진다.
## 예전엔 수명(8초)보다 자주(마무리 4.5초) 불러 겹겹이 쌓였고, 성장하면 한 번에 7마리(수 +2, 큰 변형 +3)라 우두머리전 피해의 약 44%였다
## (HH_TICK_SUMMONS=1 test_boss_balance_sim, 다른 영웅 1번 8~20%).

const HERO := preload("res://data/heroes/shin_saimdang.tres")


func _alive() -> int:
	return get_tree().get_nodes_in_group(CritterSkill.GROUP).filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).size()


func test_casting_again_keeps_at_most_max_alive() -> void:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	p.hero = HERO
	add_child(p)
	var caster: SkillCaster = auto_free(SkillCaster.new())
	caster.player = p
	caster.kit = HERO.kit
	caster.world = self
	caster.enemy_source = func() -> Array: return []
	add_child(caster)
	var d := (HERO.kit.tap as CritterSkill).duplicate() as CritterSkill
	d.count = 4
	d.extra_butterflies = 3
	assert_int(d.max_alive).is_equal(2)
	caster.kit = caster.kit.duplicate() as SkillKit
	caster.kit.tap = d
	for i in 4:
		caster.cast(SkillCaster.Slot.TAP)
		await get_tree().process_frame
		assert_int(_alive()).is_less_equal(2)
	for n in get_tree().get_nodes_in_group(CritterSkill.GROUP):
		n.queue_free()
