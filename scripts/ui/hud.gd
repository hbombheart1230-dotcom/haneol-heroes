class_name Hud
extends Control
## P0 HUD: 체력, 남은 시간, 처치 수, 대시 충전, 결과 화면, 터치 디버그 표시.
## 고정 조이스틱 UI는 그리지 않는다. 디버그 표시는 show_touch_debug로 끌 수 있다.

@export var player: Player
@export var controller: TouchController
@export var show_touch_debug: bool = true
## 결과 화면 아래 "영웅 바꾸기" 띠 높이(px). Main이 같은 값으로 터치를 판정한다.
const CHANGE_HERO_BAND := 140.0
## 영웅이 둘 이상일 때만 띠를 그린다.
var can_change_hero: bool = false

var state: GameState
## P0-D 성능 기록. 결과 화면에 요약을 보여준다.
var perf: PerfStats
## 런 성장 진행 (경험치 막대·레벨 표시). 없으면 그리지 않는다.
var progress: RunProgress
## 판 시작 때 띄우는 무대 이름 (연도 · 전장).
var stage: StageTheme
## 이겼을 때 "다음 전장" 무대 (결과 화면에 이름).
var next_stage: StageTheme
const STAGE_TITLE_TIME := 3.2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player:
		_draw_health()
		_draw_dash_pips()
	if controller and controller.skill_caster:
		SkillButtonDrawer.draw(self, controller, get_theme_default_font())
	if state:
		_draw_status()
		_draw_boss_bar()
		_draw_stage_title()
	if show_touch_debug and GameSettings.show_stats and controller:
		_draw_touch_debug()
	if state and not state.is_playing():
		_draw_result()


## 무대 시작 문구: 연도 · 전장 이름 · 한 줄 설명. 처음 STAGE_TITLE_TIME초, 끝 1초 동안 흐려진다.
func stage_title_alpha() -> float:
	if stage == null or state == null or not state.is_playing():
		return 0.0
	return clampf(STAGE_TITLE_TIME - state.elapsed, 0.0, 1.0)


func _draw_stage_title() -> void:
	var a := stage_title_alpha()
	if a <= 0.0:
		return
	var y := size.y * 0.3
	var band := Rect2(0, y - 92, size.x, 190)
	draw_rect(band, Color(UiStyle.LACQUER, 0.8 * a))
	draw_line(band.position, Vector2(band.end.x, band.position.y), Color(UiStyle.GOLD, a), 2.0)
	draw_line(Vector2(0, band.end.y), band.end, Color(UiStyle.GOLD, a), 2.0)
	UiStyle.text(self, UiStyle.BODY_FONT, Vector2(0, y - 46), stage.year_label, 30, Color(UiStyle.PAPER, a), size.x)
	UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(0, y + 30), stage.title, 84, Color(UiStyle.GOLD, a), size.x)
	UiStyle.gold_rule(self, Vector2(size.x * 0.5, y + 50), size.x * 0.22, a)
	UiStyle.text(self, UiStyle.BODY_FONT, Vector2(0, y + 82), stage.subtitle, 22, Color(UiStyle.PAPER, 0.9 * a), size.x,
		Color(0, 0, 0, 0.6 * a), 4)


func _draw_health() -> void:
	if player.health == null:
		return
	var r := Rect2(16, 16, size.x - 32, 20)
	draw_rect(r.grow(3.0), UiStyle.LACQUER)
	var fill := r
	fill.size.x *= player.health.percent()
	draw_rect(fill, Color(0.72, 0.13, 0.12))
	draw_rect(Rect2(fill.position, Vector2(fill.size.x, 5)), Color(1, 0.55, 0.45, 0.45))  # 윗빛
	draw_rect(r.grow(3.0), UiStyle.GOLD, false, 2.0)


