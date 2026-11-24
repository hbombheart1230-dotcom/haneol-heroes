class_name TitleScreen
extends Control
## 인트로(타이틀): 사용자 키아트(영문 로고 대신 붓글씨 한글 제목, tools/art/korean_title_art.py) + "입장" 단추. 앱을 켠 뒤 한 번만 (GameSettings.title_seen).

signal entered

const BG := preload("res://assets/ui/title_bg.png")
const DARK := Color(0.05, 0.04, 0.04)  # 그림 아래 어둠과 이어지는 빈자리 색

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


## 키아트(원본 그대로, 글자 없음): 가로를 화면에 맞추고 위쪽에 붙인다 (좌우 영웅이 잘리지 않게).
## 아래가 모자라면(긴 폰) 그림 아랫가장자리 띠를 늘여 잇고 아래로 갈수록 어둡게 — 제목·단추 자리.
## 가로로 넓은 화면(태블릿)은 높이를 맞추고 양옆을 어둡게 채운다. 스플래시(Keep)와 같은 위치.
func art_rect(vp: Vector2) -> Rect2:
	var ts := Vector2(BG.get_width(), BG.get_height())
	var s := ts * minf(vp.x / ts.x, vp.y / ts.y)
	return Rect2(Vector2((vp.x - s.x) * 0.5, 0.0), s)


func _draw_art(vp: Vector2) -> void:
	var r := art_rect(vp)
	var ts := Vector2(BG.get_width(), BG.get_height())
	if r.end.y < vp.y - 0.5:  # 아래 빈자리: 그림 끝 어둠과 같은 색으로 채운다
		draw_rect(Rect2(0, r.end.y - 1.0, vp.x, vp.y - r.end.y + 1.0), DARK)
	if r.position.x > 0.5:  # 가로로 넓은 화면 (태블릿): 양옆
		draw_rect(Rect2(0, 0, r.position.x, vp.y), Color(0.04, 0.035, 0.05))
		draw_rect(Rect2(r.end.x, 0, vp.x - r.end.x, vp.y), Color(0.04, 0.035, 0.05))
	draw_texture_rect(BG, r, false)
	if r.end.y < vp.y - 0.5:  # 그림 아래 12%를 점점 어둡게 → 빈자리와 이음매 없이 이어진다
		_fade(Rect2(0, r.end.y - r.size.y * 0.12, vp.x, r.size.y * 0.12 + 1.0), 1.0)


## 위는 투명, 아래로 갈수록 어둡게 (끝 불투명도 a).
func _fade(r: Rect2, a: float) -> void:
	var near := Color(DARK, 0.0)
	var far := Color(DARK, a)
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([near, near, far, far]))


## 붓글씨 제목 "한얼 영웅들" + 작은 글줄 + 붉은 낙관(한·얼). 화면 너비에 맞춰 키운다 (720px 너비 기준 1.0).
func _title_center_y(vp: Vector2) -> float:
	return minf(vp.y * 0.8, vp.y - 330.0 * vp.x / 720.0)


func _draw_title(vp: Vector2) -> void:
	var k := vp.x / 720.0
	var cy := _title_center_y(vp)
	UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(0.0, cy + 46.0 * k), "한얼 영웅들", int(132.0 * k), UiStyle.GOLD, vp.x)
	UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(0.0, cy + 100.0 * k), "역사의 전장에 선 네 영웅", int(34.0 * k), UiStyle.PAPER, vp.x)
	var sz := 70.0 * k  # 낙관
	var seal := Rect2(vp.x * 0.5 + 270.0 * k, cy - 40.0 * k, sz, sz)
	draw_rect(seal, Color(0.69, 0.12, 0.09))
	for i in 2:
		UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(seal.position.x, seal.position.y + sz * (0.44 + 0.42 * i)),
			"한얼".substr(i, 1), int(30.0 * k), Color(0.98, 0.92, 0.86), sz)


func _draw() -> void:
	if not visible:
		return
	var vp := _vp()
	_draw_art(vp)
	# 아래쪽 어둡게 (제목·단추가 잘 보이게): 제목 위부터 서서히
	var dy := _title_center_y(vp) - 200.0 * vp.x / 720.0
	_fade(Rect2(0, dy, vp.x, vp.y - dy), 0.88)
	_draw_title(vp)
	var r := button_rect()
	var pulse := 1.0 + sin(_t * 3.0) * 0.03
	var pr := Rect2(r.get_center() - r.size * pulse * 0.5, r.size * pulse)
	UiStyle.button(self, pr, "입장", 48, _press_index >= 0)
