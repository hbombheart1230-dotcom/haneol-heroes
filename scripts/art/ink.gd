class_name Ink
extends RefCounted
## 수묵풍 임시 아트 도구 (코드로 그림, 외부 이미지 없음). 정식 아트로 교체 시 이 파일과 *_art.gd만 바꾼다.
## 붓 터치는 가장자리를 사인 잡음으로 흔든 다각형으로 흉내 낸다 (프레임마다 같은 모양이 되도록 seed 고정).

const PAPER := Color(0.92, 0.88, 0.79)
const INK := Color(0.09, 0.09, 0.11)
const INK_SOFT := Color(0.09, 0.09, 0.11, 0.35)
## 인주(낙관) 빨강: 적·위험 표시.
const SEAL := Color(0.72, 0.13, 0.1)
## 이순신 쪽빛.
const INDIGO := Color(0.13, 0.27, 0.55)
const WATER := Color(0.25, 0.55, 0.85)
const GOLD := Color(0.78, 0.6, 0.18)


## 붓으로 찍은 듯한 덩어리 (원 기반, 가장자리 흔들림).
static func blob(canvas: CanvasItem, center: Vector2, radius: float, color: Color, seed: float = 0.0,
		rough: float = 0.12, squash: float = 1.0) -> void:
	var pts := PackedVector2Array()
	var n := 18
	for i in n:
		var a := TAU * i / n
		var wobble := 1.0 + rough * (sin(a * 3.0 + seed) * 0.6 + sin(a * 7.0 + seed * 2.3) * 0.4)
		pts.append(center + Vector2(cos(a), sin(a) * squash) * radius * wobble)
	canvas.draw_colored_polygon(pts, color)


## 양 끝이 가늘어지는 붓 획.
static func stroke(canvas: CanvasItem, a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var d := b - a
	if d.length_squared() < 0.01:
		return
	var n := d.orthogonal().normalized() * width * 0.5
	var mid := a + d * 0.35
	var pts := PackedVector2Array([a, mid + n, b, mid - n * 0.7])
	canvas.draw_colored_polygon(pts, color)


## 붓 획으로 그린 원호 (예고 테두리 등).
static func ring(canvas: CanvasItem, center: Vector2, radius: float, width: float, color: Color,
		squash: float = 0.6, seed: float = 0.0) -> void:
	var pts := PackedVector2Array()
	var n := 40
	for i in n + 1:
		var a := TAU * i / n
		var w := 1.0 + 0.04 * sin(a * 5.0 + seed)
		pts.append(center + Vector2(cos(a), sin(a) * squash) * radius * w)
	canvas.draw_polyline(pts, color, width)


## 먹물 튀김: 중심 덩어리 + 주변 작은 방울.
static func splash(canvas: CanvasItem, center: Vector2, radius: float, color: Color, seed: float = 0.0) -> void:
	blob(canvas, center, radius * 0.55, color, seed, 0.3)
	for i in 6:
		var a := seed * 1.7 + TAU * i / 6.0
		var d := radius * (0.8 + 0.3 * sin(seed + i))
		canvas.draw_circle(center + Vector2.from_angle(a) * d, radius * (0.12 + 0.06 * cos(i + seed)), color)


## 바닥 그림자 (옅은 먹 번짐).
static func shadow(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	blob(canvas, center, radius, Color(INK, 0.18), 1.3, 0.08, 0.4)


## 무게감 그림자: 번진 옅은 가장자리 + 진한 먹 속 (발이 땅을 누르는 느낌). alpha = 속 진하기.
static func weight_shadow(canvas: CanvasItem, center: Vector2, radius: float, alpha: float) -> void:
	blob(canvas, center, radius, Color(INK, alpha * 0.5), 1.3, 0.1, 0.4)
	blob(canvas, center, radius * 0.66, Color(INK, alpha), 2.1, 0.08, 0.36)
