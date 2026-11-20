class_name EnemyBrain
extends RefCounted
## 적 한 마리의 움직임 판단 (공격권·둘레 돌기·물러나며 쏘기·뛰기·매복·휩쓸기·정면 막기).
## 노드에 의존하지 않는 순수 로직이라 테스트에서 직접 부른다. Enemy가 매 프레임 묻는다.

var ai: EnemyAIData
var beh: EnemyBehaviourData
var id: int = 0
## 근접형(공격권 대상)인지: 거리 유지형(궁수)·보스·정예는 아님.
var melee: bool = true
## 휩쓸기(무리 이벤트): 이 방향으로 sweep_left초 동안 곧장 간다.
var sweep_dir: Vector2 = Vector2.ZERO
var sweep_left: float = 0.0
var _hop_cd: float = 0.0
var _hop_left: float = 0.0
var _hop_vel: Vector2 = Vector2.ZERO
var revealed: bool = true
var _strafe_side: float = 1.0


func _init(p_ai: EnemyAIData, p_beh: EnemyBehaviourData, p_id: int, p_melee: bool) -> void:
	ai = p_ai if p_ai else EnemyAIData.new()
	beh = p_beh
	id = p_id
	melee = p_melee and (beh == null or beh.uses_token)
	_strafe_side = 1.0 if p_id % 2 == 0 else -1.0
	if beh and beh.style == EnemyBehaviourData.Style.HOP:
		_hop_cd = beh.hop_interval * (0.3 + float(p_id % 7) / 10.0)
	if beh and beh.style == EnemyBehaviourData.Style.AMBUSH:
		revealed = false


func style() -> EnemyBehaviourData.Style:
	return beh.style if beh else EnemyBehaviourData.Style.CHASE


## 쫓을 방향을 공격권·둘레 돌기·매복에 맞게 고친다. dir = 플레이어 쪽 단위 벡터, dist = 거리.
## 반환: [방향(길이 ≤ 1), 속도 배율]
func steer(dir: Vector2, dist: float) -> Array:
	if sweep_left > 0.0:
		return [sweep_dir, ai.wall_speed_mult]
	if style() == EnemyBehaviourData.Style.AMBUSH and not revealed:
		if dist <= beh.ambush_range:
			revealed = true
		else:
			return [dir, beh.ambush_speed_mult]
	if not melee:
		return [dir, 1.0]
	if dist <= ai.engage_radius and AttackTokens.request(id, ai.max_melee_tokens):
		return [dir, 1.0]
	if dist > ai.release_radius:
		AttackTokens.release(id)
	if AttackTokens.has(id) or dist > ai.engage_radius:  # 멀면 그냥 다가온다
		return [dir, 1.0]
	# 공격권 없음: hold_radius 고리로 가서 옆걸음으로 돈다.
	var radial := dir * clampf((dist - ai.hold_radius) / 60.0, -1.0, 1.0)
	var side := dir.orthogonal() * _strafe_side * ai.strafe_ratio
	return [(radial + side).limit_length(1.0), 1.0]


## 공격 중에도 움직이는 경우의 방향 (물러나며 쏘기). 없으면 Vector2.ZERO.
func busy_dir(attack: EnemyAttack, dir: Vector2) -> Vector2:
	if attack and attack.state == EnemyAttack.State.WINDUP and attack.data.kite_while_aiming > 0.0:
		return -dir * attack.data.kite_while_aiming
	return Vector2.ZERO


## 뛰기 진행. 뛰는 중이면 그 속도, 아니면 Vector2.ZERO. dir = 플레이어 쪽.
func tick_hop(delta: float, dir: Vector2, busy: bool) -> Vector2:
	if style() != EnemyBehaviourData.Style.HOP:
		return Vector2.ZERO
	if _hop_left > 0.0:
		_hop_left = maxf(_hop_left - delta, 0.0)
		return _hop_vel
	_hop_cd -= delta
	if _hop_cd <= 0.0 and not busy:
		_hop_cd = beh.hop_interval
		_hop_left = beh.hop_time
		var swerve := deg_to_rad(randf_range(-beh.hop_swerve_deg, beh.hop_swerve_deg))
		_hop_vel = dir.rotated(swerve) * beh.hop_distance / maxf(beh.hop_time, 0.01)
		return _hop_vel
	return Vector2.ZERO


func is_hopping() -> bool:
	return _hop_left > 0.0


## 뛰는 중 몸이 떠오른 높이(px).
func hop_lift() -> float:
	if _hop_left <= 0.0 or beh == null:
		return 0.0
	var k := 1.0 - _hop_left / maxf(beh.hop_time, 0.01)
	return 4.0 * beh.hop_height * k * (1.0 - k)


## 매복 중 투명도 (드러나면 1).
func alpha() -> float:
	return beh.ambush_alpha if style() == EnemyBehaviourData.Style.AMBUSH and not revealed else 1.0


func tick_sweep(delta: float) -> void:
	sweep_left = maxf(sweep_left - delta, 0.0)


## 받는 피해 배율: 경직 중 처벌 × 정면 방패 × 변종.
func damage_mult(attack: EnemyAttack, facing: Vector2, to_player: Vector2, affix_mult: float) -> float:
	var m := affix_mult
	if attack and attack.state == EnemyAttack.State.RECOVER:
		m *= ai.punish_mult
	if beh and beh.front_guard_deg > 0.0 and to_player.length_squared() > 0.01 and facing.length_squared() > 0.01:
		if facing.normalized().dot(to_player.normalized()) >= cos(deg_to_rad(beh.front_guard_deg * 0.5)):
			m *= beh.front_guard_mult
	return m


## 일제 사격 박자인지 (모든 철포병이 같은 시계를 본다).
static func volley_open(ai_data: EnemyAIData, now_sec: float) -> bool:
	if ai_data == null or ai_data.volley_interval <= 0.0:
		return true
	return fmod(now_sec, ai_data.volley_interval) < ai_data.volley_window


func forget() -> void:
	AttackTokens.release(id)
