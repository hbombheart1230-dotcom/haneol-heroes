class_name DashAutoSkill
extends RefCounted
## 내닫아 치기 (사용자 2026-11-24 "내닫고 떼기가 헷갈린다"): 내닫기 길이 적에 닿으면 둘째 기술(Slot.DASH)이 저절로 나간다.
## 빈 곳으로 내닫으면 그냥 피하기. 쿨타임이면 지금의 돌진 타격(DashDirection)만. 켬·끔과 수치는 SkillKit (dash_auto*).
## 한 번 내닫는 동안 (이어 내닫기 포함, 내닫기가 끝날 때까지) 한 번만.

var _fired: bool = false
## 이번 내닫기에서 처음 닿은 적 (시험·보고용).
var last_target: Enemy
## 지난 틱 영웅 자리 (처음엔 NAN → 내닫기 시작 자리): 한 틱 걸음이 속도 × delta보다 길어도 건너뛰지 않게.
var _prev := Vector2(NAN, NAN)


## SkillCaster.tick에서 매 틱. 반환: 이번 틱에 둘째 기술을 냈으면 true.
func tick(c: SkillCaster, delta: float) -> bool:
	var p := c.player
	if p == null or c.kit == null or not c.kit.dash_auto or p.is_dead():
		return false
	if not p.is_dashing():
		_fired = false
		_prev = p.global_position
		return false
	var prev := _prev if _prev.is_finite() else p.dash_start_position()  # 내닫기 첫 틱: 박차고 나간 자리부터
	_prev = p.global_position
	if _fired or not c.is_ready(SkillCaster.Slot.DASH):
		return false
	var hit := touched(p, c.enemy_source.call(), delta, c.kit.dash_auto_reach, c.kit.dash_auto_cone_deg, prev)
	if hit == null:
		return false
	_fired = true
	last_target = hit
	c.cast(SkillCaster.Slot.DASH, 0.0, c.kit.dash_auto_damage_mult)
	return true


## 이번 틱 내닫기 길(방금 지나온 걸음 + 다음 걸음: 지금 자리 ∓ 속도 × delta)에 닿는 첫 적. reach: 몸 둘레에 더하는 거리(px).
## 지나온 걸음도 보는 까닭: 영웅이 SkillCaster보다 먼저 움직이면 빠른 내닫기는 한 틱에 적을 건너뛴다.
## prev(지난 틱 자리)를 주면 지나온 걸음은 거기서부터 (한 틱 걸음이 속도 × delta보다 긴 경우: 내닫기 첫 박차기 등).
## cone_deg > 0이면 내닫는 쪽 그 각도(전체) 안의 적만 (적을 향해 내닫을 때만).
static func touched(p: Player, list: Array, delta: float, reach: float, cone_deg: float, prev := Vector2(NAN, NAN)) -> Enemy:
	var from := p.global_position - p.velocity * delta
	if prev.is_finite() and prev.distance_squared_to(p.global_position) > from.distance_squared_to(p.global_position):
		from = prev
	var to := p.global_position + p.velocity * delta
	var dir := p.get_dash_direction()
	var half := deg_to_rad(cone_deg * 0.5)
	for e in list:
		var en := e as Enemy
		if en == null or not is_instance_valid(en) or en.health.is_dead():
			continue
		var near := Geometry2D.get_closest_point_to_segment(en.global_position, from, to)
		if en.global_position.distance_to(near) > reach + en.body_radius * en.size_mult:
			continue
		if cone_deg > 0.0 and dir.length_squared() > 0.0001:
			var off := en.global_position - from
			if off.length_squared() > 1.0 and absf(dir.angle_to(off)) > half:
				continue
		return en
	return null
