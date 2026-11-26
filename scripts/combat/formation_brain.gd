class_name FormationBrain
extends RefCounted
## 대형 한 묶음의 머리 (FormationData, 생성기가 tick): 구성원 자리 배정·줄 유지, 사격 주기(FormationCycle),
## 겨눔은 같은 순간 모두에게 시작해 각자 예고가 같은 순간 끝나고 같은 순간 쏜다. 구성원은 스스로 겨누지 않는다 (start_check).
## 신호로 예고·소리·그림을 붙인다 (다른 파일): aimed(구성원들) · fired(구성원들) · phase_changed · member_lost · broken.

signal phase_changed(phase: int)
## 같은 순간 겨눔 시작 (구성원 각자 EnemyAttack이 WINDUP, 남은 시간이 모두 같다).
signal aimed(members: Array)
## 겨눈 구성원이 모두 쏘았다 (또는 끊겼다).
signal fired(members: Array)
signal member_lost(slot: int)
## 구성원이 모두 쓰러졌다.
signal broken

## 처음 모이기를 이만큼(초) 넘게 기다리면 모인 사람으로 시작한다 (예고 중 막힌 자리 등).
const FORM_TIMEOUT := 2.5

var data: FormationData
var spawner: EnemySpawner
## 대형 가운데 (전장 좌표)와 영웅 쪽 방향.
var anchor: Vector2
var facing: Vector2
var cycle: FormationCycle
## 자리 번호 → 적 (비면 null).
var members: Array = []
var _joined := 0
var _waited := 0.0
var _aiming: Array = []
var _offsets := PackedVector2Array()
var _done := false


func _init(d: FormationData, sp: EnemySpawner, p_anchor: Vector2, p_facing: Vector2) -> void:
	data = d
	spawner = sp
	anchor = p_anchor
	facing = p_facing
	cycle = FormationCycle.new(d)
	members.resize(d.count)
	_offsets = FormationLayout.offsets(d, d.count, facing, int(p_anchor.x * 7.0 + p_anchor.y))


## 구성원 하나가 나왔다 (생성기 warn_spawn의 configure).
func join(e: Enemy, slot: int) -> void:
	if slot < 0 or slot >= members.size():
		return
	members[slot] = e
	e.formation = self
	e.formation_slot = slot
	if e.attack:
		e.attack.start_check = func(_p: Vector2) -> bool: return false  # 혼자 겨누지 않는다 (대형이 같은 순간 시작)
	_joined += 1


## 자리의 전장 좌표 (걸을 수 있는 곳 안).
func slot_point(slot: int) -> Vector2:
	var off := _offsets[slot] if slot < _offsets.size() else Vector2.ZERO
	return spawner.bounded(anchor + off) if spawner else anchor + off


func alive() -> Array:
	return members.filter(func(e: Variant) -> bool: return e != null and is_instance_valid(e) and not (e as Enemy).health.is_dead())


func is_over() -> bool:
	return _done


func tick(delta: float) -> void:
	if _done:
		return
	_prune()
	_waited += delta
	var ready := _joined >= data.count or _waited >= FORM_TIMEOUT
	if ready and alive().is_empty():
		_done = true
		broken.emit()
		return
	var player := spawner.target if spawner else null
	var arrived := _move_anchor(delta, player)
	cycle.tick(delta, arrived, ready)
	if cycle.entered == FormationCycle.Phase.MOVE and player:
		_face(player.global_position)
	if cycle.entered == FormationCycle.Phase.AIM:
		_aim_all(player as Player)
	elif cycle.phase == FormationCycle.Phase.AIM and _aiming.all(func(e: Variant) -> bool:
			return not is_instance_valid(e) or (e as Enemy).attack.state != EnemyAttack.State.WINDUP):
		fired.emit(_aiming)
		_aiming = []
		cycle.aim_done()
	if cycle.entered != -1:
		phase_changed.emit(cycle.entered)


## 구성원 이동 속도 (EnemySteer.chase가 대형 구성원이면 이것을 쓴다): 자기 자리로, 가까우면 선다.
func steer(e: Enemy) -> Vector2:
	var to := slot_point(e.formation_slot) - e.global_position
	var d := to.length()
	if d <= data.slot_tolerance:
		return Vector2.ZERO
	return to / d * e.move_speed * e.speed_scale() * clampf(d / 80.0, 0.35, 1.0)


## HOP 구성원이 뛸 방향 (Enemy → EnemyBrain.tick_hop): 자기 자리 쪽, 길이 = 남은 거리 ÷ 한 번 뛰는 거리 (넘어 뛰지 않게).
func hop_dir(e: Enemy) -> Vector2:
	var to := slot_point(e.formation_slot) - e.global_position
	var beh := e.data.behaviour if e.data else null
	var reach := beh.hop_distance if beh else 220.0
	return to / maxf(reach, 1.0) if to.length() < reach else to.normalized()


func _prune() -> void:
	var lost := false
	for i in members.size():
		var e: Variant = members[i]
		if e != null and (not is_instance_valid(e) or (e as Enemy).health.is_dead()):
			members[i] = null
			member_lost.emit(i)
			lost = true
	if lost and data.close_ranks:  # 빈자리 좁히기: 남은 사람을 앞쪽 자리부터 다시
		var left := alive()
		members.fill(null)
		_offsets = FormationLayout.offsets(data, left.size(), facing)
		for i in left.size():
			members[i] = left[i]
			(left[i] as Enemy).formation_slot = i


## 대형 가운데 옮기기. 반환: 움직임을 끝낼 만큼 왔는지.
func _move_anchor(delta: float, player: Node2D) -> bool:
	if player == null or not cycle.is_moving() or cycle.phase == FormationCycle.Phase.FORM:
		return false
	var to := player.global_position - anchor
	var dist := to.length()
	var speed := (data.member.move_speed if data.member else 100.0) * data.speed_mult
	match data.move:
		FormationData.Move.ADVANCE, FormationData.Move.HOP:
			if dist <= data.stop_range:
				return true
			anchor = spawner.bounded(anchor + to / dist * minf(speed * delta, dist - data.stop_range))
		FormationData.Move.KITE:  # 거리 띠를 지킨다: 멀면 다가오고 (쏴도 닿게), 가까우면 물러난다
			var gap := dist - data.stop_range
			if absf(gap) <= data.kite_band:
				return true
			anchor = spawner.bounded(anchor + to / maxf(dist, 1.0) * signf(gap) * minf(speed * delta, absf(gap)))
		FormationData.Move.HOLD:
			return true
	return false


func _face(target: Vector2) -> void:
	if data.shape == FormationData.Shape.RING:
		return
	var f := target - anchor
	if f.length_squared() > 1.0:
		facing = f.normalized()
		_offsets = FormationLayout.offsets(data, members.size() if not data.close_ranks else alive().size(), facing)


## 같은 순간 모두 겨눔 시작 (경직·기절·넘어짐 중인 사람은 이번엔 빠진다).
func _aim_all(player: Player) -> void:
	_aiming = []
	if player == null or player.is_dead():
		cycle.aim_done()
		return
	for e: Enemy in alive():
		if e.attack == null or e.is_stunned() or (e.reaction and (e.reaction.is_staggered() or e.reaction.is_down())):
			continue
		if e.attack.begin_windup(e.global_position, player):
			_aiming.append(e)
	if _aiming.is_empty():
		cycle.aim_done()
		return
	EnemyActions.play_sfx((_aiming[0] as Enemy).attack.data, true)  # 예고 소리는 한 번 (여럿이 겹치지 않게)
	aimed.emit(_aiming)
