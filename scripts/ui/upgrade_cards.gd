class_name UpgradeCards
extends Control
## 강화 고르기 카드 (화면 좌표): 가운데에 카드 셋 — 그림, 이름, 효과 한 줄, 몇 단계인지.
## 카드를 눌렀다 떼면 고른다 (누른 카드와 뗀 카드가 같아야). 열린 직후 잠깐은 누름을 받지 않는다 (싸우다 잘못 누름 방지).
## 고르는 규칙·게임 멈춤은 SealChoice가 한다. 여기는 그리기와 누름만.

signal card_picked(index: int)

## 카드 크기와 사이, 열린 뒤 누름을 받기까지(실제 초).
@export var card_size: Vector2 = Vector2(212, 340)
@export var gap: float = 16.0
@export var input_delay: float = 0.35

var choices: Array[UpgradeDef] = []
var major: bool = false
var stacks: Dictionary = {}
## 이번에 고르면 오르는 단계 수 (물결 모드는 한 번에 여러 단계).
var gain: int = 1
var _age: float = 0.0
var _press_index := -1
var _press_card := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	hide()


func open(p_choices: Array[UpgradeDef], p_major: bool, p_stacks: Dictionary, p_gain: int = 1) -> void:
	gain = maxi(p_gain, 1)
	choices = p_choices
	major = p_major
	stacks = p_stacks
	_age = 0.0
	_press_index = -1
	_press_card = -1
	show()
	queue_redraw()


func close() -> void:
	choices = []
	hide()


func _vp() -> Vector2:
	return size if size.x > 0.0 else get_viewport_rect().size


func card_rect(i: int) -> Rect2:
	var vp := _vp()
	var n := maxi(choices.size(), 1)
	var w := minf(card_size.x, (vp.x - 48.0 - gap * (n - 1)) / n)
	var total := w * n + gap * (n - 1)
	var x0 := (vp.x - total) * 0.5
	return Rect2(x0 + i * (w + gap), vp.y * 0.5 - card_size.y * 0.5, w, card_size.y)


func card_at(pos: Vector2) -> int:
	for i in choices.size():
		if card_rect(i).has_point(pos):
			return i
	return -1


func accepting() -> bool:
	return visible and not choices.is_empty() and _age >= input_delay


## 누름 처리 (테스트에서 직접 부른다). 카드 화면이 열려 있으면 모든 누름을 먹는다 (true).
func handle_touch(index: int, pos: Vector2, pressed: bool) -> bool:
	if not visible or choices.is_empty():
		return false
	if pressed:
		if accepting() and _press_index == -1:
			_press_index = index
			_press_card = card_at(pos)
			queue_redraw()
		return true
	if index != _press_index:
		return true
	var c := _press_card
	_press_index = -1
	_press_card = -1
	if c >= 0 and card_at(pos) == c:
		card_picked.emit(c)
	queue_redraw()
	return true


func step(real_delta: float) -> void:
	_age += real_delta


func _process(delta: float) -> void:
	if not visible:
		return
	# 늘 실제 시간으로 (멈춤 중에도 delta에는 Engine.time_scale이 곱해진다: 반격·마무리 느린 시간 직후 열리면
	# 페이드가 0.05배로 기어 패 셋이 흐린 채 판 위에 오래 남고 누름도 늦게 받았다)
	step(delta / maxf(Engine.time_scale, 0.001))
	queue_redraw()


func _input(event: InputEvent) -> void:
	var used := false
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		used = handle_touch(t.index, t.position, t.pressed)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var m := event as InputEventMouseButton
		used = handle_touch(1000, m.position, m.pressed)
	elif event is InputEventScreenDrag and visible and not choices.is_empty():
		used = true
	if used:
		get_viewport().set_input_as_handled()


## 긴 글을 폭에 맞게 줄을 나눈다 (띄어쓰기 기준, 최대 lines줄).
static func wrap_lines(font: Font, text: String, px: int, width: float, lines: int) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	for word in text.split(" "):
		var next := word if cur == "" else cur + " " + word
		if cur != "" and font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
			out.append(cur)
			cur = word
		else:
			cur = next
	if cur != "":
		out.append(cur)
	return out.slice(0, lines)


