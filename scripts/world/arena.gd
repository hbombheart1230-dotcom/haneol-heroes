class_name Arena
extends Node2D
## 임시 쿼터뷰 바닥: 마름모 타일 격자. 정식 그래픽 아님.

@export var rect: Rect2 = Rect2(-900, -1400, 1800, 2800)
@export var tile_size: Vector2 = Vector2(128, 64)


func _draw() -> void:
	draw_rect(rect, Color(0.12, 0.14, 0.16))
	var half := tile_size * 0.5
	var cols := int(ceil(rect.size.x / tile_size.x))
	var rows := int(ceil(rect.size.y / half.y))
	for r in rows:
		for c in cols:
			var center := rect.position + Vector2(c * tile_size.x + (half.x if r % 2 else 0.0), r * half.y)
			if not rect.has_point(center):
				continue
			var shade := 0.2 if (r + c * 2) % 3 else 0.23
			var pts := PackedVector2Array([
				center + Vector2(0, -half.y), center + Vector2(half.x, 0),
				center + Vector2(0, half.y), center + Vector2(-half.x, 0)])
			draw_colored_polygon(pts, Color(shade, shade + 0.03, shade + 0.05))
	draw_rect(rect, Color(0.4, 0.6, 0.8, 0.6), false, 6.0)
