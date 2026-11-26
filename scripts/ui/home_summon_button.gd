class_name HomeSummonButton
extends Control
## 주인 영웅 부르기 단추 (원정 전장에서만, HomeSummonData): 왼쪽 위 영웅 묶음 아래 둥근 초상 단추 (그 전장 주인 영웅 얼굴).
## 누르면 주인 영웅이 나타나 같이 싸운다 (AllyHero: 컷인 + 대사 HeroLines.Case.SUMMON + 부르기 기술 + 연타).
## 충전은 시간으로 (HomeSummonRules.tick): 테두리 고리가 차오르고, 다 차면 번쩍임·소리·한 줄 안내. 쓸 수 없으면 어둡게.
## 숨김: 판 중이 아님, 영웅 고르기, 패 고르기(BATTLE_TEXT), 조작 안내 중.

signal summoned(home: HeroData)

var main: Node
var rules := HomeSummonRules.new()
var data: HomeSummonData
var hint := ""
var _hint_left := 0.0
var line := ""
var _line_left := 0.0
var _press_index := -1
var _press_pos := Vector2.ZERO
var _press_time := 0.0
var _begun := false
var ally: AllyHero
var _flash := 0.0
var _circle_pts := PackedVector2Array()
var _circle_uvs := PackedVector2Array()


## Main HUD에 붙인다.
static func attach(m: Node) -> HomeSummonButton:
	var b := HomeSummonButton.new()
	b.main = m
	m.hud.add_child(b)
	return b


func _ready() -> void:
	data = rules.data
	add_to_group(SealChoice.BATTLE_TEXT)  # 패 고르기 화면 동안 숨김
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if main and main.spawner:
		main.spawner.boss_spawned.connect(func(_b: Enemy) -> void: on_boss())


## 판이 시작된 뒤 한 번: 주인 영웅 찾기.
func begin() -> void:
	_begun = true
	var hero: HeroData = main.player.hero if main.player else null
	if rules.begin(main.heroes, hero, main.run_stage_id()):
		_say_hint(data.hint_text)


func on_boss() -> void:
	if rules.on_boss():
		_say_hint(data.hint_more_text)


func _say_hint(fmt: String) -> void:
	hint = fmt % rules.home.display_name if fmt.contains("%s") else fmt
	_hint_left = data.hint_time


func shown() -> bool:
	if main == null or not rules.active() or main.waiting_pick or not main.state.is_playing():
		return false
	return not (main.tutorial_director and main.tutorial_director.running())


func center() -> Vector2:
	return data.button_center(size if size.x > 0.0 else get_viewport_rect().size)


func is_on(pos: Vector2) -> bool:
	return pos.distance_to(center()) <= data.button_radius + 12.0


## 누름 처리 (테스트에서 직접 부른다). 단추 위의 누름이면 true (영웅 조작으로 넘기지 않음).
func handle_touch(index: int, pos: Vector2, pressed: bool, time: float = -1.0) -> bool:
	var now := time if time >= 0.0 else Time.get_ticks_msec() / 1000.0
	if not visible or not shown():
		_press_index = -1
		return false
	if pressed:
		if not is_on(pos):
			return false
		_press_index = index
		_press_pos = pos
		_press_time = now
		return true
	if index != _press_index:
		return false
	_press_index = -1
	if is_on(pos) and now - _press_time <= data.tap_max_time:  # 짧게 톡 누른 것만 (꾹·끌기는 부르지 않음)
		summon()
	return true


## 누른 손가락이 끌림. 반환: 움직이기로 넘겼으면 true (그 뒤 끌기·떼기는 영웅 조작이 받는다).
func handle_drag(index: int, pos: Vector2) -> bool:
	if index != _press_index or pos.distance_to(_press_pos) <= data.tap_slop:
		return false
	_press_index = -1
	return true


## 주인 영웅을 부른다 (찼으면, 이미 와 있지 않으면). 나타났으면 true.
func summon() -> bool:
	if not shown() or not rules.can_use() or (ally and is_instance_valid(ally) and ally.active()):
		return false
	ally = AllyHero.spawn(main, rules)
	if ally == null:
		return false
	rules.use()
	_flash = 0.35
	_hint_left = 0.0
	var hl := HeroLines.for_hero(rules.home.id)
	line = hl.line(HeroLines.Case.SUMMON) if hl and GameSettings.story_enabled else ""
	_line_left = data.line_time if line != "" else 0.0
	summoned.emit(rules.home)
	return true


