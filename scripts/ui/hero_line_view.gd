class_name HeroLineView
extends Control
## 영웅 머리 위 한 줄 대사 (HeroLines 데이터): 전장에 들어설 때(무대 시작 문구가 사라진 뒤, 자기 전장/원정),
## 우두머리가 나올 때(등장 띠가 사라진 뒤), 이겼을 때(처치 띠가 사라진 뒤), 쓰러졌을 때.
## 붓글씨 글꼴·먹 테두리, show_time초 떴다가 끝 fade_time초 동안 흐려진다. 입력을 막지 않고 판을 멈추지 않는다.
## 띄우지 않을 때: 설정 "이야기" 끔, 조작 안내 중. 결과 화면이 떠 있으면 머리 대신 결과 판 바로 위에 띄운다.
## 소환 대사(SUMMON)는 데이터만 있다 (소환 기능이 아직 없음).

@export var show_time := 2.0
@export var fade_time := 0.6
## 영웅 발밑(위치)에서 글 줄까지 높이 (화면 px).
@export var head_offset := 190.0
## 연타 글씨와 띄울 위아래 간격, 옆으로 이만큼 안이면 "가깝다" (화면 px). 가까우면 대사를 연타 글씨 위로 올린다.
@export var combo_gap := 24.0
@export var combo_reach := 140.0
## 다른 문구(무대 시작 문구·우두머리 띠)가 사라지고 이만큼 더 기다린다 (흐려지는 끝자락과 겹치지 않게, 초).
@export var settle_time := 0.6
## 화면 위쪽 (우두머리 체력 띠) 아래로만.
@export var top_margin := 150.0
@export var font_px := 34

var main: Node
var text := ""
var _left := 0.0
var _pending := -1
var _said := {}
var _lines: HeroLines
var _clear := 0.0


## Main에 붙인다 (HUD 위, 판 상태가 만들어진 뒤).
static func attach(m: Node) -> HeroLineView:
	var v := HeroLineView.new()
	v.main = m
	m.hud.add_child(v)
	return v


func _ready() -> void:
	add_to_group(SealChoice.BATTLE_TEXT)  # 패 고르기 화면 동안 숨김
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if main == null:
		return
	if main.spawner:
		main.spawner.boss_spawned.connect(func(_b: Enemy) -> void: queue(HeroLines.Case.BOSS))
		main.spawner.enemy_killed.connect(func(e: Enemy) -> void:
			if e.data and e.data.is_boss:
				queue(HeroLines.Case.VICTORY))
	main.state.ended.connect(func(r: GameState.Result) -> void:
		queue(HeroLines.Case.VICTORY if r == GameState.Result.VICTORY else HeroLines.Case.DEFEAT))


func lines() -> HeroLines:
	if _lines == null and main and main.player and main.player.hero:
		_lines = HeroLines.for_hero(main.player.hero.id)
	return _lines


## 띄울 수 있는 판인지 (이야기 켬, 조작 안내 중 아님, 대사 데이터 있음).
func allowed() -> bool:
	if not GameSettings.story_enabled or lines() == null:
		return false
	return not (main.tutorial_director and main.tutorial_director.running())


## 다른 문구(무대 시작 문구·우두머리 띠)가 떠 있어 잠깐 기다릴 때.
func blocked() -> bool:
	if main.hud and main.hud.stage_title_alpha() > 0.0:
		return true
	var banner: Node = main.get_node_or_null("HUD/BossBanner")
	return banner != null and banner.banner_visible()


## 경우 c의 줄을 띄울 차례로 둔다 (같은 판에 경우마다 한 번).
func queue(c: HeroLines.Case) -> void:
	if not _said.has(c) and allowed():
		_pending = c


func say(c: HeroLines.Case) -> void:
	_said[c] = true
	_pending = -1
	text = lines().line(c) if lines() else ""
	_left = show_time if text != "" else 0.0


func alpha() -> float:
	return clampf(_left / maxf(fade_time, 0.01), 0.0, 1.0)


func step(delta: float) -> void:
	if main == null or main.waiting_pick:
		return
	_left = maxf(_left - delta, 0.0)
	var enter := HeroLines.enter_case(main.player.hero, main.run_stage_id())
	if main.state.is_playing() and not _said.has(enter) and _pending == -1 \
			and main.state.elapsed >= Hud.STAGE_TITLE_TIME:
		queue(enter)
	_clear = 0.0 if blocked() else _clear + delta
	if _pending != -1 and _clear >= settle_time and allowed():
		say(_pending)
	queue_redraw()


func _process(delta: float) -> void:
	step(delta)


## 글 줄 위치: 영웅 머리 위 (결과 화면이 떠 있으면 결과 판 바로 위).
func line_pos() -> Vector2:
	var vp := size if size.x > 0.0 else get_viewport_rect().size
	if not main.state.is_playing():
		return Vector2(vp.x * 0.5, ResultDrawer.panel_top(vp) - 30.0)
	var p: Vector2 = main.player.get_global_transform_with_canvas().origin
	return avoid_combo(p - Vector2(0, head_offset), vp)


## 대사 줄(가운데 at)이 연타 글씨와 같은 높이에서 가까우면(한 줄처럼 읽히면) 연타 글씨 위로 올린다.
func avoid_combo(at: Vector2, vp: Vector2) -> Vector2:
	var combo := main.get_node_or_null("HUD/ComboCounter") as ComboCounter
	var c := combo.text_rect() if combo else Rect2()
	if c.size.x <= 0.0 or text == "":
		return at
	var w := UiStyle.TITLE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
	var line := Rect2(at.x - w * 0.5, at.y - font_px, w, font_px * 1.3)
	if not line.grow_individual(combo_reach, combo_gap, combo_reach, combo_gap).intersects(c):
		return at
	return Vector2(at.x, maxf(c.position.y - combo_gap, top_margin + font_px))


func _draw() -> void:
	if text == "" or _left <= 0.0 or main == null:
		return
	var a := alpha()
	var at := line_pos()
	UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(at.x - 320.0, at.y), text, font_px, Color(UiStyle.PAPER, a), 640.0,
		Color(UiStyle.INK, 0.9 * a), 8)
