class_name BossPatternPicker
extends RefCounted
## 보스 다음 공격 고르기 (순수 로직, BossFeelData.pick_by_range).
## 바로 전에 쓴 종류는 빼고 (같은 공격 연속 금지), 지금 거리에서 닿는 공격 가운데 하나를 고른다.
## 닿는 것이 없으면 가장 멀리 닿는 것 (돌진처럼 거리를 좁히는 공격). min_range가 있는 공격은 영웅이 그보다 멀 때만.


## list: EnemyAttackData 배열, last_kind: 바로 전 공격 종류 (-1 = 없음), dist: 영웅까지 거리, roll: 0~1 난수.
static func pick(list: Array, last_kind: int, dist: float, roll: float) -> EnemyAttackData:
	if list.is_empty():
		return null
	var usable: Array = list.filter(func(a: EnemyAttackData) -> bool: return dist >= a.min_range)  # 멀 때만 쓰는 공격
	if usable.is_empty():
		usable = list
	var pool: Array = usable.filter(func(a: EnemyAttackData) -> bool: return int(a.kind) != last_kind)
	if pool.is_empty():
		pool = usable
	var near: Array = pool.filter(func(a: EnemyAttackData) -> bool: return dist <= a.trigger_range)
	if near.is_empty():
		var far: EnemyAttackData = pool[0]
		for a in pool:
			if (a as EnemyAttackData).trigger_range > far.trigger_range:
				far = a
		return far
	return near[mini(int(roll * near.size()), near.size() - 1)]
