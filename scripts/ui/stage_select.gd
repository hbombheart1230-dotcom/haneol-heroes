class_name StageSelect
extends Control
## 무대 고르기 (영웅 고르기 다음): 옻칠 판에 무대 카드 2×2 (연도 · 전장 이름 · 대표 소품 · 주인공).
## 카드 위에서 눌렀다 같은 카드에서 떼면 선택. 잠긴 무대는 "앞 무대를 이기면 열림".

signal picked(stage: StageTheme)

var stages: Array[StageTheme] = []
## 무대별 열림 (비면 전부 열림). StageUnlock.flags가 만든다.
var unlocked: Array[bool] = []
var notice: String = ""
var _notice_left: float = 0.0
var _press_index: int = -1
var _press_slot: int = -1
var _t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func open(list: Array[StageTheme], open_flags: Array[bool] = []) -> void:
	stages = list
	unlocked = open_flags
	notice = ""
	_notice_left = 0.0
	_press_index = -1
	_press_slot = -1
	show()
	queue_redraw()


func is_open() -> bool:
	return visible


func _vp() -> Vector2:
	return size if size.x > 0.0 else get_viewport_rect().size


func slot_rect(i: int) -> Rect2:
	var vp := _vp()
	var gap := 18.0
	var w := minf((vp.x - 48.0 - gap) * 0.5, 330.0)
	var h := w * 1.25
	var rows := ceili(stages.size() / 2.0)
	var top := vp.y - 70.0 - rows * h - (rows - 1) * gap
	var x0 := (vp.x - (w * 2 + gap)) * 0.5
	return Rect2(x0 + (i % 2) * (w + gap), top + (i / 2) * (h + gap), w, h)


func is_unlocked(i: int) -> bool:
	return i >= unlocked.size() or unlocked[i]


func slot_at(pos: Vector2) -> int:
	for i in stages.size():
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
	if not is_unlocked(slot):
		notice = "%s에서 이기면 열립니다" % stages[slot - 1].title if slot > 0 else "잠김"
		_notice_left = 1.8
		return false
	hide()
	picked.emit(stages[slot])
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
		_notice_left = maxf(_notice_left - delta, 0.0)
		queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var vp := _vp()
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.04, 0.04, 1.0))
	var top := slot_rect(0).position.y
	UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(0, top - 78), "전장을 고르세요", 64, UiStyle.GOLD, vp.x)
	UiStyle.gold_rule(self, Vector2(vp.x * 0.5, top - 52), vp.x * 0.3)
	for i in stages.size():
		_draw_card(i)
	if _notice_left > 0.0:
		var a := clampf(_notice_left, 0.0, 1.0)
		UiStyle.text(self, UiStyle.BODY_FONT, Vector2(0, vp.y - 30), notice, 26, Color(UiStyle.PAPER, a), vp.x)


func _draw_card(i: int) -> void:
	var st := stages[i]
	var r := slot_rect(i)
	var open := is_unlocked(i)
	UiStyle.panel(self, r, UiStyle.LACQUER_RED if _press_slot == i and open else UiStyle.LACQUER,
		UiStyle.GOLD if open else UiStyle.GOLD_DIM)
	var paper := r.grow(-14.0)
	paper.size.y -= 96.0
	draw_rect(paper, st.floor_base)
	if st.card_art:
		var ts := st.card_art.get_size()
		var k := minf(paper.size.x / ts.x, paper.size.y / ts.y) * 0.9
		var ds := ts * k
		var bob := sin(_t * 1.4 + i) * 2.0
		draw_texture_rect(st.card_art, Rect2(paper.get_center() - ds * 0.5 + Vector2(0, bob), ds), false)
	if not open:  # 먹으로 덮고 자물쇠 글
		draw_rect(paper, Color(0.05, 0.04, 0.04, 0.84))
		UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(paper.position.x, paper.get_center().y + 16), "잠김", 48,
			UiStyle.GOLD_DIM, paper.size.x)
	draw_rect(paper, Color(UiStyle.GOLD, 0.6), false, 1.5)
	var y := r.end.y - 72.0
	UiStyle.text(self, UiStyle.BODY_FONT, Vector2(r.position.x, y - 8), st.year_label, 20, Color(UiStyle.PAPER, 0.8), r.size.x,
		Color(0, 0, 0, 0.6), 3)
	UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(r.position.x, y + 28), st.title, 42, UiStyle.GOLD, r.size.x)
	if st.hero_hint != "":
		UiStyle.text(self, UiStyle.BODY_FONT, Vector2(r.position.x, y + 54), "주인공 · " + st.hero_hint, 18,
			Color(UiStyle.PAPER, 0.7), r.size.x, Color(0, 0, 0, 0.6), 3)
