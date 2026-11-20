class_name HurtResponse
extends RefCounted
## 영웅이 맞았을 때의 규칙 (순수 계산 + 주변 적 밀어내기). 수치는 HitReactionData("숨 돌릴 틈").


## 피격 무적 시간: 작은 피해는 짧게, 최대체력의 invuln_full_hp_frac 이상이면 base 전체 (Brotato식).
static func invuln_for(amount: int, max_hp: int, base: float, d: HitReactionData) -> float:
	var frac := float(maxi(amount, 0)) / float(maxi(max_hp, 1))
	var k := clampf(frac / maxf(d.invuln_full_hp_frac, 0.0001), 0.0, 1.0)
	return base * lerpf(d.invuln_min_ratio, 1.0, k)


## 이 거리(중심 사이)의 적이 받는 바깥쪽 충격 크기. 가까울수록 세고 반경 끝에서 절반, 밖이면 0.
static func breathe_impulse(dist: float, d: HitReactionData) -> float:
	if dist > d.breathe_radius or d.breathe_radius <= 0.0:
		return 0.0
	return d.breathe_impulse * (1.0 - 0.5 * dist / d.breathe_radius)


## 숨 돌릴 틈: 영웅 둘레 적을 바깥으로 민다 (잡몹은 잠깐 경직). 민 적 수.
static func breathe(center: Vector2, enemies: Array, d: HitReactionData) -> int:
	var n := 0
	for e in enemies:
		var en := e as Enemy
		if en == null or not is_instance_valid(en) or en.health == null or en.health.is_dead():
			continue
		var off := en.global_position - center
		var dist := off.length()
		var imp := breathe_impulse(maxf(dist - en.body_radius * en.size_mult, 0.0), d)
		if imp <= 0.0:
			continue
		var dir := off / dist if dist > 0.01 else Vector2.RIGHT.rotated(en.get_instance_id() % 628 * 0.01)
		en.shove(dir * imp)
		n += 1
	return n
