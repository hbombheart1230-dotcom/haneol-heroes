class_name Hud
extends Control
## P0 HUD: 체력, 남은 시간, 처치 수, 대시 충전, 결과 화면, 터치 디버그 표시.
## 고정 조이스틱 UI는 그리지 않는다. 디버그 표시는 show_touch_debug로 끌 수 있다.

@export var player: Player
@export var controller: TouchController
@export var show_touch_debug: bool = true

var state: GameState
## P0-D 성능 기록. 결과 화면에 요약을 보여준다.
var perf: PerfStats


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player:
		_draw_health()
		_draw_dash_pips()
	if controller and controller.skill_caster:
		_draw_skill_button()
	if state:
		_draw_status()
	if show_touch_debug and controller:
		_draw_touch_debug()
	if state and not state.is_playing():
		_draw_result()


func _draw_health() -> void:
	if player.health == null:
		return
	var r := Rect2(16, 16, size.x - 32, 18)
	draw_rect(r, Color(0, 0, 0, 0.5))
	var fill := r
	fill.size.x *= player.health.percent()
	draw_rect(fill, Color(0.85, 0.25, 0.3))
	draw_rect(r, Color(1, 1, 1, 0.4), false, 2.0)


func _draw_status() -> void:
	var font := get_theme_default_font()
	var t := "%d" % ceili(state.time_left())
	draw_string(font, Vector2(0, 92), t, HORIZONTAL_ALIGNMENT_CENTER, size.x, 52, Color(1, 1, 1, 0.9))
	draw_string(font, Vector2(16, 70), "처치 %d" % state.kills, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.85))


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


## 단일 스킬 버튼: 지금 발동할 기술을 색·이름으로, 쿨타임은 어두운 부채꼴로, 충전량은 고리로 표시.
func _draw_skill_button() -> void:
	var sc := controller.skill_caster
	var center := controller.skill_button_center()
	var r := controller.skill_button_radius
	var skill := sc.preview_skill()
	var colors := {
		SkillCaster.Skill.HAERYONG: Color(0.2, 0.5, 0.9),
		SkillCaster.Skill.PADO: Color(0.2, 0.85, 0.95),
		SkillCaster.Skill.HAEIL: Color(0.35, 0.65, 1.0),
	}
	var base: Color = colors.get(skill, Color(0.3, 0.3, 0.3))
	var can_use := sc.is_ready(skill)
	draw_circle(center, r, Color(0, 0, 0, 0.35))
	draw_circle(center, r * 0.86, Color(base, 0.85 if can_use else 0.35))
	var cd := sc.cooldown_ratio(skill)
	if cd > 0.0:
		var pts := PackedVector2Array([center])
		var steps := 24
		for i in steps + 1:
			pts.append(center + Vector2.from_angle(-PI / 2 + TAU * cd * float(i) / steps) * r * 0.86)
		draw_colored_polygon(pts, Color(0, 0, 0, 0.45))
	if sc.input.state == SkillInput.State.CHARGING:
		var c := sc.input.charge_ratio(Time.get_ticks_usec() / 1_000_000.0)
		draw_arc(center, r * 0.95, -PI / 2, -PI / 2 + TAU * maxf(c, 0.02), 40, Color(1, 1, 1, 0.95), 8.0)
	elif sc.input.is_down():
		draw_arc(center, r * 0.95, 0, TAU, 40, Color(1, 1, 1, 0.5), 4.0)
	var font := get_theme_default_font()
	draw_string(font, center + Vector2(-r, 10), SkillCaster.NAMES[skill], HORIZONTAL_ALIGNMENT_CENTER, r * 2, 28, Color(1, 1, 1, 0.95 if can_use else 0.5))


func _draw_result() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	var font := get_theme_default_font()
	var victory := state.result == GameState.Result.VICTORY
	var title := "생존 성공" if victory else "게임 오버"
	var color := Color(0.5, 0.85, 1.0) if victory else Color(1.0, 0.45, 0.45)
	var cy := size.y * 0.42
	draw_string(font, Vector2(0, cy), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 72, color)
	draw_string(font, Vector2(0, cy + 70), "처치 %d  ·  %d초" % [state.kills, floori(state.elapsed)],
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, Color(1, 1, 1, 0.9))
	draw_string(font, Vector2(0, cy + 140), "화면을 터치하면 다시 시작", HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color(1, 1, 1, 0.7))
	if perf and show_touch_debug:
		draw_string(font, Vector2(0, cy + 210), perf.summary(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(1, 1, 0.6, 0.85))


func _draw_touch_debug() -> void:
	var t := controller.touch_input
	if t.is_active():
		draw_arc(t.get_anchor(), t.full_speed_radius, 0, TAU, 32, Color(1, 1, 1, 0.12), 2.0)
		draw_circle(t.get_anchor(), 6, Color(1, 1, 1, 0.25))
		draw_circle(t.get_current(), 10, Color(1, 1, 1, 0.3))
	var font := get_theme_default_font()
	var enemies := get_tree().get_nodes_in_group(Enemy.GROUP).size()
	var info := "FPS %d  적 %d" % [Engine.get_frames_per_second(), enemies]
	draw_string(font, Vector2(16, size.y - 110), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.6))
