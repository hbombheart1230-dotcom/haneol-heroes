class_name ZoneHopView
extends Node2D
## 구역 건너뛰기 그림 (ZoneHop): 영웅 옆 다음 구역 쪽 먹 화살과 안내 글(전장 좌표), 넘어가는 동안 화면 먹 덮기와 구역 이름(화면 좌표).

var cover: float = 0.0:
	set(v):
		cover = v
		if _screen:
			_screen.queue_redraw()
var _on := false
var _at := Vector2.ZERO
var _dir := Vector2.UP
var _rail := Vector2.INF
var _text := ""
var _feel: ZoneHopFeel
var _t := 0.0
var _screen: ScreenPart


func _ready() -> void:
	z_index = 50
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var layer := CanvasLayer.new()
	layer.layer = 5  # 전장 위·HUD(기본 1)보다 위: 넘어가는 동안 다 덮는다
	add_child(layer)
	_screen = ScreenPart.new()
	_screen.view = self
	layer.add_child(_screen)


## rail: 넘어가는 난간 자리 (있으면 꺾쇠를 그 자리에, 없으면 영웅에서 dir 쪽 arrow_dist).
func show_arrow(on: bool, at: Vector2, dir: Vector2, text: String, feel: ZoneHopFeel, rail: Vector2 = Vector2.INF) -> void:
	_on = on
	_at = at
	_rail = rail
	_dir = dir.normalized() if dir != Vector2.ZERO else Vector2.UP
	_text = text
	_feel = feel
	queue_redraw()


## 구역 이름을 secs초 띄운다.
func title(s: String, secs: float) -> void:
	_screen.title = s
	_screen.title_left = secs
	_screen.title_total = secs


func _process(delta: float) -> void:
	_t += delta
	if _on:
		queue_redraw()
	if _screen.title_left > 0.0:
		_screen.title_left = maxf(_screen.title_left - delta, 0.0)
		_screen.queue_redraw()


func _draw() -> void:
	if not _on or _feel == null:
		return
	var pulse := 0.5 + 0.5 * sin(_t * TAU * _feel.arrow_pulse)
	var tip := _at + _dir * (_feel.arrow_dist + 24.0 * pulse)  # 영웅 앞 길잡이 꺾쇠 (난간 쪽)
	var side := _dir.orthogonal()
	var s := _feel.arrow_size
	_chevrons(tip, _dir, side, s, pulse)
	if _rail != Vector2.INF:  # 뛰는 자리 = 난간 표시 (영웅이 여기로 달려가 뛴다)
		_chevrons(_rail + _dir * 24.0 * pulse, _dir, side, s * 1.15, pulse)
	if _text != "":  # 화살 끝 너머에 (영웅 머리 위 패·대사 글과 겹치지 않게)
		var f := UiStyle.BODY_FONT
		var px := _feel.text_px
		var w := f.get_string_size(_text, HORIZONTAL_ALIGNMENT_CENTER, -1, px).x
		var at := tip + _dir * (s * 0.6 + px * 0.5) + Vector2(-w * 0.5, px * 0.35)
		draw_string_outline(f, at, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 10, Color(UiStyle.INK, 0.9))
		draw_string(f, at, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, UiStyle.GOLD)


## 세 겹 꺾쇠 (먹 바탕 위 금빛), 앞으로 갈수록 진하게.
func _chevrons(tip: Vector2, dir: Vector2, side: Vector2, s: float, pulse: float) -> void:
	for k in 3:
		var c := tip - dir * (k * 0.9 * s)
		var a := (0.55 + 0.45 * pulse) * (1.0 - k * 0.25)
		var pts := PackedVector2Array([c, c - dir * s + side * s * 1.1, c - dir * s * 0.55, c - dir * s - side * s * 1.1])
		draw_colored_polygon(pts, Color(UiStyle.INK, a * 0.6))
		draw_polyline(PackedVector2Array([pts[1], pts[0], pts[3]]), Color(UiStyle.GOLD, a), s * 0.16)


## 화면 좌표 부분: 먹 덮기와 구역 이름.
class ScreenPart extends Control:
	var view: ZoneHopView
	var title := ""
	var title_left := 0.0
	var title_total := 1.0

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if view.cover > 0.0:
			var c: Color = view._feel.cover_color if view._feel else Color.BLACK
			draw_rect(r, Color(c, c.a * view.cover))
		if title_left > 0.0 and title != "":
			var a := clampf(minf(title_left / 0.4, (title_total - title_left) / 0.25 + 0.2), 0.0, 1.0)
			var f := UiStyle.TITLE_FONT
			var px := 64
			var w := f.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, px).x
			var at := Vector2((size.x - w) * 0.5, size.y * 0.24)  # 물결 알림 띠(가운데)보다 위
			draw_string_outline(f, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 10, Color(UiStyle.INK, 0.9 * a))
			draw_string(f, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(UiStyle.GOLD, a))
			UiStyle.gold_rule(self, Vector2(size.x * 0.5, at.y + 26.0), w * 0.6, a)
