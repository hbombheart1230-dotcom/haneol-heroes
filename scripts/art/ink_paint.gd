class_name InkPaint
extends RefCounted
## 전투 화면의 단순 도형을 대신하는 먹·붓 그림 그리기 (그림 한 장씩 재사용: assets/vfx/ink_*.png, tools/art/bake_ink_ui.py).
## 매 프레임 많이 불려도 새 배열을 만들지 않는다 (텍스처 사각형 호출만).

const BAR_BACK := preload("res://assets/vfx/ink_bar_back.png")
const BAR_FILL := preload("res://assets/vfx/ink_bar_fill.png")
const WASH := preload("res://assets/vfx/ink_wash.png")
const WASH_RECT := preload("res://assets/vfx/ink_wash_rect.png")
const RING := preload("res://assets/vfx/ink_ring.png")
const ARROW := preload("res://assets/vfx/ink_arrow.png")
const TAIL := preload("res://assets/vfx/ink_tail.png")
const STREAK := preload("res://assets/vfx/ink_streak.png")
const EDGE := preload("res://assets/vfx/ink_edge.png")


## 붓으로 그은 막대: 옅은 먹 획 바탕 위에 붉은 획이 왼쪽에서 찬다. 획 그림 한 장을 찬 만큼 가로로 늘여 쓴다
## (시작은 굵고 둥글고 끝은 가늘게 빠지는 한 획이라, 얼마를 채우든 끝이 붓끝으로 맺힌다).
static func bar(c: CanvasItem, rect: Rect2, ratio: float, fill: Color, back: Color = Color(1, 1, 1, 0.55),
		pad: float = 3.0, under: Color = Color(0, 0, 0, 0)) -> void:
	if under.a > 0.0:  # 어두운 바닥에서도 빈 자리가 보이게 옅은 한지색 밑칠 (먹 번짐 사각 판)
		wash_rect(c, rect.grow_individual(pad * 2.5, pad * 1.6, pad * 2.5, pad * 1.6), under)
	c.draw_texture_rect(BAR_BACK, rect.grow_individual(pad * 2.0, pad, pad * 2.0, pad), false, back)
	fill_part(c, rect, ratio, fill)


## 막대 자리 rect에 획 하나를 ratio만큼 (자국·겹쳐 그리기용).
static func fill_part(c: CanvasItem, rect: Rect2, ratio: float, fill: Color) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	if ratio <= 0.0:
		return
	c.draw_texture_rect(BAR_FILL, Rect2(rect.position, Vector2(maxf(rect.size.x * ratio, rect.size.y * 0.8), rect.size.y)), false, fill)


## 예고 줄 가장자리: 거친 붓 획 한 줄 (x0~x1, y가 줄 가운데, 두께 thick).
static func edge(c: CanvasItem, x0: float, x1: float, y: float, thick: float, color: Color) -> void:
	c.draw_texture_rect(EDGE, Rect2(x0, y - thick * 0.5, x1 - x0, thick), false, color)


## 붓으로 그은 고리: 바깥 가장자리가 반지름 radius에 닿는다.
static func ring(c: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	c.draw_texture_rect(RING, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)


## 먹 번짐 원판 (반지름 radius 안).
static func wash(c: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	c.draw_texture_rect(WASH, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)


## 먹 번짐 사각 판 (rect 안).
static func wash_rect(c: CanvasItem, rect: Rect2, color: Color) -> void:
	c.draw_texture_rect(WASH_RECT, rect, false, color)


## 먹 꼬리 획: from에서 시작해 dir 방향으로 length만큼 가늘게 빠진다 (굵은 쪽이 from).
static func tail(c: CanvasItem, from: Vector2, dir: Vector2, length: float, thick: float, color: Color) -> void:
	c.draw_set_transform(from, dir.angle(), Vector2.ONE)
	c.draw_texture_rect(TAIL, Rect2(0.0, -thick * 0.5, length, thick), false, color)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