func _draw() -> void:
	if not visible or choices.is_empty():
		return
	var vp := _vp()
	var k := clampf(_age / 0.25, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.55 * k))
	var head := "큰 변형! 하나를 고르세요" if major else "강화를 하나 고르세요"
	var top := card_rect(0).position.y
	UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(0, top - 40), head, 46, Color(UiStyle.GOLD, k), vp.x,
		Color(0, 0, 0, 0.9 * k), 8)
	for i in choices.size():
		_draw_card(i, k)


func _draw_card(i: int, k: float) -> void:
	var u := choices[i]
	var rise := (1.0 - k) * 60.0 * (1.0 + i * 0.3)
	var r := card_rect(i)
	r.position.y += rise
	var pressed := _press_card == i
	var edge := UiStyle.GOLD if major else u.color.lightened(0.2)
	UiStyle.panel(self, r.grow(4.0 if pressed else 0.0), Color(UiStyle.LACQUER, 0.96 * k), Color(edge, k))
	draw_rect(Rect2(r.position + Vector2(6, 6), Vector2(r.size.x - 12, 10)), Color(edge, 0.85 * k))
	var c := Vector2(r.get_center().x, r.position.y + 100)
	var s := minf(r.size.x - 60.0, 130.0)
	if u.icon:
		draw_texture_rect(u.icon, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, k))
	else:  # 그림이 없는 강화: 먹 인장에 이름 첫 글자
		var name_part := u.title.split(" · ")[-1]
		draw_circle(c, s * 0.42, Color(Ink.PAPER, k))
		draw_arc(c, s * 0.42, 0.0, TAU, 40, Color(u.color, k), 5.0)
		UiStyle.text(self, UiStyle.TITLE_FONT, c + Vector2(-s * 0.5, s * 0.17), name_part.left(1), int(s * 0.45),
			Color(u.color.darkened(0.3), k), s, Color(0, 0, 0, 0.0), 0)
	var font := UiStyle.TITLE_FONT
	var y := r.position.y + 196.0
	var parts := u.title.split(" · ")
	if parts.size() > 1:  # "기술 · 강화 이름": 기술은 작게 위에, 강화 이름은 크게
		UiStyle.text(self, UiStyle.BODY_FONT, Vector2(r.position.x, y), parts[0], 20, Color(UiStyle.GOLD_DIM, k),
			r.size.x, Color(0, 0, 0, 0.7 * k), 4)
		y += 32.0
	for line in wrap_lines(font, parts[-1], 30, r.size.x - 20.0, 2):
		UiStyle.text(self, font, Vector2(r.position.x, y), line, 30, Color(UiStyle.GOLD, k), r.size.x, Color(0, 0, 0, 0.8 * k), 5)
		y += 34.0
	y += 6.0
	var desc := u.description.split("\n")[0]
	for line in wrap_lines(UiStyle.BODY_FONT, desc, 22, r.size.x - 24.0, 3):
		UiStyle.text(self, UiStyle.BODY_FONT, Vector2(r.position.x, y), line, 22, Color(UiStyle.PAPER, k), r.size.x,
			Color(0, 0, 0, 0.7 * k), 4)
		y += 27.0
	var have := int(stacks.get(u.id, 0))
	if u.max_stacks > 1:
		var to := mini(have + gain, u.max_stacks)
		var lv := "%d단계 → %d단계" % [have, to] if have > 0 else ("새 강화" if to <= 1 else "새 강화 → %d단계" % to)
		UiStyle.text(self, UiStyle.BODY_FONT, Vector2(r.position.x, r.end.y - 18), lv, 20,
			Color(UiStyle.GOLD_DIM if have > 0 else UiStyle.GOLD, k), r.size.x, Color(0, 0, 0, 0.7 * k), 4)
