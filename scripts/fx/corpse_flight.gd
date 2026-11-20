class_name CorpseFlight
extends RefCounted
## 처치된 적이 날아가는 포물선 (순수 로직). 땅 위 위치는 감속하며 앞으로, 높이는 포물선, 회전은 일정.

var from: Vector2
var to: Vector2
var height: float
var duration: float
## 회전 수 × 방향(+1/-1).
var spins: float


func _init(p_from: Vector2, dir: Vector2, distance: float, p_height: float, p_duration: float, p_spins: float) -> void:
	from = p_from
	var d := dir.normalized() if dir.length_squared() > 0.0001 else Vector2.UP
	to = p_from + d * distance
	height = p_height
	duration = maxf(p_duration, 0.01)
	# 오른쪽으로 날아가면 시계 방향으로 돈다.
	spins = p_spins * (1.0 if d.x >= 0.0 else -1.0)


## 0~1 진행률.
func progress(t: float) -> float:
	return clampf(t / duration, 0.0, 1.0)


## 땅 위 위치 (빠르게 나가서 느려짐).
func ground(t: float) -> Vector2:
	var k := progress(t)
	return from.lerp(to, 1.0 - (1.0 - k) * (1.0 - k))


## 땅에서 오른 높이(px). 시작·끝 0, 가운데 height.
func lift(t: float) -> float:
	var k := progress(t)
	return 4.0 * height * k * (1.0 - k)


func angle(t: float) -> float:
	return progress(t) * spins * TAU


func landed(t: float) -> bool:
	return t >= duration
