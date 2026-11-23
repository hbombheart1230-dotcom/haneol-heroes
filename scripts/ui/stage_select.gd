class_name StageSelect
extends Control
## 전장 고르기 (영웅 고르기 다음, 판이 끝나면 다시 여기로): 위에 영웅 초상·이름과 "영웅 바꾸기",
## 가운데 그 영웅의 전장 패를 시간 순으로 (이김 · 열림 · 잠김 · 곧 열림), 아래 "원정" (자기 전장을 다 이기면 열림).
## 한 손 세로: 누를 것(전장 패·원정)은 화면 아래쪽 2/3에. 상태는 CampaignProgress, 저장은 GameSettings.hero_cleared.

signal stage_picked(id: StringName)
signal change_hero
signal expedition

const CARD_H := 206.0
const GAP := 22.0
const STATE_TEXT := ["이김", "출전", "잠김", "곧 열림"]

var hero: HeroData
var progress: CampaignProgress
var notice: String = ""
var _notice_left: float = 0.0
var _press_index: int = -1
var _press_what: int = -99  # 칸 번호, -1 영웅 바꾸기, -2 원정
var _t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func open(h: HeroData, p: CampaignProgress) -> void:
	hero = h
	progress = p
	_press_index = -1
	_press_what = -99
	notice = ""
	show()
	queue_redraw()


func is_open() -> bool:
	return visible


func _vp() -> Vector2:
	return size if size.x > 0.0 else get_viewport_rect().size


func slot_count() -> int:
	return hero.campaign.slots.size() if hero and hero.campaign else 0


func card_rect(i: int) -> Rect2:
	var vp := _vp()
	var n := maxi(slot_count(), 1)
	var top := vp.y - 190.0 - n * CARD_H - (n - 1) * GAP
	return Rect2(24, top + i * (CARD_H + GAP), vp.x - 48, CARD_H)


func change_rect() -> Rect2:
	return Rect2(_vp().x - 214, 64, 190, 64)


func expedition_rect() -> Rect2:
	var vp := _vp()
	return Rect2(24, vp.y - 150, vp.x - 48, 96)


func what_at(pos: Vector2) -> int:
	for i in slot_count():
		if card_rect(i).has_point(pos):
			return i
	if change_rect().has_point(pos):
		return -1
	if expedition_rect().has_point(pos):
		return -2
	return -99


## 터치 처리 (테스트에서 직접 부른다). 무언가 골랐으면 true.
func handle_touch(index: int, pos: Vector2, pressed: bool) -> bool:
	if not visible:
		return false
	if pressed:
		_press_index = index
		_press_what = what_at(pos)
		return false
	if index != _press_index:
		return false
	var w := what_at(pos)
	var was := _press_what
	_press_index = -1
	_press_what = -99
	if w != was or w == -99:
		return false
	if w == -1:
		hide()
		change_hero.emit()
		return true
	if w == -2:
		if not progress.expedition_open(hero):
			_say("자기 전장을 모두 이기면 원정이 열립니다")
			return false
		expedition.emit()
		return true
	match progress.state(hero, w):
		CampaignProgress.State.LOCKED:
			_say("앞 전장을 이기면 열립니다")
			return false
		CampaignProgress.State.COMING:
			_say("곧 열립니다")
			return false
	hide()
	stage_picked.emit(hero.campaign.slots[w].id)
	return true


func _say(text: String) -> void:
	notice = text
	_notice_left = 1.6


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
	if not visible or hero == null or progress == null:
		return
	var vp := _vp()
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.04, 0.04, 0.97))
	_draw_hero_head(vp)
	var top := card_rect(0).position.y
	UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(0, top - 62), "전장", 60, UiStyle.GOLD, vp.x)
	UiStyle.gold_rule(self, Vector2(vp.x * 0.5, top - 38), vp.x * 0.3)
	UiStyle.text(self, UiStyle.BODY_FONT, Vector2(0, top - 12), "앞 전장을 이기면 다음 전장이 열린다", 20,
		Color(UiStyle.PAPER, 0.7), vp.x, Color(0, 0, 0, 0.6), 3)
	for i in slot_count():
		StageCardDrawer.draw(self, card_rect(i), hero, progress, i, _press_what == i)
	_draw_expedition()
	if _notice_left > 0.0:
		var a := clampf(_notice_left, 0.0, 1.0)
		UiStyle.text(self, UiStyle.BODY_FONT, Vector2(0, vp.y - 24), notice, 24, Color(UiStyle.PAPER, a), vp.x)


func _draw_hero_head(vp: Vector2) -> void:
	var ctr := Vector2(96, 140)
	var r := 64.0
	draw_circle(ctr, r + 8.0, UiStyle.LACQUER)
	if hero.portrait:
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in 40:
			var d := Vector2.from_angle(TAU * i / 40.0)
			pts.append(ctr + d * r)
			uvs.append(Vector2(0.5, 0.5) + d * 0.5)
		draw_circle(ctr, r, hero.body_color.darkened(0.55))
		draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, hero.portrait)
	draw_arc(ctr, r + 8.0, 0.0, TAU, 48, UiStyle.GOLD, 2.5)
	UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(184, 140), hero.display_name, 58, UiStyle.GOLD, -1)
	var clears := int(GameSettings.hero_clears.get(String(hero.id), 0))
	UiStyle.text(self, UiStyle.BODY_FONT, Vector2(188, 178), "이긴 전장 %d" % clears, 22, Color(UiStyle.PAPER, 0.8), -1,
		Color(0, 0, 0, 0.6), 3)
	UiStyle.button(self, change_rect(), "영웅 바꾸기", 26)


func _draw_expedition() -> void:
	var r := expedition_rect()
	var open := progress.expedition_open(hero)
	UiStyle.panel(self, r, UiStyle.LACQUER_RED if _press_what == -2 else UiStyle.LACQUER,
		UiStyle.GOLD if open else UiStyle.GOLD_DIM)
	UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(r.position.x, r.position.y + 48), "원정", 40,
		UiStyle.GOLD if open else UiStyle.GOLD_DIM, r.size.x)
	var sub := "다른 영웅의 전장으로" if open else "자기 전장을 모두 이기면 열린다"
	UiStyle.text(self, UiStyle.BODY_FONT, Vector2(r.position.x, r.position.y + 80), sub, 20,
		Color(UiStyle.PAPER, 0.85 if open else 0.55), r.size.x, Color(0, 0, 0, 0.6), 3)
