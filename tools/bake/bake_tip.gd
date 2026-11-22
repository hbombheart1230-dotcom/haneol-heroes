class_name BakeTip
extends RefCounted
## 굽기 때 무기 끝 찾기 (타격감 2차 T2). 오른손 뼈를 화면 좌표로 옮긴 뒤, 바라보는 쪽으로 걸어가며
## 마지막 불투명 픽셀을 무기 끝으로 본다 (총구·창끝·칼끝). 좌표는 칸 가운데 기준 픽셀.
## 굽기 구간(start~end)과 맞닿는 프레임(strike)도 여기서 계산한다 (순수 함수 → 테스트).

const HAND_BONES := ["RightHand", "hand_r", "mixamorig:RightHand"]
## 손에서 이만큼(px)까지 찾는다. 이 너비만큼 투명이 이어지면 무기가 끝났다고 본다.
const MAX_REACH := 150
const GAP := 4


## 굽기 구간 [start, end] (초). 없거나 이상하면 동작 전체.
static func window(anim: Dictionary, length: float) -> Vector2:
	var s := clampf(float(anim.get("start", 0.0)), 0.0, length)
	var e := clampf(float(anim.get("end", length)), 0.0, length)
	if e <= s:
		return Vector2(0.0, length)
	return Vector2(s, e)


## f번째 프레임의 시각 (반복 동작은 끝 프레임이 처음과 겹치지 않게).
static func frame_time(win: Vector2, f: int, frames: int, loop: bool) -> float:
	var div := float(frames if loop else maxi(frames - 1, 1))
	return win.x + (win.y - win.x) * f / div


## 맞닿는 순간(strike, 초)에 가장 가까운 프레임 번호. strike가 없으면 -1.
static func strike_frame(anim: Dictionary, win: Vector2, frames: int, loop: bool) -> int:
	if not anim.has("strike") or frames <= 0:
		return -1
	var best := 0
	var best_d := INF
	for f in frames:
		var d := absf(frame_time(win, f, frames, loop) - float(anim["strike"]))
		if d < best_d:
			best_d = d
			best = f
	return best


## 무기 끝을 기록할 동작인지 (공격·던지기).
static func wants_tips(key: String) -> bool:
	return key.begins_with("attack") or key == "throw"


static func hand_bone(skel: Skeleton3D) -> int:
	if skel == null:
		return -1
	for n in HAND_BONES:
		var i := skel.find_bone(n)
		if i >= 0:
			return i
	return -1


## 손(화면 px) → 바라보는 쪽(화면 단위 벡터)으로 걸어 마지막 불투명 픽셀. 칸 가운데 기준 오프셋.
static func find_tip(img: Image, hand: Vector2, dir: Vector2, alpha_min: float = 0.4) -> Vector2:
	var size := Vector2(img.get_width(), img.get_height())
	var last := hand
	var gap := 0
	for step in MAX_REACH:
		var p := hand + dir * step
		if p.x < 0 or p.y < 0 or p.x >= size.x or p.y >= size.y:
			break
		if img.get_pixel(int(p.x), int(p.y)).a >= alpha_min:
			last = p
			gap = 0
		else:
			gap += 1
			if gap > GAP and step > 6:
				break
	return last - size * 0.5


## 3D 손 위치·앞쪽 → 화면 px 손 위치와 화면 앞쪽 단위 벡터.
static func project(cam: Camera3D, hand_world: Vector3, forward_world: Vector3, vp_scale: Vector2) -> Array:
	var h := cam.unproject_position(hand_world) * vp_scale
	var ahead := cam.unproject_position(hand_world + forward_world * 0.5) * vp_scale
	var dir := (ahead - h).normalized() if ahead.distance_squared_to(h) > 0.01 else Vector2.DOWN
	return [h, dir]
