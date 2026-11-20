class_name StoryIntro
extends Control
## 입장 뒤 이야기 인트로: 장면 그림이 천천히 다가가고, 연도 붓글씨 아래로 글줄이 하나씩 떠오른다.
## 화면을 누르면 다음 장면, 오른쪽 위 "건너뛰기"는 끝까지. 내용은 IntroData (data/intro/story_intro.tres).

signal finished

@export var data: IntroData

var timeline: IntroTimeline
var t: float = 0.0
var _press_index: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func open(d: IntroData = null) -> void:
	if d:
		data = d
	var durs := PackedFloat32Array()
	for s in data.slides:
		durs.append(s.duration)
	timeline = IntroTimeline.new(durs, data.fade)
	t = 0.0
	_press_index = -1
	show()
	if data.music and Feedback.instance:
		Feedback.instance.play_music(data.music)


func is_open() -> bool:
	return visible


func _vp() -> Vector2:
	return size if size.x > 0.0 else get_viewport_rect().size


func skip_rect() -> Rect2:
	return Rect2(_vp().x - 190.0, 70.0, 170.0, 64.0)


func finish() -> void:
	if not visible:
		return
	hide()
	finished.emit()


## 누름 처리 (테스트에서 직접 부른다). 열린 뒤 0.4초는 받지 않는다.
func handle_touch(index: int, pos: Vector2, pressed: bool) -> void:
	if not visible or t < 0.4:
		return
	if pressed:
		_press_index = index
		return
	if index != _press_index:
		return
	_press_index = -1
	if skip_rect().grow(16.0).has_point(pos):
		finish()
	else:
		t = timeline.skip_target(t)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		handle_touch(e.index, e.position, e.pressed)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var m := event as InputEventMouseButton
		handle_touch(1000, m.position, m.pressed)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	if t >= timeline.total():
		finish()
		return
	queue_redraw()


## 세로로 부드럽게 어두워지는 띠 (꼭짓점 색 보간).
func _gradient(y0: float, y1: float, a0: float, a1: float, w: float) -> void:
	var c0 := Color(0, 0, 0, a0)
	var c1 := Color(0, 0, 0, a1)
	draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(w, y0), Vector2(w, y1), Vector2(0, y1)]),
		PackedColorArray([c0, c0, c1, c1]))


func _draw() -> void:
	if not visible or timeline == null:
		return
	var vp := _vp()
	draw_rect(Rect2(Vector2.ZERO, vp), Color.BLACK)
	var i := timeline.slide_at(t)
	if i >= data.slides.size():
		return
	var s := data.slides[i]
	var local := t - timeline.slide_start(i)
	var p := clampf(local / s.duration, 0.0, 1.0)
	if s.image:
		var ts := s.image.get_size()
		var k := maxf(vp.x / ts.x, vp.y / ts.y) * lerpf(s.zoom_from, s.zoom_to, p)
		var sz := ts * k
		draw_texture_rect(s.image, Rect2((vp - sz) * 0.5 + s.pan * vp * p, sz), false, s.tint)
	if s.lines.size() > 0:  # 아래쪽 먹빛 (글 잘 보이게)
		_gradient(vp.y * 0.48, vp.y, 0.0, 0.8, vp.x)
	if s.caption != "":
		_gradient(0.0, vp.y * 0.3, 0.6, 0.0, vp.x)
	if s.caption != "":
		var ca := clampf((local - data.fade * 0.5) / 1.0, 0.0, 1.0)
		UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(0, vp.y * 0.16), s.caption, 64, Color(UiStyle.GOLD, ca), vp.x)
		UiStyle.gold_rule(self, Vector2(vp.x * 0.5, vp.y * 0.16 + 26.0), vp.x * 0.22 * ca, ca)
	var n := s.lines.size()
	var y0 := vp.y * 0.66 - maxf(n - 3, 0) * 22.0
	for k in n:
		var a := timeline.line_alpha(i, k, n, local)
		if a <= 0.0:
			continue
		var rise := (1.0 - a) * 22.0
		UiStyle.text(self, UiStyle.BODY_FONT, Vector2(40, y0 + k * 52.0 + rise), s.lines[k], 32,
			Color(UiStyle.PAPER, a), vp.x - 80.0, Color(0, 0, 0, 0.85), 6)
	var b := timeline.black(i, local)
	if b > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, b))
	var sr := skip_rect()
	UiStyle.text(self, UiStyle.BODY_FONT, sr.position + Vector2(0, 42), "건너뛰기 ›", 28, Color(UiStyle.PAPER, 0.75), sr.size.x)
