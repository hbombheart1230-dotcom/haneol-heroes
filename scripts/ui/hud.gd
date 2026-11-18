class_name Hud
extends Control
## P0-A HUD: 대시 충전 표시 + 터치 디버그 표시(이동 앵커, FPS).
## 고정 조이스틱 UI는 그리지 않는다. 디버그 표시는 show_touch_debug로 끌 수 있다.

@export var player: Player
@export var controller: TouchController
@export var show_touch_debug: bool = true


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player:
		_draw_dash_pips()
	if show_touch_debug and controller:
		_draw_touch_debug()


func _draw_dash_pips() -> void:
	var d := player.dash
	var origin := Vector2(48, size.y - 64)
	for i in d.max_charges:
		var c := origin + Vector2(i * 56, 0)
		draw_circle(c, 20, Color(0, 0, 0, 0.5))
		if i < d.charges:
			draw_circle(c, 16, Color(0.4, 0.8, 1.0))
		elif i == d.charges:
			draw_arc(c, 16, -PI / 2, -PI / 2 + TAU * d.get_recharge_ratio(), 24, Color(0.4, 0.8, 1.0, 0.8), 4.0)


func _draw_touch_debug() -> void:
	var t := controller.touch_input
	if t.is_active():
		draw_arc(t.get_anchor(), t.full_speed_radius, 0, TAU, 32, Color(1, 1, 1, 0.12), 2.0)
		draw_circle(t.get_anchor(), 6, Color(1, 1, 1, 0.25))
		draw_circle(t.get_current(), 10, Color(1, 1, 1, 0.3))
	var font := get_theme_default_font()
	var info := "FPS %d  dash %d/%d%s" % [Engine.get_frames_per_second(), player.dash.charges,
		player.dash.max_charges, "  DASH" if player.is_dashing() else ""]
	draw_string(font, Vector2(16, 40), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.7))
