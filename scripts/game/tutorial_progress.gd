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
	progress += amount
	if progress < s.amount:
		return false
	index += 1
	progress = 0.0
	advanced.emit(index)
	_send_finished()
	return true


func skip() -> void:
	if is_done():
		return
	index = data.steps.size()
	progress = 0.0
	_send_finished()


func _send_finished() -> void:
	if is_done() and not _finished_sent:
		_finished_sent = true
		finished.emit()
