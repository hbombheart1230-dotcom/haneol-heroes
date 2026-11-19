class_name IntroTimeline
extends RefCounted
## 이야기 인트로 시간 계산 (그리기와 분리해 테스트한다).
## - 장면은 차례대로, 장면 처음·끝 fade초 동안 검게 어두워진다.
## - 줄은 장면 앞쪽 75% 동안 고르게 하나씩 나타나 LINE_IN초 동안 떠오르며 밝아진다.

const LINE_IN := 1.2

var durations: PackedFloat32Array
var fade: float


func _init(d: PackedFloat32Array, fade_time: float) -> void:
	durations = d
	fade = fade_time


func total() -> float:
	var s := 0.0
	for d in durations:
		s += d
	return s


## t초일 때 장면 번호 (끝났으면 장면 수).
func slide_at(t: float) -> int:
	var acc := 0.0
	for i in durations.size():
		acc += durations[i]
		if t < acc:
			return i
	return durations.size()


func slide_start(i: int) -> float:
	var acc := 0.0
	for k in mini(i, durations.size()):
		acc += durations[k]
	return acc


## 장면 안에서 검은 막의 진하기 (0 = 다 보임, 1 = 깜깜).
func black(i: int, local: float) -> float:
	if i >= durations.size() or fade <= 0.0:
		return 0.0
	var d := durations[i]
	return clampf(maxf(1.0 - local / fade, 1.0 - (d - local) / fade), 0.0, 1.0)


## k번째 줄이 나타나는 시각(장면 안), 줄 수 n.
func line_time(i: int, k: int, n: int) -> float:
	var d := durations[i] if i < durations.size() else 0.0
	return fade + (d * 0.75 - fade) * float(k) / maxf(float(n), 1.0)


## 줄의 밝기 0~1과 떠오름 0~1 (1 = 제자리).
func line_alpha(i: int, k: int, n: int, local: float) -> float:
	return clampf((local - line_time(i, k, n)) / LINE_IN, 0.0, 1.0)


## 다음 장면으로 넘기기: 지금 장면의 끝 (페이드가 바로 시작되게 fade만큼 앞).
func skip_target(t: float) -> float:
	var i := slide_at(t)
	if i >= durations.size():
		return t
	var end := slide_start(i) + durations[i]
	return maxf(t, end - fade)
