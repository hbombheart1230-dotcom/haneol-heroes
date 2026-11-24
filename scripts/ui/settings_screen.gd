class_name SettingsScreen
extends Control
## 설정 화면 (톱니 단추로 연다): 효과음·음악 크기(밀대), 타격 진동·이야기·스킬 단추(켬/끔), 닫기, 전장 나가기(판 중)·끝내기(판 전).
## 바뀌면 바로 저장하고 changed를 알린다. 열려 있는 동안 게임은 멈춘다 (닫으면 원래대로).
## 나가기는 한 번 더 묻고 exit_confirmed(exit_mode)를 알린다. 무엇을 할지는 StartFlow가 정한다
## (판 중: 전장 목록으로, 첫 화면·이야기·영웅·전장 고르기: 앱 끝내기). opened 때 exit_mode를 정해 둔다.

signal changed
signal closed
signal opened
signal exit_confirmed(mode: StringName)

const ROWS: Array[StringName] = [&"sfx", &"music", &"vocals", &"haptics", &"story", &"skill_button", &"enemy_hp", &"combo_text", &"stats", &"tutorial"]
const LABELS := {&"sfx": "효과음", &"music": "음악", &"vocals": "노랫소리", &"haptics": "타격 진동", &"story": "이야기",
	&"skill_button": "기술 단추", &"enemy_hp": "적 체력", &"combo_text": "연타 글씨", &"stats": "개발 수치", &"tutorial": "조작 안내"}
const ROW_STEP := 92.0
const SLIDERS: Array[StringName] = [&"sfx", &"music"]
## 나가기 방식별 [단추 글, 확인 물음 두 줄].
const EXIT_TEXT := {&"title": ["전장 나가기", "이 전장을 그만두고", "전장 목록으로 돌아갈까요?"],
	&"quit": ["끝내기", "끝낼까요?", ""]}

## &"title"(전장 목록으로 — 이름은 옛 그대로) 또는 &"quit"(앱 끄기).
var exit_mode: StringName = &"title"

var _was_paused := false
var _drag_row: StringName = &""
var _press_index := -1
## 나가기를 한 번 누르고 확인을 기다리는 중.
var _confirming := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func open() -> void:
	if visible:
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	_drag_row = &""
	_press_index = -1
	_confirming = false
	show()
	opened.emit()
	queue_redraw()


func close() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = _was_paused
	closed.emit()


func is_open() -> bool:
	return visible


func _vp() -> Vector2:
	return size if size.x > 0.0 else get_viewport_rect().size


func panel_rect() -> Rect2:
	var vp := _vp()
	var w := minf(vp.x - 48.0, 620.0)
	var h := 150.0 + ROWS.size() * ROW_STEP + 130.0
	return Rect2((vp.x - w) * 0.5, (vp.y - h) * 0.5, w, h)


func row_rect(i: int) -> Rect2:
	var p := panel_rect()
	return Rect2(p.position.x + 32.0, p.position.y + 150.0 + i * ROW_STEP, p.size.x - 64.0, ROW_STEP - 12.0)


## 밀대가 놓인 줄 영역 (줄 오른쪽 60%).
func slider_rect(i: int) -> Rect2:
	var r := row_rect(i)
	return Rect2(r.position.x + r.size.x * 0.36, r.position.y + 24.0, r.size.x * 0.6, 28.0)


func toggle_rect(i: int) -> Rect2:
	var r := row_rect(i)
	return Rect2(r.end.x - 170.0, r.position.y + 8.0, 170.0, 62.0)


func close_rect() -> Rect2:
	var p := panel_rect()
	return Rect2(p.get_center().x - 260.0, p.end.y - 126.0, 250.0, 80.0)  # 아래 출처 두 줄 자리


func exit_rect() -> Rect2:
	var c := close_rect()
	return Rect2(c.end.x + 20.0, c.position.y, c.size.x, c.size.y)


## 나가기 확인 상자와 그 안의 [전장 나가기 또는 끝내기]·[취소] (확인 중에는 줄 대신 이것만 받는다).
func confirm_rect() -> Rect2:
	var p := panel_rect()
	return Rect2(p.position.x + 32.0, p.get_center().y - 170.0, p.size.x - 64.0, 300.0)


