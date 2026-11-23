class_name BladeBite
extends RefCounted
## 무기가 몹에 박히는 순간의 영웅 쪽 상태 (Player.bite, 그림과 무관: 2D 스프라이트와 3D 모델이 같이 읽는다).
## start → 멈춤(anim_speed 0, 떨림) → 풀림(anim_speed = release_speed, 풀리는 순간 쉭) → 평소.
## 멈춤 규칙은 하나: 휘두름 한 번에 한 번 (start가 이미 멈춘 중이면 더 긴 쪽만 남긴다), 게임 시간 멈춤(GameTime) 중엔 걸지 않는다.

## 마지막 멈춤이 끝나는 실제 시각(ms): 처치 멈춤(Feedback) 등 다른 멈춤이 겹쳐 쌓이지 않게 본다.
static var _biting_until_ms: int = 0

var data: BladeBiteData
var _stop_left: float = 0.0
var _release_left: float = 0.0
var _frame: int = 0
## 멈춤 중 들어온 대시 (풀릴 때 바로, BladeBiteData.buffer_dash).
var _dash_dir := Vector2.ZERO
var _dash_pending := false
## 풀리는 순간 한 번 (소리·버퍼 대시). Player가 연결한다.
signal released


func start(d: BladeBiteData, stop: float) -> bool:
	if d == null or not d.enabled or stop <= 0.0 or GameTime.is_stopped():
		return false
	data = d
	_stop_left = maxf(_stop_left, stop)
	_release_left = d.release_time(stop)
	_biting_until_ms = Time.get_ticks_msec() + int(_stop_left * 1000.0 / maxf(Engine.time_scale, 0.05))
	return true


func tick(delta: float) -> void:
	_frame += 1
	if _stop_left > 0.0:
		_stop_left = maxf(_stop_left - delta, 0.0)
		if _stop_left <= 0.0:
			released.emit()
		return
	_release_left = maxf(_release_left - delta, 0.0)


func cancel() -> void:
	_stop_left = 0.0
	_release_left = 0.0
	_dash_pending = false


## 멈춘 중 대시 요청: 기억하면 true (풀릴 때 on_release가 낸다). can = 대시 충전이 있는지.
func hold_dash(dir: Vector2, can: bool) -> bool:
	if _stop_left <= 0.0 or data == null or not data.buffer_dash or not can:
		return false
	_dash_dir = dir
	_dash_pending = true
	return true


func dash_pending() -> bool:
	return _dash_pending


## 풀린 순간 (Player가 released에 연결): 가르는 쉭, 기억해 둔 대시.
static func on_release(p: Player) -> void:
	var b := p.bite
	if b.data and b.data.release_sfx != &"" and Feedback.instance:
		Feedback.instance.play(b.data.release_sfx, 0.03, b.data.release_pitch)
	if b._dash_pending:
		b._dash_pending = false
		p.request_dash(b._dash_dir)


func active() -> bool:
	return _stop_left > 0.0


func left() -> float:
	return _stop_left


func releasing() -> bool:
	return _stop_left <= 0.0 and _release_left > 0.0


## 동작 재생 배율: 멈춤 0, 풀림 release_speed, 그 밖 1.
func anim_speed() -> float:
	if _stop_left > 0.0:
		return 0.0
	return data.release_speed if _release_left > 0.0 and data else 1.0


## 멈춘 동안 그림 떨림 (좌우, 프레임마다 번갈아).
func jitter() -> Vector2:
	if _stop_left <= 0.0 or data == null:
		return Vector2.ZERO
	return Vector2(data.jitter_px if _frame % 2 == 0 else -data.jitter_px, 0.0)


## 지금 어느 영웅이든 칼이 박혀 멈춘 중인지 (처치 멈춤을 겹치지 않게).
static func is_biting() -> bool:
	return Time.get_ticks_msec() < _biting_until_ms


static func reset() -> void:
	_biting_until_ms = 0
