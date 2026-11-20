class_name TitleScreen
extends Control
## 인트로(타이틀): 사용자 키아트(영문 로고 대신 붓글씨 한글 제목, tools/art/korean_title_art.py) + "입장" 단추. 앱을 켠 뒤 한 번만 (GameSettings.title_seen).

signal entered

const BG := preload("res://assets/ui/title_bg.png")

var _t: float = 0.0
var _press_index: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func open() -> void:
	_t = 0.0
	_press_index = -1
	show()


func is_open() -> bool:
	return visible


func _vp() -> Vector2:
	return size if size.x > 0.0 else get_viewport_rect().size


func button_rect() -> Rect2:
	var vp := _vp()
	return Rect2(vp.x * 0.5 - 150.0, vp.y - 140.0, 300.0, 92.0)  # 키아트 로고 아래


## 단추 위에서 눌렀다 떼면 입장. 열린 뒤 0.4초는 받지 않는다 (앱 켜는 손가락 오작동 방지).
func handle_touch(index: int, pos: Vector2, pressed: bool) -> bool:
	if not visible or _t < 0.4:
		return false
	if pressed:
		_press_index = index if button_rect().grow(20.0).has_point(pos) else -1
		return false
	if index != _press_index:
		return false
	_press_index = -1
	if not button_rect().grow(20.0).has_point(pos):
		return false
	hide()
	entered.emit()
	return true


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		handle_touch(t.index, t.position, t.pressed)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var m := event as InputEventMouseButton
		handle_touch(1000, m.position, m.pressed)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


## 키아트 전체가 보이게 맞춘다 (세로로 긴 폰에서 양옆 영웅 얼굴이 잘리지 않게).
## 남는 위아래는 그림 가장자리 띠를 늘여 잇고 바깥으로 갈수록 어둡게. 스플래시(Keep)와 같은 크기.
func art_rect(vp: Vector2) -> Rect2:
	var ts := Vector2(BG.get_width(), BG.get_height())
	var s := ts * minf(vp.x / ts.x, vp.y / ts.y)
	return Rect2((vp - s) * 0.5, s)


func _draw_art(vp: Vector2) -> void:
	var r := art_rect(vp)
	var ts := Vector2(BG.get_width(), BG.get_height())
	var edge := 6.0
	if r.position.y > 0.5:  # 위·아래 띠
		draw_texture_rect_region(BG, Rect2(r.position.x, 0, r.size.x, r.position.y + 1), Rect2(0, 0, ts.x, edge))
		draw_texture_rect_region(BG, Rect2(r.position.x, r.end.y - 1, r.size.x, vp.y - r.end.y + 1),
			Rect2(0, ts.y - edge, ts.x, edge))
		_fade(Rect2(0, 0, vp.x, r.position.y), true)
		_fade(Rect2(0, r.end.y, vp.x, vp.y - r.end.y), false)
	if r.position.x > 0.5:  # 가로로 넓은 화면 (태블릿): 양옆
		draw_rect(Rect2(0, 0, r.position.x, vp.y), Color(0.04, 0.035, 0.05))
		draw_rect(Rect2(r.end.x, 0, vp.x - r.end.x, vp.y), Color(0.04, 0.035, 0.05))
	draw_texture_rect(BG, r, false)


## 그림에서 멀어질수록 어둡게 (dark_at_top: 위쪽 띠는 맨 위가 가장 어둡다).
func _fade(r: Rect2, dark_at_top: bool) -> void:
	if r.size.y <= 0.0:
		return
	var far := Color(0.04, 0.035, 0.05, 0.95)
	var near := Color(0.04, 0.035, 0.05, 0.35)
	var top := far if dark_at_top else near
	var bottom := near if dark_at_top else far
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func _draw() -> void:
	if not visible:
		return
	var vp := _vp()
	_draw_art(vp)
	# 아래쪽 어둡게 (단추가 잘 보이게)
	for i in 12:
		var y := vp.y * (0.62 + i * 0.032)
		draw_rect(Rect2(0, y, vp.x, vp.y * 0.032 + 1.0), Color(0, 0, 0, 0.06 * i))
	var r := button_rect()
	var pulse := 1.0 + sin(_t * 3.0) * 0.03
	var pr := Rect2(r.get_center() - r.size * pulse * 0.5, r.size * pulse)
	UiStyle.button(self, pr, "입장", 48, _press_index >= 0)
