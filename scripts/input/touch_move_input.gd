class_name TouchMoveInput
extends RefCounted
## 자유 영역 터치·드래그 이동 + 플릭 대시 판정 (순수 로직, 노드 의존 없음).
##
## - 화면 어디든 처음 닿은 손가락 하나가 "이동 손가락"이 된다. 다른 터치 ID는 이동에 영향을 주지 않는다.
## - 이동 방향 = 터치 시작점(앵커) 기준 상대 벡터. 고정 조이스틱 UI 없음.
## - 플릭 = 짧은 시간 창 안의 빠른 이동. 드래그 도중 또는 손을 뗄 때 판정한다.
## - 좌표 단위는 뷰포트 픽셀(720x1280 기준), 시간 단위는 초.

signal flicked(direction: Vector2)

## 이 거리(px) 미만 드래그는 이동 0.
var dead_zone: float = 12.0
## 이 거리(px)에서 이동 강도 1.0.
var full_speed_radius: float = 90.0
## 앵커가 손가락에서 이 거리 이상 멀어지면 손가락 쪽으로 끌려온다 (방향 전환을 빠르게).
var anchor_follow_radius: float = 140.0
## 플릭 판정: 최근 flick_window 초 안에 flick_min_distance(px) 이상, flick_min_speed(px/s) 이상 이동.
## 실기기 피드백(이동 중 오발동 대시)으로 80px/800 → 120px/1400 상향.
var flick_min_speed: float = 1400.0
var flick_min_distance: float = 120.0
var flick_window: float = 0.10
## 급가속 조건: 플릭 구간 속도가 바로 앞 구간(같은 길이) 속도의 이 배수 이상이어야 한다.
## 꾸준히 빠른 드래그나 빠른 방향 전환은 대시가 아니다. 0 이하면 끔.
var flick_burst_ratio: float = 1.8
## 손가락이 움직이는 동안 터치 이벤트 간격의 상한(초). 이보다 긴 공백은 "정지"로 본다.
## Android 터치 샘플링은 보통 60~240Hz(4~17ms).
var max_event_gap: float = 0.05
## 한 손가락에서 연속 플릭 사이 최소 간격(초).
var flick_cooldown: float = 0.20
## 플릭 직후 앵커를 손가락 위치로 재설정해 대시 후 이동이 튀지 않게 한다.
var reanchor_after_flick: bool = true

var _move_index: int = -1
var _anchor: Vector2 = Vector2.ZERO
var _current: Vector2 = Vector2.ZERO
var _last_flick_time: float = -INF
## 최근 샘플 [time, position] 목록 (flick_window 동안만 유지).
var _samples: Array = []


func is_active() -> bool:
	return _move_index != -1


func get_move_index() -> int:
	return _move_index


func get_anchor() -> Vector2:
	return _anchor


func get_current() -> Vector2:
	return _current


## 길이 0~1의 이동 벡터.
func get_move_vector() -> Vector2:
	if _move_index == -1:
		return Vector2.ZERO
	var offset := _current - _anchor
	var dist := offset.length()
	if dist < dead_zone:
		return Vector2.ZERO
	var strength := clampf((dist - dead_zone) / maxf(full_speed_radius - dead_zone, 0.001), 0.0, 1.0)
	return offset / dist * strength


## 반환: 이 터치가 이동 손가락으로 채택됐으면 true.
func touch_down(index: int, pos: Vector2, time: float) -> bool:
	if _move_index != -1:
		return false
	_move_index = index
	_anchor = pos
	_current = pos
	_samples.clear()
	_push_sample(time, pos)
	return true


## 반환: 플릭이 발생하면 방향(단위벡터), 아니면 Vector2.ZERO.
func touch_move(index: int, pos: Vector2, time: float) -> Vector2:
	if index != _move_index:
		return Vector2.ZERO
	_current = pos
	_push_sample(time, pos)
	var offset := _current - _anchor
	if offset.length() > anchor_follow_radius:
		_anchor = _current - offset.normalized() * anchor_follow_radius
	var dir := _detect_flick(time)
	if dir != Vector2.ZERO and reanchor_after_flick:
		_anchor = _current
		_samples.clear()
		_push_sample(time, pos)
	return dir


