class_name HeroSelect
extends Control
## 판 시작 전 영웅 고르기. 영웅마다 큰 칸(구운 스프라이트 정면 + 이름 + 한 줄 소개)을 세로로 쌓는다.
## 칸 위에서 눌렀다 같은 칸에서 떼면 선택 (오른엄지 한 손).

signal picked(hero: HeroData)

var heroes: Array[HeroData] = []
var _press_index: int = -1
var _press_slot: int = -1
var _t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func open(list: Array[HeroData]) -> void:
	heroes = list
	_press_index = -1
	_press_slot = -1
	show()
	queue_redraw()


func is_open() -> bool:
	return visible


func slot_rect(i: int) -> Rect2:
	var vp := size if size.x > 0.0 else get_viewport_rect().size
	var w := minf(vp.x - 48.0, 660.0)
	var h := 260.0
	var gap := 24.0
	var bottom := vp.y - 90.0
	var top := bottom - heroes.size() * h - (heroes.size() - 1) * gap
	return Rect2((vp.x - w) * 0.5, top + i * (h + gap), w, h)


func slot_at(pos: Vector2) -> int:
	for i in heroes.size():
		if slot_rect(i).has_point(pos):
			return i
	return -1


## 터치 처리 (테스트에서 직접 부른다). 고르면 true.
func handle_touch(index: int, pos: Vector2, pressed: bool) -> bool:
	if not visible:
		return false
	if pressed:
		_press_index = index
		_press_slot = slot_at(pos)
		return false
	if index != _press_index:
		return false
	var slot := slot_at(pos)
	var was := _press_slot
	_press_index = -1
	_press_slot = -1
	if slot < 0 or slot != was:
		return false
	hide()
	picked.emit(heroes[slot])
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
		handle_touch(1000, m.position, m.pressed)  # 마우스 (터치 에뮬레이션과 겹쳐도 마지막 누름만 기억)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var vp := size if size.x > 0.0 else get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(Ink.PAPER, 0.96))
	var font := get_theme_default_font()
	var top := slot_rect(0).position.y
	draw_string(font, Vector2(0, top - 60), "영웅을 고르세요", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 44, Ink.INK)
	for i in heroes.size():
		_draw_slot(font, i)


func _draw_slot(font: Font, i: int) -> void:
	var h := heroes[i]
	var r := slot_rect(i)
	var pressed := _press_slot == i
	draw_rect(r, Color(1, 1, 1, 0.35))
	draw_rect(Rect2(r.position, Vector2(12, r.size.y)), h.body_color)
	draw_rect(r, Color(Ink.INK, 0.9 if pressed else 0.5), false, 5.0 if pressed else 2.0)
	var portrait := Rect2(r.position + Vector2(24, 10), Vector2(r.size.y - 20, r.size.y - 20))
	var tex := _portrait(h)
	if tex:
		draw_texture_rect(tex, portrait, false)
	else:
		draw_circle(portrait.get_center(), portrait.size.x * 0.35, h.body_color)
	var tx := portrait.end.x + 16.0
	var tw := r.end.x - tx - 16.0
	draw_string(font, Vector2(tx, r.position.y + 90), h.display_name, HORIZONTAL_ALIGNMENT_LEFT, tw, 46, Ink.INK)
	var lines := h.tagline.split("\n")
	for li in mini(lines.size(), 3):
		draw_string(font, Vector2(tx, r.position.y + 140 + li * 32), lines[li], HORIZONTAL_ALIGNMENT_LEFT, tw, 24,
			Color(Ink.INK, 0.8))


## 구운 대기 동작에서 정면(방향 2) 한 장을 고른다 (프레임은 시간에 따라 바뀐다).
func _portrait(h: HeroData) -> Texture2D:
	var sheet := h.sprite_sheet
	if sheet == null or not sheet.has_anim("idle"):
		return null
	var i := sheet.anim_names.find("idle")
	var at := AtlasTexture.new()
	at.atlas = sheet.textures[i]
	var frame := int(_t * sheet.fps[i]) % maxi(sheet.frame_counts[i], 1)
	at.region = Rect2(frame * sheet.frame_size, 2 * sheet.frame_size, sheet.frame_size, sheet.frame_size)
	return at
