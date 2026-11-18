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
## 플릭 판정: 최근 flick_window 초 안의 이동 거리·속도. 손가락 상태에 따라 기준이 다르다
## (실기기 피드백: "처음 터치 후 튕기기는 잘 안 되고, 이동 중 방향 전환은 너무 쉽게 대시된다").
var flick_window: float = 0.10
## 직전 구간 속도가 이보다 느리면 "멈춰 있다가 튕김" → 쉬운 기준.
var rest_speed: float = 250.0
## 멈춰 있다가 튕길 때 (처음 터치, 잠깐 멈춤): 쉽게, 급가속 조건 없음.
var rest_min_distance: float = 70.0
var rest_min_speed: float = 700.0
## 이동 중에 튕길 때: 엄격하게 + 급가속 조건 (방향 전환은 대시가 아님). 실기기 피드백으로 110/1300/1.6 → 140/1600/1.8.
var move_min_distance: float = 140.0
var move_min_speed: float = 1600.0
## 급가속: 플릭 구간 속도가 직전 구간(실제 경로 길이 기준) 속도의 이 배수 이상.
var flick_burst_ratio: float = 1.8
## 연속 대시: 직전 플릭 후 이 시간(초) 안에 방향을 크게 꺾은(코사인 < chain_max_dot) 플릭은
## 더 쉬운 기준 (사이에 걷기가 끼지 않게, 실기기 피드백).
var chain_window: float = 0.4
var chain_max_dot: float = 0.5
var chain_min_distance: float = 40.0
var chain_min_speed: float = 500.0
## 손가락이 움직이는 동안 터치 이벤트 간격의 상한(초). 이보다 긴 공백은 "정지"로 본다.
## Android 터치 샘플링은 보통 60~240Hz(4~17ms).
var max_event_gap: float = 0.05
## 한 손가락에서 연속 플릭 사이 최소 간격(초).
var flick_cooldown: float = 0.12
## 플릭 직후 앵커를 손가락 위치로 재설정해 대시 후 이동이 튀지 않게 한다.
var reanchor_after_flick: bool = true

var _move_index: int = -1
var _anchor: Vector2 = Vector2.ZERO
var _current: Vector2 = Vector2.ZERO
var _last_flick_time: float = -INF
## 진단용: 마지막으로 의미 있는 움직임(거리 40px 이상 또는 손 뗌)의 판정 결과.
## {"dist", "speed", "need", "prev", "result"} — 실기기에서 대시가 왜 안 나갔는지 보여주기 위함.
var last_check: Dictionary = {}
var _last_flick_dir: Vector2 = Vector2.ZERO
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
	var dir := _detect_flick(time, true)
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


func _detect_flick(time: float, releasing: bool = false) -> Vector2:
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
	if dist < 1.0:
		return Vector2.ZERO
	var speed := dist / dt
	# 직전 구간 속도 (실제 이동 경로 길이 기준: 방향을 꺾어도 작아지지 않음).
	var prev := _point_at(float(base[0]) - flick_window)
	var prev_dt := float(base[0]) - float(prev[0])
	var prev_speed := _path_length(prev, base) / prev_dt if prev_dt > 0.0 else 0.0
	var chained := time - _last_flick_time <= chain_window and (delta / dist).dot(_last_flick_dir) < chain_max_dot
	var easy := prev_speed < rest_speed or chained
	var need_dist := rest_min_distance if easy else move_min_distance
	var need_speed := rest_min_speed if easy else move_min_speed
	if chained:
		need_dist = chain_min_distance
		need_speed = chain_min_speed
	var check := {"dist": dist, "speed": speed, "need": need_speed, "prev": prev_speed, "result": ""}
	var reason := ""
	if dist < need_dist:
		reason = "거리 부족"
	elif speed < need_speed:
		reason = "속도 부족"
	elif not easy and flick_burst_ratio > 0.0 and speed < prev_speed * flick_burst_ratio:
		reason = "급가속 부족"
	if reason != "":
		if dist >= need_dist * 0.5 or (releasing and dist >= 20.0):
			check["result"] = reason + ("" if easy else " (이동 중)")
			last_check = check
		return Vector2.ZERO
	_last_flick_time = time
	var dir := delta / dist
	_last_flick_dir = dir
	check["result"] = "플릭"
	last_check = check
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


## 두 추정점 [시간, 위치] 사이 손가락이 실제로 지나간 경로 길이.
func _path_length(from: Array, to: Array) -> float:
	var t0 := float(from[0])
	var t1 := float(to[0])
	var last: Vector2 = from[1]
	var total := 0.0
	for smp in _samples:
		var t := float(smp[0])
		if t > t0 and t < t1:
			total += last.distance_to(smp[1] as Vector2)
			last = smp[1]
	return total + last.distance_to(to[1] as Vector2)