## 반환: 손을 떼는 순간의 플릭 방향 또는 Vector2.ZERO. 이동은 멈춘다.
func touch_up(index: int, pos: Vector2, time: float) -> Vector2:
	if index != _move_index:
		return Vector2.ZERO
	_current = pos
	_push_sample(time, pos)
	var dir := _detect_flick(time)
	reset()
	return dir


## 앱 포커스 상실 등으로 터치가 취소될 때.
func reset() -> void:
	_move_index = -1
	_samples.clear()
	_anchor = Vector2.ZERO
	_current = Vector2.ZERO


## 판정 구간 2개(현재 + 직전) 분량의 샘플과, 그 이전 기준점 1개를 남긴다.
## 터치 이벤트는 손가락이 움직일 때만 오므로, 정지 후 첫 이동 이벤트도 기준점과 비교할 수 있어야 한다.
func _push_sample(time: float, pos: Vector2) -> void:
	_samples.append([time, pos])
	while _samples.size() >= 2 and float(_samples[1][0]) <= time - flick_window * 2.0:
		_samples.pop_front()


func _detect_flick(time: float) -> Vector2:
	if time - _last_flick_time < flick_cooldown:
		return Vector2.ZERO
	if _samples.size() < 2:
		return Vector2.ZERO
	var base := _point_at(time - flick_window)
	var dt := time - float(base[0])
	if dt <= 0.0:
		return Vector2.ZERO
	var delta: Vector2 = _current - (base[1] as Vector2)
	var dist := delta.length()
	var speed := dist / dt
	if dist < flick_min_distance or speed < flick_min_speed:
		return Vector2.ZERO
	# 급가속 조건: 직전 구간보다 충분히 빨라졌을 때만 플릭.
	if flick_burst_ratio > 0.0:
		var prev := _point_at(float(base[0]) - flick_window)
		var prev_dt := float(base[0]) - float(prev[0])
		if prev_dt > 0.0:
			var prev_speed := ((base[1] as Vector2) - (prev[1] as Vector2)).length() / prev_dt
			if speed < prev_speed * flick_burst_ratio:
				return Vector2.ZERO
	_last_flick_time = time
	var dir := delta / dist
	flicked.emit(dir)
	return dir


## 시각 t의 손가락 [시간, 위치]를 샘플에서 추정한다. (시간은 추정에 쓴 유효 시각)
## - t가 첫 샘플보다 이르면 첫 샘플 그대로.
## - t 전후 샘플 간격이 max_event_gap 이하이면 손가락이 계속 움직이던 중이므로 선형 보간
##   (연속 이동의 속도를 부풀리지 않음).
## - 간격이 그보다 크면 그 사이에 이벤트가 없었다 = 손가락이 정지해 있었다.
##   다음 샘플 직전 max_event_gap 동안만 움직였다고 본다 (정지 후 첫 플릭을 놓치지 않음).
func _point_at(t: float) -> Array:
	var first: Array = _samples[0]
	if t <= float(first[0]):
		return first
	for i in range(_samples.size() - 2, -1, -1):
		var s0: Array = _samples[i]
		var t0 := float(s0[0])
		if t0 > t:
			continue
		var s1: Array = _samples[i + 1]
		var t1 := float(s1[0])
		if t1 - t0 <= max_event_gap:
			var w := clampf((t - t0) / maxf(t1 - t0, 0.000001), 0.0, 1.0)
			return [t, (s0[1] as Vector2).lerp(s1[1] as Vector2, w)]
		return [maxf(t, t1 - max_event_gap), s0[1]]
	return _samples[_samples.size() - 1]
