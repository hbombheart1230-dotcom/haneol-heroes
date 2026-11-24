class_name GhostFire
extends Node2D
## 망령 발밑 도깨비불: 군대 색(EnemyData.ghost_color) 불꽃 혀 몇 가닥이 일렁인다. 적은 사람 모습으로 굽고
## 망령 느낌은 여기와 셰이더(enemy_rim: 일렁이는 테두리·비침·발쪽 사라짐)로 준다.
## 적 스크립트를 건드리지 않고 한 노드에서 모두 그린다 (EnemyBars와 같은 방식).

## 불꽃 혀 수, 기본 높이·폭(px, 몸 반지름 배율), 일렁임 빠르기.
@export var tongues: int = 5
@export var height: float = 1.3
@export var width: float = 0.32
@export var speed: float = 7.0

var _t := 0.0
## 바닥 빛무리 타원 조각 수.
const RING := 16


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
	var mesh := build_mesh(fires(), _t)
	if not mesh[0].is_empty():  # 모든 불을 삼각형 하나의 목록으로 한 번에 (마리당 그리기 호출 약 11 → 판 전체 1)
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), mesh[2], mesh[0], mesh[1])


## 빛무리(타원 부채꼴) + 불꽃 혀(바깥·안쪽 삼각형)를 점·색·번호 배열로 [PackedVector2Array, PackedColorArray, PackedInt32Array].
## 예전 draw_circle·draw_colored_polygon과 같은 모양·색 (타원은 RING 조각). 순수 계산 (시험용).
func build_mesh(list: Array, t: float) -> Array:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for f in list:
		var foot: Vector2 = f[0]
		var r: float = f[1]
		var col: Color = f[2]
		var phase: float = f[3]
		var glow := Color(col, 0.28 * col.a)
		var c0 := pts.size()
		pts.append(foot)
		cols.append(glow)
		for i in RING:
			pts.append(foot + Vector2.from_angle(TAU * i / RING) * r * 1.35 * Vector2(1.0, 0.38))
			cols.append(glow)
		for i in RING:
			idx.append_array([c0, c0 + 1 + i, c0 + 1 + (i + 1) % RING])
		for k in tongues:
			var u := (float(k) / maxf(tongues - 1, 1)) * 2.0 - 1.0  # -1 ~ 1
			var flick := 0.65 + 0.35 * sin(t * speed + phase + k * 1.7)
			var h := r * height * flick * (1.0 - absf(u) * 0.45)
			var w := r * width
			var base := foot + Vector2(u * r * 0.85, 0)
			var sway := sin(t * speed * 0.6 + phase + k) * w * 0.8
			var tip := base + Vector2(sway, -h)
			_tri(pts, cols, idx, [base - Vector2(w, 0), tip, base + Vector2(w, 0)], Color(col, 0.5 * col.a))
			_tri(pts, cols, idx, [base - Vector2(w * 0.45, 0), base.lerp(tip, 0.7), base + Vector2(w * 0.45, 0)],
				Color(col.lightened(0.4), 0.55 * col.a))
	return [pts, cols, idx]


static func _tri(pts: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array, v: Array, c: Color) -> void:
	var n := pts.size()
	for p in v:
		pts.append(p)
		cols.append(c)
	idx.append_array([n, n + 1, n + 2])
