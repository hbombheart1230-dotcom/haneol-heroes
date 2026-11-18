class_name SkillInput
extends RefCounted
## 스킬 입력의 누름 상태 (순수 로직, 터치 ID 기준).
## 짧게 눌렀다 떼기 = 탭, hold_threshold 이상 누르기 = 충전, 떼면 충전 발동.
## 입력원은 스킬 버튼(BUTTON) 또는 이동 손가락의 제스처(GESTURE).

enum State { IDLE, PRESSED, CHARGING, CONSUMED }
enum Source { BUTTON, GESTURE }

## 이 시간(초) 이상 누르면 충전으로 본다 (press에서 입력원별로 바꿀 수 있음).
var hold_threshold: float = 0.2
## 충전 시작 후 최대 충전까지 시간(초).
var full_charge_time: float = 1.0

var state: State = State.IDLE
var source: Source = Source.BUTTON
var index: int = -1
var _press_time: float = 0.0
var _threshold: float = 0.2


func is_down() -> bool:
	return state != State.IDLE


func is_from(p_source: Source) -> bool:
	return is_down() and source == p_source


## threshold < 0이면 hold_threshold를 쓴다.
func press(p_index: int, time: float, p_source: Source = Source.BUTTON, threshold: float = -1.0) -> bool:
	if state != State.IDLE:
		return false
	index = p_index
	source = p_source
	state = State.PRESSED
	_press_time = time
	_threshold = hold_threshold if threshold < 0.0 else threshold
	return true


## 누름을 다른 기술(예: 파도격)이 즉시 사용했을 때. 손을 뗄 때 아무 것도 발동하지 않는다.
func consume() -> void:
	if state != State.IDLE:
		state = State.CONSUMED


## 반환: 이번 호출에서 충전 상태로 들어갔으면 true.
func update(time: float) -> bool:
	if state == State.PRESSED and time - _press_time >= _threshold:
		state = State.CHARGING
		return true
	return false


## 0~1 충전량 (충전 중이 아니면 0).
func charge_ratio(time: float) -> float:
	if state != State.CHARGING:
		return 0.0
	return clampf((time - _press_time - _threshold) / maxf(full_charge_time, 0.001), 0.0, 1.0)


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
