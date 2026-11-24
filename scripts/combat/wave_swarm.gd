class_name WaveSwarm
extends RefCounted
## 근접 잡몹 수 배율 (WaveSetData.melee_count_mult, 순수 로직): 물결 목록의 근접 잡몹 사이사이에 같은 적을 더 끼워
## 같은 체력·같은 종류로 수만 늘린다. 원거리·정예·중간 우두머리 무리·우두머리·서 있는 깃발·북잡이(둘레 힘)는 그대로
## (예고가 겹쳐 못 피하게 되지 않게). 1이면 목록을 그대로 돌려준다. 조작 안내 연습 상대는 물결이 아니라
## EnemySpawner.spawn_at으로 서므로 이 배율을 받지 않는다.


## 근접 잡몹인가: 정예·우두머리 아님, 쏘지 않음, 거리를 두지 않음, 둘레 힘 없음.
static func is_melee_trash(d: EnemyData) -> bool:
	if d == null or d.is_elite or d.is_boss or d.aura != null:
		return false
	if d.preferred_range > 0.0:
		return false
	return d.attack == null or d.attack.kind != EnemyAttackData.Kind.SHOOT


## 목록을 늘린다: 근접 잡몹 하나를 지날 때마다 (mult − 1)씩 쌓고, 1이 넘을 때마다 바로 뒤에 같은 적 하나 (순서·섞임 유지).
static func expand(enemies: Array, mult: float) -> Array:
	if mult <= 1.0:
		return enemies.duplicate()
	var out: Array = []
	var acc := 0.0
	for d in enemies:
		out.append(d)
		if not is_melee_trash(d):
			continue
		acc += mult - 1.0
		while acc >= 1.0 - 0.0001:
			out.append(d)
			acc -= 1.0
	return out
