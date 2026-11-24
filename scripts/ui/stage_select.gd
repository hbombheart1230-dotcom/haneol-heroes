class_name StageSelect
extends Control
## 전장 고르기 (영웅 고르기 다음, 판이 끝나면 다시 여기로): 위에 영웅 초상·이름과 "영웅 바꾸기",
## 가운데 그 영웅의 전장 패를 시간 순으로 (이김 · 출전 · 잠김 · 곧 열림), 아래 "원정" (만든 자기 전장을 다 이기면 열림).
## 원정: 다른 영웅의 전장 목록을 지금 영웅으로 (초상을 누르면 다음 영웅, "내 전장"으로 돌아옴).
## 한 손 세로: 누를 것(전장 패·원정)은 화면 아래쪽 2/3에. 상태는 CampaignProgress, 저장은 GameSettings.

signal stage_picked(id: StringName)
signal change_hero

const CARD_H := 206.0
const GAP := 22.0
const HEAD := Vector2(96, 140)  # 초상 중심
const HEAD_R := 64.0
const CHANGE_W := 220.0
## 원정 단추 아래 한 줄 글자 크기.
const SUB_PX := 18

## 판을 뛸 영웅 (지금 영웅).
var hero: HeroData
## 목록을 보여 주는 영웅 (원정이면 다른 영웅).
var view_hero: HeroData
var expedition: bool = false
## 원정에서 돌아볼 다른 영웅들.
var others: Array[HeroData] = []
var progress: CampaignProgress
var notice: String = ""
var _notice_left: float = 0.0
var _press_index: int = -1
var _press_what: int = -99  # 칸 번호, -1 영웅 바꾸기/내 전장, -2 원정, -3 초상(원정 다음 영웅)
var _t: float = 0.0
## 초상 원 (꼭짓점·UV): 한 번만 만든다 (매 프레임 다시 만들지 않게).
var _head_pts := PackedVector2Array()
var _head_uvs := PackedVector2Array()
var _growth: HeroGrowth


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func open(h: HeroData, p: CampaignProgress, all_heroes: Array[HeroData] = []) -> void:
	hero = h
	view_hero = h
	progress = p
	expedition = false
	others = []
	for o in all_heroes:
		if o and o != h and o.playable and o.campaign:
			others.append(o)
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
	return view_hero.campaign.slots.size() if view_hero and view_hero.campaign else 0


func state_of(i: int) -> CampaignProgress.State:
	return progress.expedition_state(hero, view_hero, i) if expedition else progress.state(hero, i)


## 처음 하는 사람 눈에 띄게: 아직 아무 전장도 못 이겼으면 열린 첫 전장 패가 빛난다.
func highlight(i: int) -> bool:
	return not expedition and i == 0 and state_of(0) == CampaignProgress.State.OPEN


func card_rect(i: int) -> Rect2:
	var vp := _vp()
	var n := maxi(slot_count(), 1)
	var top := vp.y - 190.0 - n * CARD_H - (n - 1) * GAP
	return Rect2(24, top + i * (CARD_H + GAP), vp.x - 48, CARD_H)


## 아래 줄 왼쪽 "영웅 바꾸기" (원정 보기에서는 "내 전장"). 한 손 엄지 자리, 오른쪽 위 톱니와 겹치지 않게.
func change_rect() -> Rect2:
	var vp := _vp()
	return Rect2(24, vp.y - 150, CHANGE_W, 96)


func head_rect() -> Rect2:
	return Rect2(HEAD - Vector2(HEAD_R + 8, HEAD_R + 8), Vector2(HEAD_R * 2 + 16 + 260, HEAD_R * 2 + 16))


func expedition_rect() -> Rect2:
	var vp := _vp()
	var x := 24.0 + CHANGE_W + 16.0
	return Rect2(x, vp.y - 150, vp.x - 24.0 - x, 96)


func what_at(pos: Vector2) -> int:
	for i in slot_count():
		if card_rect(i).has_point(pos):
			return i
	if change_rect().has_point(pos):
		return -1
	if expedition_rect().has_point(pos) and not expedition:
		return -2
	if expedition and head_rect().has_point(pos):
		return -3
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
	return press(w)


## 칸 w를 누름 (-1 영웅 바꾸기·내 전장, -2 원정, -3 원정 다음 영웅, 0.. 전장).
func press(w: int) -> bool:
	match w:
		-1:
			if expedition:
				set_expedition(false)
				return true
			hide()
			change_hero.emit()
			return true
		-2:
			if not progress.expedition_open(hero) or others.is_empty():
				_say(progress.expedition_reason(hero) if not progress.expedition_open(hero) else "다른 영웅이 없습니다")
				return false
			set_expedition(true)
			return true
		-3:
			view_hero = others[(others.find(view_hero) + 1) % others.size()]
			return true
	match state_of(w):
		CampaignProgress.State.LOCKED:
			_say("앞 전장을 이기면 열립니다")
			return false
		CampaignProgress.State.COMING:
			_say("곧 열립니다")
			return false
	hide()
	stage_picked.emit(view_hero.campaign.slots[w].id)
	return true