func _input(event: InputEvent) -> void:
	var used := false
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		used = handle_touch(t.index, _to_local(t.position), t.pressed)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var m := event as InputEventMouseButton
		used = handle_touch(1000, _to_local(m.position), m.pressed)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _press_index:
			if handle_drag(d.index, _to_local(d.position)):
				_hand_to_move(d.index, d.position)  # 이 끌기부터는 영웅 조작으로 (처리했다고 표시하지 않음)
			else:
				used = true  # 아직 단추 위의 작은 흔들림
	if used:
		get_viewport().set_input_as_handled()


## 단추에서 시작해 끌린 손가락을 영웅 조작에 누름으로 넘긴다 (움직이려던 손가락).
func _hand_to_move(index: int, screen_pos: Vector2) -> void:
	var tc := main.get_node_or_null("TouchController") as TouchController if main else null
	if tc == null:
		return
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = screen_pos
	e.pressed = true
	tc.handle_event(e, Time.get_ticks_usec() / 1_000_000.0)


## 화면 좌표 → 이 칸 좌표 (HUD는 화면 전체).
func _to_local(p: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * p


## 시간으로 채우기: 판이 흐르는 동안만 (패 고르기·조작 안내·멈춤 동안은 멈춘다).
func _physics_process(delta: float) -> void:
	if not shown() or get_tree().paused:
		return
	if rules.tick(delta):  # 다 찼다: 번쩍임·소리·한 줄 안내
		_flash = 0.35
		_say_hint(data.hint_more_text)
		if Feedback.instance:
			Feedback.instance.play(&"confirm_kill", 0.1)


func _process(delta: float) -> void:
	if main == null:
		return
	if not _begun and main.state.is_playing() and not main.waiting_pick:
		begin()
	_hint_left = maxf(_hint_left - delta, 0.0)
	_line_left = maxf(_line_left - delta, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if not shown():
		return
	var c := center()
	var r := data.button_radius
	var ok := rules.can_use()
	var pressed := _press_index != -1
	var s := 0.92 if pressed else 1.0 + 0.15 * _flash / 0.35
	draw_circle(c, (r + 7.0) * s, UiStyle.LACQUER)
	_draw_face(c, r * s, ok)
	draw_arc(c, (r + 7.0) * s, 0.0, TAU, 48, UiStyle.GOLD if ok else UiStyle.GOLD_DIM, 3.0 if ok else 2.0)
	if not ok and rules.fill() > 0.0:  # 차오르는 고리 (위에서 시계 방향)
		draw_arc(c, (r + 7.0) * s, -PI * 0.5, -PI * 0.5 + TAU * rules.fill(), 48, UiStyle.GOLD, 4.0)
	var st := c + Vector2(r * 0.72, r * 0.72) * s  # 남은 횟수 도장
	draw_circle(st, 17.0, UiStyle.GOLD if ok else UiStyle.GOLD_DIM)
	draw_circle(st, 14.5, Color(0.66, 0.12, 0.1) if ok else Color(0.3, 0.25, 0.22))
	UiStyle.text(self, UiStyle.TITLE_FONT, st + Vector2(-14.5, 8.0), str(rules.charges), 22, Ink.PAPER, 29.0,
		Color(0, 0, 0, 0.0), 0)
	var tx := c.x + r + 18.0
	if _line_left > 0.0:
		var a := clampf(_line_left / 0.4, 0.0, 1.0)
		UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(tx, c.y + 10.0), line, data.font_px + 6, Color(UiStyle.PAPER, a), -1,
			Color(UiStyle.INK, 0.9 * a), 7)
	elif _hint_left > 0.0 and ok:
		var a := clampf(_hint_left / 0.4, 0.0, 1.0)
		UiStyle.text(self, UiStyle.BODY_FONT, Vector2(tx, c.y + 9.0), hint, data.font_px, Color(UiStyle.GOLD, a), -1,
			Color(0, 0, 0, 0.8 * a), 5)


func _draw_face(c: Vector2, r: float, ok: bool) -> void:
	var hero := rules.home
	var tint := Color.WHITE if ok else Color(0.45, 0.45, 0.45)
	if hero.portrait:
		_build_circle()
		draw_circle(c, r, hero.body_color.darkened(0.55))
		draw_set_transform(c, 0.0, Vector2.ONE * (r / 50.0))
		draw_polygon(_circle_pts, PackedColorArray([tint]), _circle_uvs, hero.portrait)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_circle(c, r, hero.body_color * tint)
	if _flash > 0.0:
		draw_circle(c, r, Color(1, 0.95, 0.7, 0.6 * _flash / 0.35))


func _build_circle() -> void:
	if not _circle_pts.is_empty():
		return
	for i in 40:
		var d := Vector2.from_angle(TAU * i / 40.0)
		_circle_pts.append(d * 50.0)
		_circle_uvs.append(Vector2(0.5, 0.5) + d * 0.5)
