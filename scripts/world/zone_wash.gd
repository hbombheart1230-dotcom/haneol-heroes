class_name ZoneWash
extends Node2D
## 구역 색 덮개 (ZoneHop, ZoneData.wash): 배경 지도 위에 반투명 색 한 장 (임시 색판). 투명이면 그리지 않는다.

var color := Color(0, 0, 0, 0)
var rect := Rect2()


func show_wash(c: Color, r: Rect2) -> void:
	color = c
	rect = r
	visible = c.a > 0.0
	queue_redraw()


func _draw() -> void:
	if color.a > 0.0:
		draw_rect(rect, color)
