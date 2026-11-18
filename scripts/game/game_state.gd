class_name GameState
extends RefCounted
## 한 판의 진행 상태 (순수 로직): 60초 생존, 처치 수, 게임오버/생존 성공.

signal ended(result: Result)

enum Result { PLAYING, DEFEAT, VICTORY }

var survive_time: float = 60.0
var elapsed: float = 0.0
var kills: int = 0
var result: Result = Result.PLAYING


func _init(p_survive_time: float = 60.0) -> void:
	survive_time = p_survive_time


func is_playing() -> bool:
	return result == Result.PLAYING


func time_left() -> float:
	return maxf(survive_time - elapsed, 0.0)


func tick(delta: float) -> void:
	if not is_playing():
		return
	elapsed += delta
	if elapsed >= survive_time:
		_end(Result.VICTORY)


func add_kill() -> void:
	if is_playing():
		kills += 1


func player_died() -> void:
	if is_playing():
		_end(Result.DEFEAT)


func _end(r: Result) -> void:
	result = r
	ended.emit(r)