func confirm_yes_rect() -> Rect2:
	var b := confirm_rect()
	return Rect2(b.get_center().x - 250.0, b.end.y - 110.0, 240.0, 80.0)


func confirm_no_rect() -> Rect2:
	var y := confirm_yes_rect()
	return Rect2(y.end.x + 20.0, y.position.y, y.size.x, y.size.y)


func is_confirming() -> bool:
	return visible and _confirming


func _exit_text(i: int) -> String:
	return EXIT_TEXT.get(exit_mode, EXIT_TEXT[&"title"])[i]


func value_of(row: StringName) -> Variant:
	match row:
		&"sfx": return GameSettings.sfx_volume
		&"music": return GameSettings.music_volume
		&"vocals": return GameSettings.vocals_enabled
		&"haptics": return GameSettings.haptics_enabled
		&"story": return GameSettings.story_enabled
		&"skill_button": return GameSettings.skill_button_enabled
		&"enemy_hp": return GameSettings.enemy_hp_bars
		&"combo_text": return GameSettings.combo_text
		&"stats": return GameSettings.show_stats
		&"tutorial": return GameSettings.tutorial_enabled  # 켬(처음 값) = 앱을 켤 때마다 첫 판에 안내
	return null


func set_value(row: StringName, v: Variant) -> void:
	match row:
		&"sfx": GameSettings.sfx_volume = clampf(float(v), 0.0, 1.0)
		&"music": GameSettings.music_volume = clampf(float(v), 0.0, 1.0)
		&"vocals": GameSettings.vocals_enabled = bool(v)
		&"haptics":
			GameSettings.haptics_enabled = bool(v)
			Haptics.pulse(60, 0.7)  # 켜면 바로 한 번 떨려서 알려 준다
		&"story": GameSettings.story_enabled = bool(v)
		&"skill_button": GameSettings.skill_button_enabled = bool(v)
		&"enemy_hp": GameSettings.enemy_hp_bars = bool(v)
		&"combo_text": GameSettings.combo_text = bool(v)
		&"stats": GameSettings.show_stats = bool(v)
		&"tutorial":
			GameSettings.tutorial_enabled = bool(v)
			if bool(v):
				GameSettings.tutorial_done = false  # 다시 켜면 다음 판에 바로
	GameSettings.apply_audio()
	GameSettings.save_settings()
	changed.emit()
	queue_redraw()


## 누름 처리 (테스트에서 직접 부른다).
func handle_touch(index: int, pos: Vector2, pressed: bool) -> void:
	if not visible:
		return
	if pressed:
		if _press_index != -1:
			return
		_press_index = index
		if _confirming:
			return
		for i in ROWS.size():
			if SLIDERS.has(ROWS[i]) and slider_rect(i).grow_individual(20, 30, 20, 30).has_point(pos):
				_drag_row = ROWS[i]
				_slide(i, pos)
		return
	if index != _press_index:
		return
	_press_index = -1
	if _drag_row != &"":
		_drag_row = &""
		return
	if _confirming:
		if confirm_yes_rect().has_point(pos):
			_confirming = false
			close()
			exit_confirmed.emit(exit_mode)
		elif confirm_no_rect().has_point(pos) or not confirm_rect().has_point(pos):
			_confirming = false
			queue_redraw()
		return
	if exit_rect().has_point(pos):
		_confirming = true
		queue_redraw()
		return
	if close_rect().has_point(pos) or not panel_rect().has_point(pos):
		close()
		return
	for i in ROWS.size():
		if not SLIDERS.has(ROWS[i]) and row_rect(i).has_point(pos):
			set_value(ROWS[i], not bool(value_of(ROWS[i])))


func handle_drag(index: int, pos: Vector2) -> void:
	if visible and index == _press_index and _drag_row != &"":
		_slide(ROWS.find(_drag_row), pos)


