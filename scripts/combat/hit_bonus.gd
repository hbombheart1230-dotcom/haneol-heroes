class_name HitBonus
extends RefCounted
## 반격·뒤치기 판정 (순수 로직). 적이 받는 피해 배율과 맞았을 때 띄울 글자를 정한다.

const NONE := 0
const COUNTER := 1
const BACK := 2


## windup: 적이 공격 예고 중. body_facing: 적이 보는 방향. to_attacker: 적 → 때린 쪽.
static func flags(windup: bool, body_facing: Vector2, to_attacker: Vector2, back_arc_deg: float) -> int:
	var f := NONE
	if windup:
		f |= COUNTER
	if back_arc_deg > 0.0 and body_facing.length_squared() > 0.0001 and to_attacker.length_squared() > 0.0001:
		# 때린 쪽이 보는 방향의 반대쪽 back_arc_deg 안
		if body_facing.normalized().dot(to_attacker.normalized()) <= -cos(deg_to_rad(back_arc_deg * 0.5)):
			f |= BACK
	return f


static func mult(f: int, d: ImpactFeelData) -> float:
	var m := 1.0
	if f & COUNTER:
		m *= d.counter_mult
	if f & BACK:
		m *= d.back_mult
	return minf(m, d.bonus_mult_cap) if d.bonus_mult_cap > 0.0 else m


## 띄울 글자와 색 (반격이 뒤치기보다 먼저). 없으면 빈 글자.
static func label(f: int, d: ImpactFeelData) -> Array:
	if f & COUNTER:
		return [d.counter_label, d.counter_color]
	if f & BACK:
		return [d.back_label, d.back_color]
	return ["", Color.WHITE]
