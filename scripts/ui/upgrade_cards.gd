class_name UpgradeCards
extends Control
## 강화 고르기 카드 (화면 좌표): 가운데에 카드 셋 — 맨 위 종류 띠(우리말 한 낱말·종류 색), 그림, 기술 이름,
## 패 이름(붓글씨), 바뀌는 값 "지금 → 고른 뒤"(UpgradeReadout, 금색 숫자), 몇 단계인지. 큰 변형은 금 띠·금 테에 설명 한 줄.
## 카드를 눌렀다 떼면 고른다 (누른 카드와 뗀 카드가 같아야). 열린 직후 잠깐은 누름을 받지 않는다 (싸우다 잘못 누름 방지).
## 고르는 규칙·게임 멈춤은 SealChoice가 한다. 여기는 그리기와 누름만.

signal card_picked(index: int)

## 카드 크기와 사이, 열린 뒤 누름을 받기까지(실제 초).
@export var card_size: Vector2 = Vector2(212, 452)
@export var gap: float = 16.0
@export var input_delay: float = 0.35
## 뒤 판을 가리는 어둠 (0~1).
@export var dim: float = 0.8
## 종류 띠 높이, 글자 크기 (화면 px, 720 폭 기준).
@export var band_height: float = 50.0
@export var band_px: int = 30
@export var skill_px: int = 24
@export var name_px: int = 34
@export var value_label_px: int = 22
@export var value_px: int = 32
@export var desc_px: int = 24
@export var level_px: int = 22
## 줄 사이 (화면 px): 아이콘 아래, 같은 묶음 줄 사이, 값 하나 끝, 이름과 값 묶음 사이, 좌우 여백, 아래 여백, 단계 글 위.
## 글씨는 줄이지 않는다 — 값 줄이 많으면 패가 길어진다 (모든 패가 같은 높이, max_height_ratio × 화면 높이까지).
@export var icon_gap: float = 14.0
@export var row_gap: float = 6.0
@export var value_gap: float = 14.0
@export var block_gap: float = 8.0
@export var side_pad: float = 10.0
@export var bottom_pad: float = 14.0
@export var level_gap: float = 18.0
@export var max_height_ratio: float = 0.8

var choices: Array[UpgradeDef] = []
var major: bool = false
var stacks: Dictionary = {}
## 이번에 고르면 오르는 단계 수 (물결 모드는 한 번에 여러 단계).
var gain: int = 1
## 이번 판 수치 (값 "지금 → 뒤" 계산). 없으면 패 설명 글.
var build: RunBuild
var _age: float = 0.0
var _height: float = 0.0
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
	_height = 0.0
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
	var h := card_height(w, vp)
	return Rect2(x0 + i * (w + gap), vp.y * 0.5 - h * 0.5, w, h)


## 패 높이: 기본 card_size.y, 글이 더 필요한 패가 있으면 셋 다 그만큼 (한 번 재고 기억).
func card_height(w: float, vp: Vector2) -> float:
	if _height <= 0.0:
		_height = card_size.y
		for u in choices:
			_height = maxf(_height, ceilf(UpgradeCardLayout.needed_height(self, u, w)))
		_height = minf(_height, vp.y * max_height_ratio)
	return _height


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
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, dim * k))
	var head := "큰 변형! 하나를 고르세요" if major else "강화를 하나 고르세요"
	var top := card_rect(0).position.y
	UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(0, top - 40), head, 46, Color(UiStyle.GOLD, k), vp.x,
		Color(0, 0, 0, 0.9 * k), 8)
	for i in choices.size():
		_draw_card(i, k)


## 이번에 고르면 실제로 오르는 단계 수.
func steps_of(u: UpgradeDef) -> int:
	return maxi(mini(gain, u.max_stacks - int(stacks.get(u.id, 0))), 1)


## 띠 낱말과 색.
func band_of(u: UpgradeDef) -> Array:
	var d := UpgradeReadout.data()
	if major:
		return [d.major_word, d.major_color]
	var kd := UpgradeReadout.kind(u)
	return [d.word(kd), d.color(kd)]


func _draw_card(i: int, k: float) -> void:
	var u := choices[i]
	var rise := (1.0 - k) * 60.0 * (1.0 + i * 0.3)
	var r := card_rect(i)
	r.position.y += rise
	var pressed := _press_card == i
	var band := band_of(u)
	var band_col: Color = band[1]
	var edge := UiStyle.GOLD if major else band_col.lightened(0.25)
	UiStyle.panel(self, r.grow(4.0 if pressed else 0.0), Color(UiStyle.LACQUER, 0.97 * k), Color(edge, k))
	var br := Rect2(r.position + Vector2(6, 6), Vector2(r.size.x - 12, band_height))
	draw_rect(br, Color(band_col, 0.95 * k))
	UiStyle.text(self, UiStyle.BODY_FONT, Vector2(br.position.x, br.position.y + band_height * 0.5 + band_px * 0.36),
		band[0], band_px, Color(1, 1, 1, k), br.size.x, Color(UiStyle.INK, 0.85 * k), 6)
	var ir := UpgradeCardLayout.icon_rect(self, r)
	var c := ir.get_center()
	var s := ir.size.x
	if u.icon:
		draw_texture_rect(u.icon, ir, false, Color(1, 1, 1, k))
	else:  # 그림이 없는 강화: 먹 인장에 이름 첫 글자
		var name_part := u.title.split(" · ")[-1]
		draw_circle(c, s * 0.42, Color(Ink.PAPER, k))
		draw_arc(c, s * 0.42, 0.0, TAU, 40, Color(u.color, k), 5.0)
		UiStyle.text(self, UiStyle.TITLE_FONT, c + Vector2(-s * 0.5, s * 0.17), name_part.left(1), int(s * 0.45),
			Color(u.color.darkened(0.3), k), s, Color(0, 0, 0, 0.0), 0)
	for it in UpgradeCardLayout.rows(self, u, r):
		var col: Color = it["color"]
		var big: bool = it["role"] in [UpgradeCardLayout.Role.NAME, UpgradeCardLayout.Role.VALUE]
		UiStyle.text(self, it["font"], it["pos"], it["text"], it["px"], Color(col, k), it["width"],
			Color(0, 0, 0, (0.9 if big else 0.8) * k), 6 if big else 5)


## 값 줄 "지금 → 뒤" (큰 변형·숫자로 못 읽는 패는 빈 목록 → 설명 글).
func values_of(u: UpgradeDef) -> Array[Dictionary]:
	if major:
		return []
	return UpgradeReadout.lines(u, build, steps_of(u))


## 패 맨 아래 단계 글 (한 단계뿐인 패는 빈 글).
func level_text(u: UpgradeDef) -> String:
	if u.max_stacks <= 1:
		return ""
	var have := int(stacks.get(u.id, 0))
	var to := mini(have + gain, u.max_stacks)
	return "%d단계 → %d단계" % [have, to] if have > 0 else ("새 강화" if to <= 1 else "새 강화 → %d단계" % to)
