class_name SwingArc
extends RefCounted
## 검기 궤적 계산 (순수, 테스트용): 휘두르기 시각표, 머리 각도, 띠 꼭짓점.
## 시각은 휘두르기 신호(melee_windup)부터 잰 초. 머리는 부채꼴 한쪽 끝에서 다른 쪽 끝으로 휩쓸고
## (가운데가 빠르게: smoothstep), 칼이 닿는 순간(strike)에는 가운데를 조금 지난다.

var aim: float = 0.0
var half: float = 0.5
var flip: float = 1.0
var radius: float = 100.0
var width: float = 30.0
var start: float = 0.0
var strike: float = 0.0
var finish: float = 0.0


## pause = 3타 모으기, delay = 칼이 닿기까지 (모으기 뒤). 모으는 동안은 그리지 않는다.
func setup(p_aim: float, p_half: float, p_flip: float, p_radius: float, p_width: float,
		pause: float, delay: float, d: SwingTrailData) -> void:
	aim = p_aim
	half = p_half
	flip = p_flip
	radius = p_radius
	width = p_width
	strike = pause + delay
	start = maxf(pause, strike - d.lead)
	finish = strike + d.follow


## 0 (시작 쪽 끝) → 1 (반대쪽 끝).
func head_u(time: float) -> float:
	var s := clampf((time - start) / maxf(finish - start, 0.001), 0.0, 1.0)
	return s * s * (3.0 - 2.0 * s)


func angle_at(time: float) -> float:
	return aim + half * flip * (2.0 * head_u(time) - 1.0)


## 꼬리까지 다 사라졌으면 false.
func alive(time: float, d: SwingTrailData) -> bool:
	return time < finish + d.life


## 띠 꼭짓점을 채운다 (배열 길이 = 마디 + 1, 미리 만든 것을 재사용). f = 0 꼬리 → 1 머리 (굵기·진하기 비율),
## 아직 시작 전인 마디는 f를 0으로 (그리지 않음).
func fill(time: float, d: SwingTrailData, outer: PackedVector2Array, inner: PackedVector2Array,
		f: PackedFloat32Array) -> void:
	var n := outer.size() - 1
	for i in n + 1:
		var k := float(i) / n
		var ts := time - d.life * (1.0 - k)
		var a := angle_at(ts)
		var dir := Vector2(cos(a), sin(a) * d.squash)
		var w := width * pow(k, d.taper)
		if ts < start or time < start:
			w = 0.0
		outer[i] = dir * radius
		inner[i] = dir * maxf(radius - w, 0.0)
		f[i] = k if w > 0.0 else 0.0
