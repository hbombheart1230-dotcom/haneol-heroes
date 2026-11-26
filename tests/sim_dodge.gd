class_name SimDodge
extends RefCounted
## 시뮬 봇이 예고를 보고 피하는 대시 (BossSim에서 나눔, 파일 400줄): 맞을 예고면 옆이나 바깥으로.


static func dodge(sim: BossSim, list: Array) -> bool:
	if sim.player.is_dashing():
		return false
	var p := sim.player.global_position
	for e in list:
		var a: EnemyAttack = e.attack
		if a == null or a.state != EnemyAttack.State.WINDUP:
			sim._missed.erase(a)
			continue
		if not sim._missed.has(a):
			sim._missed[a] = randf() < sim.miss_rate
		if sim._missed[a] or a.windup_left() > BossSim.REACT:
			continue
		if a.is_shoot():
			var off := p - a.aim_origin
			if absf(off.dot(a.aim_dir.orthogonal())) < 50.0 and off.dot(a.aim_dir) > 0.0:
				sim.player.request_dash(side(a.aim_dir, off))
				return true
		elif a.contains(p):
			sim.player.request_dash(escape_dir(a, p))
			return true
	return false


## 예고 영역 밖으로 나가는 대시 방향.
static func escape_dir(a: EnemyAttack, p: Vector2) -> Vector2:
	match a.data.kind:
		EnemyAttackData.Kind.CHARGE, EnemyAttackData.Kind.THRUST, EnemyAttackData.Kind.PULL:
			return side(a.aim_dir, p - a.aim_origin)
		EnemyAttackData.Kind.SLAM:
			var o := p - a.target_point
			return o.normalized() if o.length_squared() > 1.0 else Vector2.RIGHT
	var off := p - a.aim_origin
	return off.normalized() if off.length_squared() > 1.0 else a.aim_dir.orthogonal()


static func side(dir: Vector2, off: Vector2) -> Vector2:
	var n := dir.orthogonal()
	return n if off.dot(n) >= 0.0 else -n
