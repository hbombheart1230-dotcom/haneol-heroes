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


## 막대 그림의 양 끝 (가늘어지는 자리) 폭: 늘이지 않고 높이에 맞춘 크기로 그대로 붙인다.
const CAP_SRC := 28.0


## 붓으로 그은 먹선 바탕 위에 획이 차는 막대. rect = 막대 자리, ratio 0~1.
static func bar(c: CanvasItem, rect: Rect2, ratio: float, fill: Color, back: Color = Color(1, 1, 1, 0.8),
		pad: float = 3.0) -> void:
	_patch(c, BAR_BACK, rect.grow_individual(pad * 2.0, pad, pad * 2.0, pad), back)
	fill_part(c, rect, ratio, fill)


## 막대 자리 rect에 획 하나를 ratio만큼 (자국·겹쳐 그리기용). 끝은 둥글게 맺힌다.
static func fill_part(c: CanvasItem, rect: Rect2, ratio: float, fill: Color) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	if ratio <= 0.0:
		return
	_patch(c, BAR_FILL, Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), fill)


## 가운데만 늘이고 양 끝은 그대로 (너무 짧으면 통째로 늘임).
static func _patch(c: CanvasItem, tex: Texture2D, dst: Rect2, color: Color) -> void:
	var th := float(tex.get_height())
	var tw := float(tex.get_width())
	var cap := CAP_SRC * dst.size.y / th
	if dst.size.x < cap * 2.0 + 2.0:
		c.draw_texture_rect(tex, dst, false, color)
		return
	c.draw_texture_rect_region(tex, Rect2(dst.position, Vector2(cap, dst.size.y)), Rect2(0, 0, CAP_SRC, th), color)
	c.draw_texture_rect_region(tex, Rect2(dst.position + Vector2(cap, 0), Vector2(dst.size.x - cap * 2.0, dst.size.y)),
		Rect2(CAP_SRC, 0, tw - CAP_SRC * 2.0, th), color)
	c.draw_texture_rect_region(tex, Rect2(dst.position + Vector2(dst.size.x - cap, 0), Vector2(cap, dst.size.y)),
		Rect2(tw - CAP_SRC, 0, CAP_SRC, th), color)


## 붓으로 그은 고리: 바깥 가장자리가 반지름 radius에 닿는다.
static func ring(c: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	c.draw_texture_rect(RING, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)


## 먹 번짐 원판 (반지름 radius 안).
static func wash(c: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	c.draw_texture_rect(WASH, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)


## 먹 번짐 사각 판 (rect 안).
static func wash_rect(c: CanvasItem, rect: Rect2, color: Color) -> void:
	c.draw_texture_rect(WASH_RECT, rect, false, color)