func _draw_status() -> void:
	var font := get_theme_default_font()
	var t := "%d" % ceili(state.time_left())
	if state.survive_time <= 0.0:  # 런: 지난 시간 (분:초)
		t = "%d:%02d" % [floori(state.elapsed / 60.0), floori(state.elapsed) % 60]
	if progress:
		var r := Rect2(16, 44, size.x - 32, 7)
		draw_rect(r.grow(2.0), UiStyle.LACQUER)
		draw_rect(Rect2(r.position, Vector2(r.size.x * progress.xp_ratio(), r.size.y)), UiStyle.GOLD)
		UiStyle.text(self, UiStyle.BODY_FONT, Vector2(16, 82), "단계 %d · 처치 %d" % [progress.level, state.kills], 26,
			UiStyle.PAPER, -1, Color(0, 0, 0, 0.7), 5)
	else:
		_ink_text(font, Vector2(16, 70), "처치 %d" % state.kills, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
	UiStyle.text(self, UiStyle.BODY_FONT, Vector2(0, 112), t, 54, UiStyle.PAPER, size.x, Color(0, 0, 0, 0.85), 9)


## 보스 체력 막대 (보스가 살아 있을 때 화면 위).
func _draw_boss_bar() -> void:
	var bosses := get_tree().get_nodes_in_group(Enemy.BOSS_GROUP)
	if bosses.is_empty():
		return
	var b := bosses[0] as Enemy
	if b == null or not is_instance_valid(b) or b.health.is_dead():
		return
	var r := Rect2(70, 176, size.x - 140, 18)
	UiStyle.panel(self, r.grow(8.0), UiStyle.LACQUER, UiStyle.GOLD)
	draw_rect(Rect2(r.position, Vector2(r.size.x * b.health.percent(), r.size.y)), Color(0.78, 0.16, 0.12))
	draw_rect(Rect2(r.position, Vector2(r.size.x * b.health.percent(), 4)), Color(1, 0.6, 0.45, 0.5))
	var name_text := b.data.display_name if b.data.display_name != "" else "보스"
	UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(0, r.position.y - 14), name_text, 40, UiStyle.GOLD, size.x)


func _draw_dash_pips() -> void:
	var d := player.dash
	var origin := Vector2(48, size.y - 64)
	for i in d.max_charges:
		var c := origin + Vector2(i * 56, 0)
		draw_circle(c, 20, Color(0, 0, 0, 0.5))
		if i < d.charges:
			draw_circle(c, 16, Color(0.4, 0.8, 1.0))
		elif i == d.charges:
			draw_arc(c, 16, -PI / 2, -PI / 2 + TAU * d.get_recharge_ratio(), 24, Color(0.4, 0.8, 1.0, 0.8), 4.0)


func _draw_result() -> void:
	ResultDrawer.draw(self)


func _draw_touch_debug() -> void:
	var t := controller.touch_input
	if t.is_active():
		draw_arc(t.get_anchor(), t.full_speed_radius, 0, TAU, 32, Color(Ink.INK, 0.12), 2.0)
		draw_circle(t.get_anchor(), 6, Color(Ink.INK, 0.25))
		draw_circle(t.get_current(), 10, Color(Ink.INK, 0.3))
	var font := get_theme_default_font()
	var enemies := get_tree().get_nodes_in_group(Enemy.GROUP).size()
	var info := "초당 %d장 · 적 %d" % [Engine.get_frames_per_second(), enemies]
	if controller.dash_note != "":
		_ink_text(font, Vector2(16, size.y - 140), controller.dash_note, HORIZONTAL_ALIGNMENT_LEFT, size.x - 32, 20)
	_ink_text(font, Vector2(16, size.y - 110), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)


## 한지 바탕 위 글자: 먹색 + 종이색 테두리.
func _ink_text(font: Font, pos: Vector2, text: String, align: HorizontalAlignment, width: float, size_px: int) -> void:
	draw_string_outline(font, pos, text, align, width, size_px, 5, Color(Ink.PAPER, 0.9))
	draw_string(font, pos, text, align, width, size_px, Color(Ink.INK, 0.9))
