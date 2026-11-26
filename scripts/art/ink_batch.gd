class_name InkBatch
extends RefCounted
## 먹 획·덩어리를 모아 한 번에 그리기 (Ink.stroke·Ink.blob와 같은 모양·같은 색): draw_colored_polygon은 그릴 때마다
## 그리기 호출이 하나씩 들어 (GL 호환 렌더러는 다각형을 묶지 않는다) 풀숲처럼 획이 수백 개면 폰에서 무겁다.
## 여기 모은 삼각형을 canvas_item_add_triangle_array 한 번으로 낸다 (넣은 차례 = 그리는 차례, 겹침 그대로).
## 2026-11-26 초충도 끊김: 풀숲 장치가 한 프레임 약 480 그리기 호출 (tools/perf/mid_boss_perf.gd --offclass=GrassHide,GrassFire).
## 같은 날 광개토 1번 벼락: 맞은 자리 효과(HitImpactLayer)의 번개 줄기·방울·심이 하나씩 그리기 호출.

var points := PackedVector2Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()
## 그림을 입힐 때만 (tex_quad): 꼭짓점마다 그림 좌표. 한 묶음은 그림 한 장 (flush의 tex).
var uvs := PackedVector2Array()


func clear() -> void:
	points.clear()
	colors.clear()
	indices.clear()
	uvs.clear()


## Ink.stroke와 같은 네 점 (a, 35% 지점 ± 굵기) 붓 획.
func stroke(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var d := b - a
	if d.length_squared() < 0.01:
		return
	var n := d.orthogonal().normalized() * width * 0.5
	var mid := a + d * 0.35
	var i := points.size()
	points.append_array(PackedVector2Array([a, mid + n, b, mid - n * 0.7]))
	for k in 4:
		colors.append(color)
	indices.append_array(PackedInt32Array([i, i + 1, i + 2, i, i + 2, i + 3]))


## Ink.blob와 같은 18점 덩어리 (가운데에서 부채꼴로).
func blob(center: Vector2, radius: float, color: Color, seed: float = 0.0, rough: float = 0.12, squash: float = 1.0) -> void:
	var c := points.size()
	points.append(center)
	colors.append(color)
	var n := 18
	for i in n:
		var a := TAU * i / n
		var wobble := 1.0 + rough * (sin(a * 3.0 + seed) * 0.6 + sin(a * 7.0 + seed * 2.3) * 0.4)
		points.append(center + Vector2(cos(a), sin(a) * squash) * radius * wobble)
		colors.append(color)
	for i in n:
		indices.append_array(PackedInt32Array([c, c + 1 + i, c + 1 + (i + 1) % n]))


## 네 점 사각형 (draw_colored_polygon(네 점)과 같다: 0-1-2, 0-2-3).
func quad(pts: PackedVector2Array, color: Color) -> void:
	var i := points.size()
	points.append_array(pts)
	for k in 4:
		colors.append(color)
	indices.append_array(PackedInt32Array([i, i + 1, i + 2, i, i + 2, i + 3]))


## 채운 원 (draw_circle과 같은 모양: 작은 원은 SEGMENTS각형이면 눈으로 같다).
const SEGMENTS := 24


func circle(center: Vector2, radius: float, color: Color) -> void:
	if radius <= 0.0:
		return
	var c := points.size()
	points.append(center)
	colors.append(color)
	for k in SEGMENTS:
		points.append(center + Vector2.from_angle(TAU * k / SEGMENTS) * radius)
		colors.append(color)
	for k in SEGMENTS:
		indices.append_array(PackedInt32Array([c, c + 1 + k, c + 1 + (k + 1) % SEGMENTS]))


## 굵기 width 곧은 선 (draw_line과 같다: 양끝 그대로의 사각형).
func line(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var d := b - a
	if d.length_squared() < 0.0001:
		return
	var n := d.orthogonal().normalized() * width * 0.5
	quad(PackedVector2Array([a + n, b + n, b - n, a - n]), color)


## Ink.splash와 같은 먹물 튀김: 가운데 덩어리 + 둘레 방울 여섯.
func splash(center: Vector2, radius: float, color: Color, seed: float = 0.0) -> void:
	blob(center, radius * 0.55, color, seed, 0.3)
	for i in 6:
		var a := seed * 1.7 + TAU * i / 6.0
		var d := radius * (0.8 + 0.3 * sin(seed + i))
		circle(center + Vector2.from_angle(a) * d, radius * (0.12 + 0.06 * cos(i + seed)), color)


## 그림 입힌 네 점 조각 (draw_polygon(네 점, 색, uv, 그림)과 같다). 그림은 flush(canvas, tex)에서 한 장.
func tex_quad(pts: PackedVector2Array, cols: PackedColorArray, quad_uvs: PackedVector2Array) -> void:
	var i := points.size()
	points.append_array(pts)
	colors.append_array(cols)
	uvs.append_array(quad_uvs)
	indices.append_array(PackedInt32Array([i, i + 1, i + 2, i, i + 2, i + 3]))


## 모은 것을 canvas에 한 번에 그리고 비운다 (_draw 안에서 부른다).
## tex가 있으면 tex_quad로 모은 것을 그 그림으로.
func flush(canvas: CanvasItem, tex: Texture2D = null) -> void:
	if not indices.is_empty():
		if tex:
			RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), indices, points, colors, uvs,
				PackedInt32Array(), PackedFloat32Array(), tex.get_rid())
		else:
			RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), indices, points, colors)
	clear()
