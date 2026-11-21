class_name TutorialOverlay
extends Control
## 조작 안내 띠: 화면 아래쪽에 붓글씨 제목·설명, 왼쪽에 손가락 동작 그림, 단계 점, 왼쪽 위 "건너뛰기".
## 게임 입력은 막지 않는다 (건너뛰기 단추만 받는다). 진행은 TutorialProgress.

signal skipped

var run: TutorialProgress
var _t: float = 0.0
var _finish_left: float = 0.0
var _press_index := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func open(p: TutorialProgress) -> void:
	run = p
	_t = 0.0
	_finish_left = 0.0
	run.finished.connect(func() -> void: _finish_left = 1.6, CONNECT_ONE_SHOT)
	show()


func is_open() -> bool:
	return visible


func _vp() -> Vector2:
	return size if size.x > 0.0 else get_viewport_rect().size


func banner_rect() -> Rect2:
	var vp := _vp()
	return Rect2(16.0, vp.y - 470.0, vp.x - 32.0, 210.0)  # 아래쪽 (위쪽은 무대 제목 자리)


func skip_rect() -> Rect2:
	return Rect2(16.0, 84.0, 180.0, 60.0)


func handle_touch(index: int, pos: Vector2, pressed: bool) -> bool:
	if not visible or run == null or run.is_done():
		return false
	if pressed:
		if skip_rect().grow(10.0).has_point(pos):
			_press_index = index
			return true
		return false
	if index != _press_index:
		return false
	_press_index = -1
	if skip_rect().grow(10.0).has_point(pos):
		run.skip()
		skipped.emit()
	return true


func _input(event: InputEvent) -> void:
	var used := false
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		used = handle_touch(e.index, e.position, e.pressed)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var m := event as InputEventMouseButton
		used = handle_touch(1000, m.position, m.pressed)
	if used:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if run and run.is_done():
		_finish_left -= delta
		if _finish_left <= 0.0:
			hide()
	queue_redraw()


func _draw() -> void:
	if run == null:
		return
	var b := banner_rect()
	if run.is_done():
		var a := clampf(_finish_left, 0.0, 1.0)
		UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(0, b.get_center().y + 30), run.data.finish_caption, 84,
			Color(UiStyle.GOLD, a), _vp().x)
		return
	var s := run.current()
	UiStyle.panel(self, b, Color(UiStyle.LACQUER, 0.82), UiStyle.GOLD)
	var text_x := b.position.x + 150.0
	var text_w := b.size.x - 170.0
	UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(text_x, b.position.y + 70), s.caption, 52, UiStyle.GOLD, text_w)
	var hint := s.button_hint if GameSettings.skill_button_enabled and s.button_hint != "" else s.hint
	var lines := hint.split("\n")
	for i in lines.size():
		UiStyle.text(self, UiStyle.BODY_FONT, Vector2(text_x, b.position.y + 116 + i * 34), lines[i], 24,
			UiStyle.PAPER, text_w)
	_draw_gesture(s.event, Vector2(b.position.x + 78.0, b.get_center().y))
	_draw_dots(b)
	UiStyle.button(self, skip_rect(), "건너뛰기", 30, _press_index != -1)


## 단계 점 (지난 단계 금색, 지금 단계는 진행률만큼 차오름).
func _draw_dots(b: Rect2) -> void:
	var n := run.data.steps.size()
	var gap := 22.0
	var x0 := b.get_center().x - (n - 1) * gap * 0.5 + 75.0
	for i in n:
		var c := Vector2(x0 + i * gap, b.end.y - 18.0)
		draw_circle(c, 6.0, Color(UiStyle.GOLD_DIM, 0.5))
		if i < run.index:
			draw_circle(c, 6.0, UiStyle.GOLD)
		elif i == run.index:
			draw_arc(c, 6.0, -PI * 0.5, -PI * 0.5 + TAU * run.ratio(), 16, UiStyle.GOLD, 3.0)


## 손가락 동작 그림: 끌기(좌우로 미끄러짐) · 튕기기(빠른 획) · 톡(퍼지는 원) · 꾹(차오르는 고리).
func _draw_gesture(event: StringName, c: Vector2) -> void:
	var finger := Color(UiStyle.PAPER, 0.9)
	var t := fmod(_t, 1.6) / 1.6
	match event:
		&"move":
			var x := sin(_t * 2.4) * 34.0
			draw_line(c + Vector2(-34, 0), c + Vector2(34, 0), Color(UiStyle.GOLD, 0.35), 4.0)
			draw_circle(c + Vector2(x, 0), 14.0, finger)
		&"dash", &"skill_dash":
			var p := ease(t, 0.3) * 70.0 - 35.0
			draw_line(c + Vector2(-35, 18), c + Vector2(p, 18 - (p + 35) * 0.6), Color(UiStyle.GOLD, 0.8 * (1.0 - t)), 6.0)
			draw_circle(c + Vector2(p, 18 - (p + 35) * 0.6), 12.0, finger)
			if event == &"skill_dash" and t > 0.6:
				draw_arc(c + Vector2(35, -24), 10.0 + (t - 0.6) * 60.0, 0.0, TAU, 24, Color(UiStyle.GOLD, 1.6 - t), 3.0)
		&"skill_tap":
			draw_circle(c, 12.0, finger)
			draw_arc(c, 14.0 + t * 30.0, 0.0, TAU, 24, Color(UiStyle.GOLD, 1.0 - t), 3.0)
		&"skill_charge":
			draw_circle(c, 12.0, finger)
			draw_arc(c, 26.0, -PI * 0.5, -PI * 0.5 + TAU * t, 32, UiStyle.GOLD, 5.0)
		&"upgrade":  # 카드 셋 중 가운데를 톡
			for k in 3:
				var cr := Rect2(c + Vector2(-46 + k * 32, -26), Vector2(26, 40))
				draw_rect(cr, Color(UiStyle.LACQUER, 0.9))
				draw_rect(cr, UiStyle.GOLD if k == 1 and t > 0.5 else Color(UiStyle.GOLD_DIM, 0.8), false, 2.0)
			draw_circle(c + Vector2(-7, 6), 9.0, finger)
			if t > 0.5:
				draw_arc(c + Vector2(-7, 6), 10.0 + (t - 0.5) * 30.0, 0.0, TAU, 20, Color(UiStyle.GOLD, 1.0 - t), 3.0)
		_:
			draw_circle(c, 16.0, Color(0.55, 0.85, 0.5, 0.5 + 0.3 * sin(_t * 4.0)))  # 탕약 빛
