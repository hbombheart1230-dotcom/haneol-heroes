class_name PerfStats
extends RefCounted
## 한 판 동안의 프레임 성능 기록 (P0-D 실기기 측정용).
## 평균 FPS, 하위 1% FPS(가장 느린 1% 프레임의 평균), 최악 프레임, 최대 동시 적 수.

var frames: int = 0
var total_time: float = 0.0
var worst_frame: float = 0.0
var max_enemies: int = 0
var _frame_times: PackedFloat32Array = PackedFloat32Array()


func sample(delta: float, enemies: int) -> void:
	if delta <= 0.0:
		return
	frames += 1
	total_time += delta
	worst_frame = maxf(worst_frame, delta)
	max_enemies = maxi(max_enemies, enemies)
	_frame_times.append(delta)


func avg_fps() -> float:
	return frames / total_time if total_time > 0.0 else 0.0


## 가장 느린 1% 프레임들의 평균 FPS.
func low_1pct_fps() -> float:
	if _frame_times.is_empty():
		return 0.0
	var sorted := _frame_times.duplicate()
	sorted.sort()
	var n := maxi(1, int(ceil(sorted.size() * 0.01)))
	var sum := 0.0
	for i in n:
		sum += sorted[sorted.size() - 1 - i]
	return n / sum if sum > 0.0 else 0.0


func summary() -> String:
	return "평균 초당 %d장 · 하위 1%% %d장 · 최악 %d밀리초 · 최대 적 %d" % [
		roundi(avg_fps()), roundi(low_1pct_fps()), roundi(worst_frame * 1000.0), max_enemies]
