class_name SkillButtonDrawer
extends RefCounted
## 단일 스킬 버튼 그리기 (HUD에서 호출).
## 지금 발동할 기술을 색·이름으로, 쿨타임은 어두운 부채꼴로, 충전량은 고리로 표시.


static func draw(canvas: CanvasItem, controller: TouchController, font: Font) -> void:
	var sc := controller.skill_caster
	var center := controller.skill_button_center()
	var r := controller.skill_button_radius
	var slot := sc.preview_slot()
	var def := sc.def_of(slot)
	var base: Color = def.color if def else Color(0.3, 0.3, 0.3)
	var can_use := sc.is_ready(slot)
	canvas.draw_circle(center, r, Color(0, 0, 0, 0.35))
	canvas.draw_circle(center, r * 0.86, Color(base, 0.85 if can_use else 0.35))
	var cd := sc.cooldown_ratio(slot)
	if cd > 0.0:
		var pts := PackedVector2Array([center])
		var steps := 24
		for i in steps + 1:
			pts.append(center + Vector2.from_angle(-PI / 2 + TAU * cd * float(i) / steps) * r * 0.86)
		canvas.draw_colored_polygon(pts, Color(0, 0, 0, 0.45))
	if sc.input.state == SkillInput.State.CHARGING:
		var c := sc.input.charge_ratio(Time.get_ticks_usec() / 1_000_000.0)
		canvas.draw_arc(center, r * 0.95, -PI / 2, -PI / 2 + TAU * maxf(c, 0.02), 40, Color(1, 1, 1, 0.95), 8.0)
	elif sc.input.is_down():
		canvas.draw_arc(center, r * 0.95, 0, TAU, 40, Color(1, 1, 1, 0.5), 4.0)
	canvas.draw_string(font, center + Vector2(-r, 10), sc.display_name(slot), HORIZONTAL_ALIGNMENT_CENTER,
		r * 2, 28, Color(1, 1, 1, 0.95 if can_use else 0.5))