func _slide(i: int, pos: Vector2) -> void:
	var s := slider_rect(i)
	set_value(ROWS[i], snappedf(clampf((pos.x - s.position.x) / s.size.x, 0.0, 1.0), 0.05))


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		handle_touch(t.index, t.position, t.pressed)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		handle_drag(d.index, d.position)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var m := event as InputEventMouseButton
		handle_touch(1000, m.position, m.pressed)
	elif event is InputEventMouseMotion:
		handle_drag(1000, (event as InputEventMouseMotion).position)
	get_viewport().set_input_as_handled()


func _draw() -> void:
	if not visible:
		return
	var vp := _vp()
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.6))
	var p := panel_rect()
	UiStyle.panel(self, p, UiStyle.LACQUER, UiStyle.GOLD)
	UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(p.position.x, p.position.y + 92), "설정", 72, UiStyle.GOLD, p.size.x)
	UiStyle.gold_rule(self, Vector2(p.get_center().x, p.position.y + 118), p.size.x * 0.3)
	for i in ROWS.size():
		var row := ROWS[i]
		var r := row_rect(i)
		UiStyle.text(self, UiStyle.BODY_FONT, Vector2(r.position.x, r.position.y + 50), LABELS[row], 34, UiStyle.PAPER)
		if SLIDERS.has(row):
			_draw_slider(slider_rect(i), float(value_of(row)))
		else:
			var on := bool(value_of(row))
			var t := toggle_rect(i)
			UiStyle.panel(self, t, UiStyle.LACQUER_RED if on else UiStyle.LACQUER, UiStyle.GOLD if on else UiStyle.GOLD_DIM)
			UiStyle.text(self, UiStyle.BODY_FONT, t.position + Vector2(0, 44), "켬" if on else "끔", 32,
				UiStyle.GOLD if on else Color(UiStyle.PAPER, 0.6), t.size.x)
	UiStyle.button(self, close_rect(), "닫기", 40)
	UiStyle.button(self, exit_rect(), _exit_text(0), 40)
	for k in UiStyle.CREDITS.size():  # 출처 (공공누리)
		var y := p.end.y - 10.0 - (UiStyle.CREDITS.size() - 1 - k) * 20.0
		UiStyle.text(self, UiStyle.BODY_FONT, Vector2(p.position.x, y), UiStyle.CREDITS[k], 16,
			Color(UiStyle.PAPER, 0.5), p.size.x)
	if _confirming:
		_draw_confirm()


func _draw_confirm() -> void:
	draw_rect(panel_rect(), Color(0, 0, 0, 0.55))
	var b := confirm_rect()
	UiStyle.panel(self, b, UiStyle.LACQUER_RED, UiStyle.GOLD)
	var lines := [_exit_text(1), _exit_text(2)].filter(func(l: String) -> bool: return l != "")
	var y0 := b.position.y + (80.0 if lines.size() > 1 else 100.0)
	for i in lines.size():
		UiStyle.text(self, UiStyle.BODY_FONT, Vector2(b.position.x, y0 + i * 48.0), lines[i], 38, UiStyle.PAPER, b.size.x)
	UiStyle.button(self, confirm_yes_rect(), _exit_text(0), 38)
	UiStyle.button(self, confirm_no_rect(), "취소", 38)


func _draw_slider(s: Rect2, v: float) -> void:
	var mid := s.position.y + s.size.y * 0.5
	draw_line(Vector2(s.position.x, mid), Vector2(s.end.x, mid), Color(UiStyle.GOLD_DIM, 0.7), 6.0)
	draw_line(Vector2(s.position.x, mid), Vector2(s.position.x + s.size.x * v, mid), UiStyle.GOLD, 6.0)
	var knob := Vector2(s.position.x + s.size.x * v, mid)
	draw_circle(knob, 18.0, UiStyle.LACQUER_RED)
	draw_arc(knob, 18.0, 0.0, TAU, 24, UiStyle.GOLD, 3.0)
	UiStyle.text(self, UiStyle.BODY_FONT, Vector2(s.position.x, mid - 26), "%d" % roundi(v * 100.0), 22,
		Color(UiStyle.PAPER, 0.8), s.size.x)
