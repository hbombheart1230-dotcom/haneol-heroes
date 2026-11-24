class_name UpgradePool
extends Resource
## 영웅 하나의 성장 선택지 목록 (영웅 데이터에서 참조).

@export var upgrades: Array[UpgradeDef] = []
## 패 짝 (둘 다 가지면 맞물리는 효과, SynergyDef). 비어 있으면 없음.
@export var synergies: Array[SynergyDef] = []


## 아직 최대로 고르지 않은 것 중 가중치로 count개를 겹치지 않게 뽑는다.
func roll(rng: RandomNumberGenerator, stacks: Dictionary, count: int) -> Array[UpgradeDef]:
	var pool: Array[UpgradeDef] = []
	for u in upgrades:
		if u and u.weight > 0.0 and int(stacks.get(u.id, 0)) < u.max_stacks:
			pool.append(u)
	var picked: Array[UpgradeDef] = []
	while picked.size() < count and not pool.is_empty():
		var total := 0.0
		for u in pool:
			total += u.weight
		var r := rng.randf() * total
		var idx := pool.size() - 1
		for i in pool.size():
			r -= pool[i].weight
			if r <= 0.0:
				idx = i
				break
		picked.append(pool[idx])
		pool.remove_at(idx)
	return picked