func set_expedition(on: bool) -> void:
	expedition = on and not others.is_empty()
	view_hero = others[0] if expedition else hero
	Feedback.ui()


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
	_draw_head()
	var top := card_rect(0).position.y
	UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(0, top - 62), "원정 · %s의 전장" % view_hero.display_name if expedition else "전장",
		60 if not expedition else 48, UiStyle.GOLD, vp.x)
	UiStyle.gold_rule(self, Vector2(vp.x * 0.5, top - 38), vp.x * 0.3)
	var hint := "%s, 다른 영웅의 전장에 나선다 · 초상을 누르면 다음 영웅" % hero.display_name if expedition \
		else "앞 전장을 이기면 다음 전장이 열린다"
	UiStyle.text(self, UiStyle.BODY_FONT, Vector2(0, top - 12), hint, 20, Color(UiStyle.PAPER, 0.7), vp.x, Color(0, 0, 0, 0.6), 3)
	for i in slot_count():
		var glow := 0.5 + 0.5 * sin(_t * 3.2) if highlight(i) else -1.0
		StageCardDrawer.draw(self, card_rect(i), view_hero, hero, progress, i, state_of(i), _press_what == i, glow)
	_draw_expedition()
	if _notice_left > 0.0:
		var a := clampf(_notice_left, 0.0, 1.0)
		UiStyle.text(self, UiStyle.BODY_FONT, Vector2(0, vp.y - 24), notice, 24, Color(UiStyle.PAPER, a), vp.x)


func _draw_head() -> void:
	var h := view_hero if expedition else hero
	draw_circle(HEAD, HEAD_R + 8.0, UiStyle.LACQUER)
	if h.portrait:
		if _head_pts.is_empty():
			_build_head()
		draw_circle(HEAD, HEAD_R, h.body_color.darkened(0.55))
		draw_polygon(_head_pts, PackedColorArray([Color.WHITE]), _head_uvs, h.portrait)
	draw_arc(HEAD, HEAD_R + 8.0, 0.0, TAU, 48, UiStyle.GOLD, 2.5)
	UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(184, 140), h.display_name, 58, UiStyle.GOLD, -1)
	var line := growth_line()
	if expedition:
		line = "▶ 다음 영웅의 전장"
	UiStyle.text(self, UiStyle.BODY_FONT, Vector2(188, 178), line, 22, Color(UiStyle.PAPER, 0.8), -1, Color(0, 0, 0, 0.6), 3)
	UiStyle.button(self, change_rect(), "내 전장" if expedition else "영웅 바꾸기", 30)


## 위 한 줄: "깬 전장 n · 영웅 성장 +x% · 기술 n단계 시작" (HeroGrowth, 깬 전장 목록에서).
func growth_line() -> String:
	if _growth == null:
		_growth = HeroGrowth.load_default()
	return _growth.line(HeroGrowth.points(GameSettings.hero_cleared, hero.id)) if hero else ""


func _build_head() -> void:
	for i in 40:
		var d := Vector2.from_angle(TAU * i / 40.0)
		_head_pts.append(HEAD + d * HEAD_R)
		_head_uvs.append(Vector2(0.5, 0.5) + d * 0.5)


## 잠긴 원정 단추 아래 한 줄 (왜 잠겼는지, 영웅 이름과 전장 이름).
func locked_line() -> String:
	return progress.expedition_reason(hero) if progress and not progress.expedition_open(hero) else "다른 영웅이 없습니다"


func _draw_expedition() -> void:
	if expedition:
		return
	var r := expedition_rect()
	var open := progress.expedition_open(hero) and not others.is_empty()
	UiStyle.panel(self, r, UiStyle.LACQUER_RED if _press_what == -2 else UiStyle.LACQUER,
		UiStyle.GOLD if open else UiStyle.GOLD_DIM)
	UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(r.position.x, r.position.y + 48), "원정", 40,
		UiStyle.GOLD if open else UiStyle.GOLD_DIM, r.size.x)
	var sub := "다른 영웅의 전장으로" if open else locked_line()
	UiStyle.text(self, UiStyle.BODY_FONT, Vector2(r.position.x, r.position.y + 80), sub, SUB_PX,
		Color(UiStyle.PAPER, 0.85 if open else 0.55), r.size.x, Color(0, 0, 0, 0.6), 3)
