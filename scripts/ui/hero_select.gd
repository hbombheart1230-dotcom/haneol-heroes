class_name HeroSelect
extends Control
## 판 시작 전 영웅 고르기 (하데스 참고): 옻칠 판에 영웅 전신 일러스트 카드 2×2.
## 카드 위에서 눌렀다 같은 카드에서 떼면 선택. 아직 못 쓰는 영웅(playable = false)은 "준비 중".

signal picked(hero: HeroData)

var heroes: Array[HeroData] = []
## 고를 수 없는 카드를 누르면 잠깐 띄우는 안내.
var notice: String = ""
var _notice_left: float = 0.0
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
	notice = ""
	show()
	queue_redraw()


func is_open() -> bool:
	return visible


func _vp() -> Vector2:
	return size if size.x > 0.0 else get_viewport_rect().size


## 카드 i의 영역 (2열, 아래쪽에 모아 오른엄지가 닿게).
func slot_rect(i: int) -> Rect2:
	var vp := _vp()
	var gap := 18.0
	var w := minf((vp.x - 48.0 - gap) * 0.5, 330.0)
	var h := w * 1.55
	var rows := ceili(heroes.size() / 2.0)
	var top := vp.y - 70.0 - rows * h - (rows - 1) * gap
	var x0 := (vp.x - (w * 2 + gap)) * 0.5
	return Rect2(x0 + (i % 2) * (w + gap), top + (i / 2) * (h + gap), w, h)


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
	var h := heroes[slot]
	if not h.playable:
		notice = "%s · 준비 중" % h.display_name
		_notice_left = 1.6
		return false
	hide()
	picked.emit(h)
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
		_notice_left = maxf(_notice_left - delta, 0.0)
		queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var vp := _vp()
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.04, 0.04, 0.97))
	var top := slot_rect(0).position.y
	UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(0, top - 78), "영웅을 고르세요", 64, UiStyle.GOLD, vp.x)
	UiStyle.gold_rule(self, Vector2(vp.x * 0.5, top - 52), vp.x * 0.3)
	for i in heroes.size():
		_draw_card(i)
	if _notice_left > 0.0:
		var a := clampf(_notice_left, 0.0, 1.0)
		UiStyle.text(self, UiStyle.BODY_FONT, Vector2(0, vp.y - 30), notice, 26, Color(UiStyle.PAPER, a), vp.x)


func _draw_card(i: int) -> void:
	var h := heroes[i]
	var r := slot_rect(i)
	var pressed := _press_slot == i
	UiStyle.panel(self, r, UiStyle.LACQUER_RED if pressed else UiStyle.LACQUER, UiStyle.GOLD if h.playable else UiStyle.GOLD_DIM)
	draw_rect(Rect2(r.position + Vector2(8, 8), Vector2(r.size.x - 16, 6)), h.body_color)
	if h.card_art:
		var inner := r.grow(-14.0)
		inner.size.y -= 74.0
		var tex_size := h.card_art.get_size()
		var k := minf(inner.size.x / tex_size.x, inner.size.y / tex_size.y)
		var bob := sin(_t * 1.6 + i) * 3.0 if h.playable else 0.0
		var draw_size := tex_size * k
		var at := Vector2(inner.get_center().x - draw_size.x * 0.5, inner.end.y - draw_size.y + bob)
		var tint := Color(1, 1, 1) if h.playable else Color(0.35, 0.33, 0.33)
		draw_texture_rect(h.card_art, Rect2(at, draw_size), false, tint)
	var name_y := r.end.y - 44.0
	UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(r.position.x, name_y), h.display_name, 46,
		UiStyle.GOLD if h.playable else UiStyle.GOLD_DIM, r.size.x)
	var tag := h.tagline.split("\n")[0] if h.playable else "준비 중"
	UiStyle.text(self, UiStyle.BODY_FONT, Vector2(r.position.x, name_y + 30), tag, 20, Color(UiStyle.PAPER, 0.85),
		r.size.x, Color(0, 0, 0, 0.6), 4)
