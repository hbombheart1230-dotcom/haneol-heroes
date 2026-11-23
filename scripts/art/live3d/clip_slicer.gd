class_name ClipSlicer
extends RefCounted
## 동작 자르기 (순수 계산): 원본 동작의 [start, end] 구간을 길이 out_len(초)로 늘이거나 줄여 새 동작으로 만든다.
## 구운 시트와 같은 길이가 되므로 1배속 재생 = 지금 피해 시점 그대로. 뿌리 뼈 수평 이동은 rest로 고정 (굽기와 같다).
## Godot에 동작 일부를 잘라 내는 기본 기능이 없어 직접 만든다 (트랙 보간 함수만 쓴다).

## 결과 키 간격 (초). 원본(30fps)보다 촘촘해 늘여도 매끄럽다.
const STEP := 1.0 / 60.0


## win = (start, end) 초. loop면 반복 동작 (끝 → 처음이 이어진다).
static func slice(src: Animation, win: Vector2, out_len: float, loop: bool, root_track: NodePath = NodePath(""),
		root_rest: Vector3 = Vector3.ZERO) -> Animation:
	var a := Animation.new()
	a.length = maxf(out_len, STEP)
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var n := maxi(ceili(a.length / STEP), 1)
	var last := n - 1 if loop else n  # 반복이면 끝 키 = 처음 키라 빼고, 아니면 끝까지
	for t in src.get_track_count():
		var type := src.track_get_type(t)
		if type not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			continue
		var path := src.track_get_path(t)
		var i := a.add_track(type)
		a.track_set_path(i, path)
		a.track_set_interpolation_type(i, Animation.INTERPOLATION_LINEAR)
		for k in last + 1:
			var ot := minf(k * STEP, a.length)
			var st := source_time(ot, win, a.length)
			match type:
				Animation.TYPE_POSITION_3D:
					var p := src.position_track_interpolate(t, st)
					if path == root_track:
						p = Vector3(root_rest.x, p.y, root_rest.z)
					a.position_track_insert_key(i, ot, p)
				Animation.TYPE_ROTATION_3D:
					a.rotation_track_insert_key(i, ot, src.rotation_track_interpolate(t, st))
				Animation.TYPE_SCALE_3D:
					a.scale_track_insert_key(i, ot, src.scale_track_interpolate(t, st))
	return a


## 결과 시각 → 원본 시각 (구간 안에서 비례).
static func source_time(out_t: float, win: Vector2, out_len: float) -> float:
	return win.x + (win.y - win.x) * clampf(out_t / maxf(out_len, 0.0001), 0.0, 1.0)


## 굽기 구간 (BakeTip.window와 같은 규칙): 없거나 이상하면 전체.
static func window(clip: Dictionary, length: float) -> Vector2:
	var s := clampf(float(clip.get("start", 0.0)), 0.0, length)
	var e := clampf(float(clip.get("end", length)), 0.0, length)
	return Vector2(0.0, length) if e <= s else Vector2(s, e)
