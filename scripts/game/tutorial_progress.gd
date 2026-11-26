class_name TutorialProgress
extends RefCounted
## 조작 안내 진행 (그리기와 분리해 테스트한다): 지금 단계, 단계별로 쌓인 양, 끝났는지.

signal advanced(index: int)
signal finished

var data: TutorialData
var index: int = 0
var progress: float = 0.0
## finished를 이미 알렸는지 (advanced 처리 안에서 다시 notify해 끝나도 한 번만).
var _finished_sent := false
## 지금 단계가 시작된 뒤 흐른 시간(초)과, 해냈지만 min_show가 안 차 붙들려 있는지.
var step_time: float = 0.0
var _held := false


func _init(d: TutorialData) -> void:
	data = d


func current() -> TutorialStep:
	return data.steps[index] if data and index < data.steps.size() else null


func is_done() -> bool:
	return current() == null


## 지금 단계에서 0~1 진행률.
func ratio() -> float:
	var s := current()
	return 1.0 if s == null else clampf(progress / maxf(s.amount, 0.001), 0.0, 1.0)


## 일이 일어났다고 알린다 (걸음은 거리, 나머지는 1번, wait는 시간). 단계가 바뀌면 true.
func notify(event: StringName, amount: float = 1.0) -> bool:
	var s := current()
	if s == null or s.event != event:
		return false
	if _held:
		return false
	progress += amount
	if progress < s.amount:
		return false
	if step_time < s.min_show:  # 해냈다: 안내 글이 읽힐 때까지만 붙든다 (elapse가 넘긴다)
		_held = true
		return false
	return _advance()


## 해냈지만 읽힐 시간을 기다리는 중인지.
func held() -> bool:
	return _held


## 시간이 흐른다 (물리 틱마다). 붙들린 단계는 min_show가 차면 넘어간다.
func elapse(delta: float) -> void:
	step_time += delta
	var s := current()
	if _held and s and step_time >= s.min_show:
		_advance()


## 이 단계를 읽힐 시간도 기다리지 않고 바로 넘긴다 (이 영웅이 할 수 없는 단계).
func pass_step() -> void:
	if not is_done():
		_advance()


func _advance() -> bool:
	index += 1
	progress = 0.0
	step_time = 0.0
	_held = false
	advanced.emit(index)
	_send_finished()
	return true


func skip() -> void:
	if is_done():
		return
	index = data.steps.size()
	progress = 0.0
	_held = false
	_send_finished()


func _send_finished() -> void:
	if is_done() and not _finished_sent:
		_finished_sent = true
		finished.emit()
