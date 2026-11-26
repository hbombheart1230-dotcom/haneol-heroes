class_name FormationCycle
extends RefCounted
## 대형 사격 주기 (순수 로직, FormationData): FORM(모이기) → MOVE → HALT → AIM → RELOAD → MOVE …
## AIM은 바깥(FormationBrain)이 구성원 모두의 겨눔을 같은 순간 시작한 뒤, 모두 쏘고 나면 aim_done()으로 끝낸다.

enum Phase { FORM, MOVE, HALT, AIM, RELOAD }

var data: FormationData
var phase: Phase = Phase.FORM
var left: float = 0.0
## 이번 틱에 새로 들어간 단계 (없으면 -1): 바깥이 단계 시작 일을 한 번만 하도록.
var entered: int = -1


func _init(d: FormationData) -> void:
	data = d
	left = d.form_time if d else 0.0


## arrived = 움직임을 일찍 끝낼 조건 (ADVANCE가 stop_range에 닿음 등). ready = 구성원이 다 모였는지 (FORM).
func tick(delta: float, arrived: bool = false, ready: bool = true) -> void:
	entered = -1
	if phase == Phase.AIM:
		return
	left -= delta
	match phase:
		Phase.FORM:
			if ready and left <= 0.0:
				_go(Phase.MOVE, data.move_time)
		Phase.MOVE:
			if arrived or left <= 0.0:
				_go(Phase.HALT, data.halt_time)
		Phase.HALT:
			if left <= 0.0:
				_go(Phase.AIM, 0.0)
		Phase.RELOAD:
			if left <= 0.0:
				_go(Phase.MOVE, data.move_time)


## 모두 쐈다 (또는 겨눌 사람이 없다): 장전으로.
func aim_done() -> void:
	if phase == Phase.AIM:
		_go(Phase.RELOAD, data.reload_time)


func is_moving() -> bool:
	return phase == Phase.MOVE or phase == Phase.FORM


func _go(p: Phase, t: float) -> void:
	phase = p
	left = t
	entered = p
