class_name ChargeRelease
extends RefCounted
## 충전 기술을 놓는 순간 공통 연출 (ChargeScaling 값): 모은 만큼 화면 흔들림, 다 모았으면 시전 이펙트를 높은 단계로
## 한 번 더 + 흰 고리 (범위가 뛰었다는 표시). 해일검기·낙뢰·성좌진·화폭이 같이 쓴다.


## def: 충전 기술, c: 모은 비율 0~1, at: 터지는 자리, dir: 바라보는 방향. 다 모았으면 true.
## shake·vfx_gain이 0 이상이면 ChargeScaling 값 대신 (해일검기는 자기 값을 그대로 쓴다).
static func play(ctx: SkillContext, def: SkillDef, c: float, at: Vector2, dir: Vector2,
		shake: float = -1.0, vfx_gain: int = -1) -> bool:
	var sc := def.charge_scaling if def else null
	if sc == null:
		return false
	var s := sc.release_shake if shake < 0.0 else shake
	if s > 0.0:
		Feedback.shake(s * sc.at(sc.fx, c))
	if not sc.is_full(c):
		return false
	var gain := sc.full_vfx_gain if vfx_gain < 0 else vfx_gain
	if gain > 0 and def.vfx_cast:
		Feedback.vfx_burst(def.vfx_cast, at, dir, def.vfx_level + gain)
	if sc.full_ring > 0.0 and ctx and ctx.fx:
		ctx.fx.add_ring(at, sc.full_ring, 0.35, Color(1, 1, 1))
	return true
