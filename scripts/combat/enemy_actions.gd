class_name EnemyActions
extends RefCounted
## 적 공격 결과 처리 (enemy.gd가 400줄을 넘지 않게 나눔): 화살 발사, 돌진(빗나가면 더 미끄러짐), 혀로 끌어당기기.


static func on_attack_result(e: Enemy, r: EnemyAttack.Result) -> void:
	var d := e.attack.data
	if r == EnemyAttack.Result.FIRED:
		fire_arrow(e)
	elif d.kind == EnemyAttackData.Kind.CHARGE:
		var extra := d.miss_overshoot if r != EnemyAttack.Result.HIT else 0.0
		e._charge_to(e.attack.charge_end() + e.attack.aim_dir * extra)
	elif d.kind == EnemyAttackData.Kind.PULL and r == EnemyAttack.Result.HIT and e.target is Player:
		var p := e.target as Player
		var to_me := e.global_position - p.global_position
		var dist := minf(d.pull_distance, maxf(to_me.length() - e.body_radius - p.body_radius, 0.0))
		p.apply_recoil(to_me.normalized() * dist, d.pull_time)


static func fire_arrow(e: Enemy) -> void:
	var a := EnemyArrow.new()
	a.direction = e.attack.aim_dir
	a.setup(e.target as Player, e.global_position, e.attack.data)
	e.get_parent().add_child(a)
