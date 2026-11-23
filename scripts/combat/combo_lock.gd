class_name ComboLock
extends RefCounted
## 연타 대상 고정 (ComboLockData, AutoAttack.lock): 1타가 맞힌 몹 (여럿이면 휘두른 방향에 가장 가까운 하나)을 잡고,
## 연타가 이어지는 동안 manual_strike의 겨냥을 그 몹으로. 풀림: 새 연타(1타)·대상 죽음·사거리+여유 밖·이동 입력·대시.

var target: Enemy = null


func active() -> bool:
	return target != null and is_instance_valid(target) and not target.health.is_dead()


func release() -> void:
	target = null


## 이번 손 평타의 겨냥 대상: 연타가 이어지고 (step > 1) 대상이 살아 있고 가까우면 대상, 아니면 fallback (가장 가까운 몹).
func pick(d: ComboLockData, p: Player, step: int, reach: float, fallback: Enemy) -> Enemy:
	if d == null or not d.enabled:
		return fallback
	if step <= 1 or p.move_input.length() >= d.release_input:
		release()
		return fallback
	if not active() or target.global_position.distance_to(p.global_position) > reach + d.keep_slack + target.body_radius * target.size_mult:
		release()
		return fallback
	return target


## 칼이 닿음: 대상이 없으면 맞은 몹 중 휘두른 방향에 가장 가까운 하나를 잡고, 대상이 맞았으면 그쪽으로 살짝 끌려 붙는다.
func on_contact(d: ComboLockData, p: Player, hits: Array, swing_dir: Vector2) -> void:
	if d == null or not d.enabled or hits.is_empty():
		return
	if not active() or not hits.has(target):
		var best: Enemy = null
		var best_dot := -INF
		for e in hits:
			var en := e as Enemy
			if en == null or not is_instance_valid(en):
				continue
			var dot := swing_dir.dot((en.global_position - p.global_position).normalized())
			if dot > best_dot:
				best_dot = dot
				best = en
		target = best
	if not active() or p.is_dashing():
		return
	var off := target.global_position - p.global_position
	var gap := off.length() - target.body_radius * target.size_mult - p.body_radius
	var px := minf(gap - d.ideal_gap, d.pull_max)
	if px > 0.5:
		p.apply_recoil(off.normalized() * px, d.pull_time)
