class_name GhostFire
extends Node2D
## 망령 발밑 도깨비불: 군대 색(EnemyData.ghost_color) 불꽃 혀 몇 가닥이 일렁인다. 적은 사람 모습으로 굽고
## 망령 느낌은 여기와 셰이더(enemy_rim: 일렁이는 테두리·비침·발쪽 사라짐)로 준다.
## 적 스크립트를 건드리지 않고 한 노드에서 모두 그린다 (EnemyBars와 같은 방식).

## 불꽃 혀 수, 기본 높이·폭(px, 몸 반지름 배율), 일렁임 빠르기.
@export var tongues: int = 5
@export var height: float = 2.0
@export var width: float = 0.32
@export var speed: float = 7.0

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## 그릴 불: [발 위치, 몸 반지름 × 크기 배율, 색, 위상].
func fires() -> Array:
	var out: Array = []
	if not is_inside_tree():
		return out
	for n in get_tree().get_nodes_in_group(Enemy.GROUP):
		var e := n as Enemy
		if e == null or not is_instance_valid(e) or e.data == null or e.data.ghost_color.a <= 0.0:
			continue
		if e.health and e.health.is_dead():
			continue
		var r := e.body_radius * e.data.ghost_fire_scale
		out.append([to_local(e.global_position) + Vector2(0, e.body_radius * 0.55), r, e.data.ghost_color,
			float(e.get_instance_id() % 997) * 0.37])
	return out


func _draw() -> void:
	for f in fires():
		_draw_fire(f[0], f[1], f[2], f[3])


func _draw_fire(foot: Vector2, r: float, col: Color, phase: float) -> void:
	draw_set_transform(foot, 0.0, Vector2(1.0, 0.38))  # 바닥 빛무리
	draw_circle(Vector2.ZERO, r * 1.35, Color(col, 0.32 * col.a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for k in tongues:
		var u := (float(k) / maxf(tongues - 1, 1)) * 2.0 - 1.0  # -1 ~ 1
		var flick := 0.65 + 0.35 * sin(_t * speed + phase + k * 1.7)
		var h := r * height * flick * (1.0 - absf(u) * 0.45)
		var w := r * width
		var base := foot + Vector2(u * r * 0.85, 0)
		var sway := sin(_t * speed * 0.6 + phase + k) * w * 0.8
		var tip := base + Vector2(sway, -h)
		draw_colored_polygon(PackedVector2Array([base - Vector2(w, 0), tip, base + Vector2(w, 0)]),
			Color(col, 0.65 * col.a))
		draw_colored_polygon(PackedVector2Array([base - Vector2(w * 0.45, 0), base.lerp(tip, 0.7), base + Vector2(w * 0.45, 0)]),
			Color(col.lightened(0.5), 0.8 * col.a))
