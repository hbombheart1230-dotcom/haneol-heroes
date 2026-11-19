class_name GameState
extends RefCounted
## 한 판의 진행 상태 (순수 로직): 시간, 처치 수, 게임오버/승리.
## survive_time > 0이면 그 시간을 버티면 승리, 0이면 보스 처치만 승리 (런 루프).

signal ended(result: Result)

enum Result { PLAYING, DEFEAT, VICTORY }

var survive_time: float = 60.0
var elapsed: float = 0.0
var kills: int = 0
var boss_killed: bool = false
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
	if survive_time > 0.0 and elapsed >= survive_time:
		_end(Result.VICTORY)


func add_kill() -> void:
	if is_playing():
		kills += 1


func boss_defeated() -> void:
	if is_playing():
		boss_killed = true
		_end(Result.VICTORY)


func player_died() -> void:
	if is_playing():
		_end(Result.DEFEAT)


func _end(r: Result) -> void:
	result = r
	ended.emit(r)
