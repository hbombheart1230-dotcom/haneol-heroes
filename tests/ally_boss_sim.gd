class_name AllyBossSim
extends BossSim
## 주인 영웅 부르기(같이 싸우기)를 쓰는 우두머리 시뮬 (tests/test_ally_summon_sim.gd): 찰 때마다 부르고 (판 시작 때 차 있음),
## 불려 온 영웅(AllyHero)을 고른 영웅과 같은 틱으로 손으로 굴린다. 부르지 않으면 BossSim 그대로.

var rules: HomeSummonRules
var summons: int = 0
var ally: AllyHero


func _tick_extra(_res: Dictionary) -> void:
	if rules == null:
		return
	rules.tick(DT)
	if (ally == null or not is_instance_valid(ally) or not ally.active()) and rules.can_use():
		ally = AllyHero.spawn_into(suite, player, rules, true)
		if ally:
			rules.use()
			summons += 1
	if ally and is_instance_valid(ally) and ally.active():
		ally.step(DT, _t, enemies())


func free_all() -> void:
	if ally and is_instance_valid(ally):
		if is_instance_valid(ally.body):
			ally.body.free()
		ally.free()
	super.free_all()
