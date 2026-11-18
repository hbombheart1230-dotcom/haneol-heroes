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
