class_name CreditsScreen
extends Control
## "만든 이들" (설정 화면 아래 단추로 연다): 출처 표시 의무(공공누리)·함께 넣은 소프트웨어 라이선스·감사 표기·Godot 엔진 고지.
## 문구는 데이터(CreditsData, data/credits/credits.tres). 엔진과 엔진이 끼고 오는 제3자 라이브러리 고지는
## Godot 문서 "Complying with licenses"대로 엔진에서 읽는다 (get_license_text·get_copyright_info·get_license_info).
## 긴 글은 위아래로 끌어 넘긴다. 설정 화면의 자식이라 열려 있는 동안 설정 화면은 입력을 받지 않는다.

signal closed

const HEAD_PX := 30
const BODY_PX := 22
const LICENSE_PX := 15
const TOP := 170.0
const BOTTOM := 150.0

var data: CreditsData
var scroll: ScrollContainer
var _box: VBoxContainer
var _press_index := -1
var _dragged := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	hide()


func open() -> void:
	if visible:
		return
	if _box == null:
		_build()
	_layout()
	scroll.scroll_vertical = 0
	_press_index = -1
	show()
	queue_redraw()


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func is_open() -> bool:
	return visible


func _vp() -> Vector2:
	return size if size.x > 0.0 else get_viewport_rect().size


func close_rect() -> Rect2:
	var vp := _vp()
	return Rect2(vp.x * 0.5 - 130.0, vp.y - 124.0, 260.0, 90.0)


func scroll_rect() -> Rect2:
	var vp := _vp()
	return Rect2(40.0, TOP, vp.x - 80.0, vp.y - TOP - BOTTOM)


## 화면에 나오는 글 전체 (시험용: 의무 항목이 다 들어 있는지).
func all_text() -> String:
	if _box == null:
		_build()
	var parts := PackedStringArray()
	for c in _box.get_children():
		if c is Label:
			parts.append((c as Label).text)
	return "\n".join(parts)


func _build() -> void:
	if data == null:
		data = CreditsData.load_default()
	scroll = ScrollContainer.new()
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 끌기는 _input에서 직접 (터치·마우스 같게)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	scroll.add_child(_box)
	_head("출처 표시")
	for s in data.required:
		_line(s, BODY_PX, UiStyle.PAPER)
	_head("함께 쓴 소프트웨어")
	for s in data.licenses:
		_line(s, LICENSE_PX, Color(UiStyle.PAPER, 0.85), true)
	_head("Godot Engine")
	_line(engine_notice(), LICENSE_PX, Color(UiStyle.PAPER, 0.85), true)
	_head("고마운 자료")
	for s in data.thanks:
		_line(s, BODY_PX, Color(UiStyle.PAPER, 0.8))


## 엔진 고지: MIT 본문, 엔진 안 제3자 구성 요소의 저작권 줄, 그 라이선스 본문 (모두 엔진이 주는 원문).
static func engine_notice() -> String:
	var out := "This game uses Godot Engine, available under the following license:\n\n" + Engine.get_license_text()
	out += "\n\nPortions of this software are copyright © %s The FreeType Project (www.freetype.org). All rights reserved." \
		% freetype_years()
	out += "\n\nThird-party components:"
	for comp in Engine.get_copyright_info():
		out += "\n\n" + str(comp["name"])
		for part in comp["parts"]:
			for line in part["copyright"]:
				out += "\n© " + str(line)
			out += "\nLicense: " + str(part["license"])
	var texts := Engine.get_license_info()
	for name in texts:
		out += "\n\n——— " + str(name) + " ———\n" + str(texts[name])
	return out


## FreeType 라이선스(FTL)가 요구하는 문구의 연도: 엔진의 FreeType 저작권 줄 앞 연도 (예: "1996-2024").
static func freetype_years() -> String:
	var re := RegEx.create_from_string("^\\d{4}(-\\d{4})?")
	for comp in Engine.get_copyright_info():
		if str(comp["name"]).to_lower().contains("freetype"):
			for part in comp["parts"]:
				for line in part["copyright"]:
					var m := re.search(str(line))
					if m:
						return m.get_string()
	return ""


func _head(t: String) -> void:
	var l := _label(t, HEAD_PX, UiStyle.GOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _line(t: String, px: int, col: Color, latin := false) -> void:
	_label(t, px, col, latin)


func _label(t: String, px: int, col: Color, latin := false) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not latin:  # 우리말 줄은 게임 글꼴, 영문 허가문은 엔진 기본 글꼴 (기호·로마자가 다 있음)
		l.add_theme_font_override("font", UiStyle.BODY_FONT)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(l)
	return l


func _layout() -> void:
	var r := scroll_rect()
	scroll.position = r.position
	scroll.size = r.size
	_box.custom_minimum_size.x = r.size.x - 16.0


## 위아래로 넘기기 (끌거나 바퀴).
func scroll_by(dy: float) -> void:
	scroll.scroll_vertical = int(scroll.scroll_vertical - dy)


## 누름 처리 (시험에서 직접 부른다). 닫기 단추에서 누르고 뗐으면 닫는다 (끌어 넘긴 뒤 뗀 것은 닫지 않음).
func handle_touch(index: int, pos: Vector2, pressed: bool) -> void:
	if pressed:
		if _press_index == -1:
			_press_index = index
			_dragged = 0.0
		return
	if index != _press_index:
		return
	_press_index = -1
	if _dragged < 20.0 and close_rect().has_point(pos):
		close()


func handle_drag(index: int, rel: Vector2) -> void:
	if index == _press_index:
		_dragged += absf(rel.y)
		scroll_by(rel.y)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var vp := get_viewport()
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		handle_touch(t.index, t.position, t.pressed)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		handle_drag(d.index, d.relative)
	elif event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.button_index == MOUSE_BUTTON_LEFT:
			handle_touch(1000, m.position, m.pressed)
		elif m.pressed and m.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			scroll_by(60.0 if m.button_index == MOUSE_BUTTON_WHEEL_UP else -60.0)
	elif event is InputEventMouseMotion:
		handle_drag(1000, (event as InputEventMouseMotion).relative)
	if vp:
		vp.set_input_as_handled()


func _draw() -> void:
	if not visible:
		return
	var vp := _vp()
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.04, 0.04, 0.97))
	UiStyle.panel(self, Rect2(20, 40, vp.x - 40, vp.y - 60), UiStyle.LACQUER, UiStyle.GOLD)
	UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(0, 120), "만든 이들", 60, UiStyle.GOLD, vp.x)
	UiStyle.gold_rule(self, Vector2(vp.x * 0.5, 146), vp.x * 0.3)
	UiStyle.button(self, close_rect(), "닫기", 40, _press_index != -1 and _dragged < 20.0)
