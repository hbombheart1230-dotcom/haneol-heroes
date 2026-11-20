class_name StoryIntro
extends Control
## 입장 뒤 이야기 인트로: 장면 그림이 천천히 다가가고, 연도 붓글씨 아래로 글줄이 하나씩 떠오른다.
## 아래 "다음 ›" (또는 화면 아무 곳)은 다음 장면, "건너뛰기"는 끝까지. 내용은 IntroData (data/intro/*.tres).

signal finished

@export var data: IntroData

var timeline: IntroTimeline
var t: float = 0.0
var _press_index: int = -1
var _press_on_skip := false


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


## 아래쪽 단추: 왼쪽 "건너뛰기", 오른쪽 "다음 ›" (마지막 장면은 "시작").
func skip_rect() -> Rect2:
	var vp := _vp()
	return Rect2(28.0, vp.y - 118.0, 220.0, 76.0)


func next_rect() -> Rect2:
	var vp := _vp()
	return Rect2(vp.x - 248.0, vp.y - 118.0, 220.0, 76.0)


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
		_press_on_skip = skip_rect().grow(16.0).has_point(pos)
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


## 붓으로 휘갈겨 쓰듯 한 줄을 그린다: progress(0~1)만큼 글자가 차례로 먹이 번지며 나타난다
## (막 쓰인 글자는 크게 찍혔다가 자리를 잡고, 아래에 먹 번짐이 잠깐 남는다).
const LINE_PX := 50


func _write_line(line: String, center_x: float, baseline: float, progress: float) -> void:
	var font: Font = UiStyle.TITLE_FONT
	var count := line.length()
	var total := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_PX).x
	var x := center_x - total * 0.5
	var reveal := progress * count
	for j in count:
		var ch := line.substr(j, 1)
		var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_PX).x
		var t := clampf(reveal - j, 0.0, 1.0)
		if t <= 0.0:
			break
		var mid := Vector2(x + w * 0.5, baseline - LINE_PX * 0.32)
		if t < 1.0 and ch != " ":  # 먹 번짐
			for ring in 4:  # 가운데가 진하고 바깥으로 옅어지는 먹
				draw_circle(mid, LINE_PX * (0.25 + 0.5 * t) * (1.0 - ring * 0.2), Color(0, 0, 0, 0.09 * (1.0 - t)))
		var k := lerpf(1.45, 1.0, ease(t, 0.4))
		draw_set_transform(mid, lerpf(-0.12, 0.0, t), Vector2(k, k))
		var p := Vector2(-w * 0.5, LINE_PX * 0.32)
		draw_string_outline(font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_PX, 7, Color(0, 0, 0, 0.8 * t))
		draw_string(font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_PX, Color(UiStyle.PAPER, t))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		x += w


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
	var y0 := vp.y * 0.64 - maxf(n - 3, 0) * 26.0
	for k in n:
		var a := timeline.line_alpha(i, k, n, local)
		if a > 0.0:
			_write_line(s.lines[k], vp.x * 0.5, y0 + k * 68.0, a)
	var b := timeline.black(i, local)
	if b > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, b))
	var last := i == data.slides.size() - 1
	UiStyle.button(self, skip_rect(), "건너뛰기", 32, _press_index >= 0 and _press_on_skip)
	UiStyle.button(self, next_rect(), "시작" if last else "다음 ›", 34, _press_index >= 0 and not _press_on_skip)
