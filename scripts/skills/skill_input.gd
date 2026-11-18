class_name SkillInput
extends RefCounted
## 단일 스킬 버튼의 누름 상태 (순수 로직, 터치 ID 기준).
## 짧게 눌렀다 떼기 = 탭, hold_threshold 이상 누르기 = 충전, 떼면 충전 발동.

enum State { IDLE, PRESSED, CHARGING, CONSUMED }

## 이 시간(초) 이상 누르면 충전으로 본다. 실험 값.
var hold_threshold: float = 0.2
## 충전 시작 후 최대 충전까지 시간(초). 실험 값.
var full_charge_time: float = 1.0

var state: State = State.IDLE
var index: int = -1
var _press_time: float = 0.0


func is_down() -> bool:
	return state != State.IDLE


func press(p_index: int, time: float) -> bool:
	if state != State.IDLE:
		return false
	index = p_index
	state = State.PRESSED
	_press_time = time
	return true


## 누름을 다른 기술(예: 파도격)이 즉시 사용했을 때. 손을 뗄 때 아무 것도 발동하지 않는다.
func consume() -> void:
	if state != State.IDLE:
		state = State.CONSUMED


## 반환: 이번 호출에서 충전 상태로 들어갔으면 true.
func update(time: float) -> bool:
	if state == State.PRESSED and time - _press_time >= hold_threshold:
		state = State.CHARGING
		return true
	return false


## 0~1 충전량 (충전 중이 아니면 0).
func charge_ratio(time: float) -> float:
	if state != State.CHARGING:
		return 0.0
	return clampf((time - _press_time - hold_threshold) / maxf(full_charge_time, 0.001), 0.0, 1.0)


## 반환: {"kind": "tap" | "charge" | "none", "charge": float}
func release(p_index: int, time: float) -> Dictionary:
	if p_index != index or state == State.IDLE:
		return {"kind": "none", "charge": 0.0}
	update(time)
	var out := {"kind": "none", "charge": 0.0}
	match state:
		State.PRESSED:
			out = {"kind": "tap", "charge": 0.0}
		State.CHARGING:
			out = {"kind": "charge", "charge": charge_ratio(time)}
	reset()
	return out


func reset() -> void:
	state = State.IDLE
	index = -1
