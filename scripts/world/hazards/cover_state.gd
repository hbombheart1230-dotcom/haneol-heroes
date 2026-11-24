class_name CoverState
extends RefCounted
## 엄폐들의 상태 (순수 로직): 어디에 있나, 몇 번 맞았나, 깨졌나. 날아가는 점이 서 있는 엄폐에 닿았는지.

var at := PackedVector2Array()
var radius := PackedFloat32Array()
var hits := PackedInt32Array()
var max_hits: int = 3


func _init(d: CoverData) -> void:
	max_hits = maxi(d.max_hits, 1)
	for p in d.pieces:
		var k := int(p.z)
		at.append(Vector2(p.x, p.y))
		radius.append(d.radii[k] if k < d.radii.size() else 40.0)
		hits.append(0)


func is_broken(i: int) -> bool:
	return hits[i] >= max_hits


func standing() -> int:
	var n := 0
	for i in hits.size():
		if not is_broken(i):
			n += 1
	return n


## 반지름 r인 점 p가 닿은 서 있는 엄폐 번호 (없으면 -1).
func touching(p: Vector2, r: float) -> int:
	for i in at.size():
		if not is_broken(i) and p.distance_to(at[i]) <= radius[i] + r:
			return i
	return -1


## a→b로 곧게 가는 반지름 r 점이 처음 닿는 서 있는 엄폐 (없으면 -1). 막힘 확률 재기·조준 판단에 쓴다.
func first_on_segment(a: Vector2, b: Vector2, r: float) -> int:
	var best := -1
	var best_t := INF
	var d := b - a
	var len2 := d.length_squared()
	for i in at.size():
		if is_broken(i):
			continue
		var t := clampf((at[i] - a).dot(d) / len2, 0.0, 1.0) if len2 > 0.0 else 0.0
		if at[i].distance_to(a + d * t) <= radius[i] + r and t < best_t:
			best_t = t
			best = i
	return best


## i번에 한 대. 반환: 이번에 깨졌는가.
func hit(i: int) -> bool:
	if is_broken(i):
		return false
	hits[i] += 1
	return is_broken(i)


## i번의 걸음 막는 원 (x, y, 반지름) — Obstacles에 넣고 뺄 때.
func circle(i: int) -> Vector3:
	return Vector3(at[i].x, at[i].y, radius[i])
