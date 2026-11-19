class_name LevelUpPanel
extends Control
## 레벨업 선택 화면: 성장 카드 3장 중 하나를 고른다 (게임은 그동안 멈춘다).
## 한 손 오른엄지 기준으로 카드는 화면 아래쪽에 세로로 쌓는다.
## 이동하던 손가락으로 잘못 고르지 않게, 열린 뒤 input_delay가 지나고 새로 누른 터치만 받는다.
## 카드 위에서 눌렀다가 같은 카드 위에서 떼면 선택.

signal chosen(upgrade: UpgradeDef)

@export var input_delay: float = 0.35
## 마우스 입력에 쓰는 가상 터치 번호 (실제 터치 번호와 겹치지 않게).
const MOUSE_INDEX := 1000

var choices: Array[UpgradeDef] = []
var level: int = 1
## UpgradeDef.id → 이미 고른 횟수 (카드에 표시).
var stacks: Dictionary = {}

var _open_time: float = 0.0
var _press_index: int = -1
var _press_card: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func open(p_choices: Array[UpgradeDef], p_level: int, p_stacks: Dictionary) -> void:
	choices = p_choices
	level = p_level
	stacks = p_stacks
	_open_time = 0.0
	_press_index = -1
	_press_card = -1
	show()
	queue_redraw()


func is_open() -> bool:
	return visible


func _process(delta: float) -> void:
	if visible:
		_open_time += delta
		queue_redraw()


func card_rect(i: int) -> Rect2:
	var vp := size if size.x > 0.0 else get_viewport_rect().size
	var w := minf(vp.x - 48.0, 660.0)
	var h := 150.0
	var gap := 18.0
	var bottom := vp.y - 70.0
	var top := bottom - choices.size() * h - (choices.size() - 1) * gap
	return Rect2((vp.x - w) * 0.5, top + i * (h + gap), w, h)


## 화면 좌표의 카드 번호 (없으면 -1).
func card_at(pos: Vector2) -> int:
	for i in choices.size():
		if card_rect(i).has_point(pos):
			return i
	return -1


func accepts_input() -> bool:
	return visible and _open_time >= input_delay


## 터치 처리 (테스트에서 직접 부른다). 선택하면 true.
func handle_touch(index: int, pos: Vector2, pressed: bool) -> bool:
	if not accepts_input():
		return false
	if pressed:
		_press_index = index
		_press_card = card_at(pos)
		return false
	if index != _press_index:
		return false
	var card := card_at(pos)
	var was := _press_card
	_press_index = -1
	_press_card = -1
	if card < 0 or card != was:
		return false
	var u := choices[card]
	hide()
	chosen.emit(u)
	return true


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		handle_touch(t.index, t.position, t.pressed)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		# 마우스를 터치로 바꾸는 설정이 꺼져 있거나 바뀌지 않는 환경(데스크톱 도구) 대비.
		# 둘 다 오면 마지막에 누른 쪽만 기억하므로 두 번 고르지 않는 것이다.
		var m := event as InputEventMouseButton
		handle_touch(MOUSE_INDEX, m.position, m.pressed)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if not visible:
		return
	var vp := size if size.x > 0.0 else get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(Ink.INK, 0.55))
	var font := get_theme_default_font()
	var top := card_rect(0).position.y
	_text(font, Vector2(0, top - 70), "레벨 %d" % level, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 46, Ink.PAPER)
	_text(font, Vector2(0, top - 28), "하나를 고르세요", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 24, Color(Ink.PAPER, 0.8))
	var ready := accepts_input()
	for i in choices.size():
		_draw_card(font, i, ready)


func _draw_card(font: Font, i: int, ready: bool) -> void:
	var u := choices[i]
	var r := card_rect(i)
	var pressed := _press_card == i
	draw_rect(r, Color(Ink.PAPER, 0.97 if ready else 0.75))
	draw_rect(Rect2(r.position, Vector2(10, r.size.y)), u.color)
	draw_rect(r, Color(Ink.INK, 0.9 if pressed else 0.5), false, 4.0 if pressed else 2.0)
	var icon_c := r.position + Vector2(78, r.size.y * 0.5)
	if u.icon:
		var s := 104.0
		draw_texture_rect(u.icon, Rect2(icon_c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
	else:  # 아이콘이 없으면 색 원 + 제목 첫 글자
		draw_circle(icon_c, 46.0, u.color)
		_text(font, icon_c + Vector2(-46, 15), u.title.left(1), HORIZONTAL_ALIGNMENT_CENTER, 92, 42, Ink.PAPER)
	var tx := r.position.x + 146.0
	var tw := r.size.x - 160.0
	_text(font, Vector2(tx, r.position.y + 46), u.title, HORIZONTAL_ALIGNMENT_LEFT, tw, 30, Ink.INK)
	var lines := u.description.split("\n")
	for li in mini(lines.size(), 3):
		_text(font, Vector2(tx, r.position.y + 82 + li * 28), lines[li], HORIZONTAL_ALIGNMENT_LEFT, tw, 22,
			Color(Ink.INK, 0.8))
	var have := int(stacks.get(u.id, 0))
	var pips := "●".repeat(have) + "○".repeat(maxi(u.max_stacks - have, 0))
	_text(font, Vector2(r.position.x, r.position.y + 40), pips, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 18, 20,
		Color(Ink.SEAL, 0.9))


func _text(font: Font, pos: Vector2, text: String, align: HorizontalAlignment, width: float, px: int, col: Color) -> void:
	draw_string(font, pos, text, align, width, px, col)
