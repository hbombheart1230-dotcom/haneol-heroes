class_name WalkArea
extends RefCounted
## 무대에서 걸을 수 있는 곳 (StageTheme.walk_area, 꼭짓점 다각형, 몸 중심 기준): 영웅·적·등장 자리를 이 안에 둔다.
## 엔진 Geometry2D로 안팎을 보고, 밖이면 가장 가까운 경계 점으로 되돌린다 — 이동(move_and_slide) 뒤에 부르면
## 경계를 따라가는 성분은 남아서 벽에 붙어도 미끄러지듯 움직인다. 비어 있으면 아무것도 하지 않는다.
## 충돌 벽(StaticBody2D) 대신 이 방식인 까닭: 등장 자리 고르기·시뮬(물리 서버 없이 손으로 굴림)까지 같은 한 곳에서 막으려고.

## 경계 점을 안쪽으로 이만큼(px) 들인다 (경계 위 점이 다각형 밖으로 판정되지 않게).
const NUDGE := 1.0


static func contains(poly: PackedVector2Array, p: Vector2) -> bool:
	return poly.size() < 3 or Geometry2D.is_point_in_polygon(p, poly)


## p가 안이면 그대로, 밖이면 가장 가까운 경계 점 (조금 안쪽).
static func clamp_point(poly: PackedVector2Array, p: Vector2) -> Vector2:
	if contains(poly, p):
		return p
	var best := p
	var bd := INF
	for i in poly.size():
		var q := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
		var d := q.distance_squared_to(p)
		if d < bd:
			bd = d
			best = q
	var c := Vector2.ZERO
	for v in poly:
		c += v
	c /= poly.size()
	return best + (c - best).normalized() * NUDGE


## 적 하나를 자기 생성기의 걸을 수 있는 곳 안으로 (밀려남·날아감 포함, 이동 뒤에 부른다).
static func keep_enemy(e: Node2D) -> void:
	var sp := e.get_parent() as EnemySpawner
	if sp and sp.walk_area.size() >= 3:
		e.global_position = clamp_point(sp.walk_area, e.global_position)
