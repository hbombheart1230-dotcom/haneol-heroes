class_name Targeting
extends RefCounted
## 적 선택 유틸 (순수 함수). 동시 최대 30마리라 전수 탐색으로 충분하다.


## from에서 max_range 안의 가장 가까운 노드. 없으면 null.
static func nearest(nodes: Array, from: Vector2, max_range: float) -> Node2D:
	var best: Node2D = null
	var best_d2 := max_range * max_range
	for n in nodes:
		var node := n as Node2D
		if node == null or not is_instance_valid(node):
			continue
		var d2 := from.distance_squared_to(node.global_position)
		if d2 <= best_d2:
			best_d2 = d2
			best = node
	return best


## 방향 기술 조준 보정 (Brawl Stars식 자동 조준 + 부채꼴): facing ±cone_deg/2 안·max_range 안에서 각도가 가장
## 가까운 적 쪽. 그 안에 없으면 fallback이면 가장 가까운 적 쪽, 아니면 facing 그대로. cone_deg 0이면 끔.
static func assist_dir(nodes: Array, from: Vector2, facing: Vector2, cone_deg: float, max_range: float, fallback: bool) -> Vector2:
	var f := facing.normalized() if facing.length_squared() > 0.0001 else Vector2.DOWN
	if cone_deg <= 0.0:
		return f
	var cos_half := cos(deg_to_rad(cone_deg * 0.5))
	var best: Vector2 = Vector2.ZERO
	var best_dot := cos_half
	for n in nodes:
		var node := n as Node2D
		if node == null or not is_instance_valid(node):
			continue
		var off := node.global_position - from
		var d := off.length()
		if d < 1.0 or d > max_range:
			continue
		var dot := f.dot(off / d)
		if dot >= best_dot:
			best_dot = dot
			best = off / d
	if best != Vector2.ZERO:
		return best
	if fallback:
		var near := nearest(nodes, from, max_range)
		if near and from.distance_squared_to(near.global_position) > 1.0:
			return (near.global_position - from).normalized()
	return f


## from 기준 facing 방향 arc_degrees 부채꼴, radius 안의 노드들.
static func in_arc(nodes: Array, from: Vector2, facing: Vector2, radius: float, arc_degrees: float) -> Array[Node2D]:
	var out: Array[Node2D] = []
	var dir := facing.normalized() if facing.length_squared() > 0.0001 else Vector2.DOWN
	var cos_half := cos(deg_to_rad(arc_degrees * 0.5))
	for n in nodes:
		var node := n as Node2D
		if node == null or not is_instance_valid(node):
			continue
		var offset := node.global_position - from
		var d := offset.length()
		if d > radius:
			continue
		# 몸에 붙어 있는 적은 방향과 무관하게 맞는다.
		if d < 1.0 or dir.dot(offset / d) >= cos_half:
			out.append(node)
	return out
