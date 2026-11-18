class_name SkillButtonDrawer
extends RefCounted
## 스킬 입력 UI 그리기 (HUD에서 호출).
## - 버튼(설정에서 켰을 때): 지금 발동할 기술을 색·이름으로, 쿨타임은 어두운 부채꼴로, 충전량은 고리로.
## - 버튼이 꺼져 있을 때: 기술 3개의 쿨타임만 작게 표시 (제스처 조작용).
## - 버튼 켜기/끄기 토글.


static func draw(canvas: CanvasItem, controller: TouchController, font: Font) -> void:
	var sc := controller.skill_caster
	_draw_counter_prompt(canvas, controller, sc, font)
	if controller.skill_button_enabled:
		_draw_button(canvas, controller, sc, font)
	else:
		_draw_status(canvas, controller, sc, font)
	_draw_toggle(canvas, controller, font)


## 회피 성공 후 반격 가능 시간: 화면 가장자리 강조 + "반격!" + 남은 시간 막대.
static func _draw_counter_prompt(canvas: CanvasItem, controller: TouchController, sc: SkillCaster, font: Font) -> void:
	var left := sc.counter_time_left()
	if left <= 0.0 or sc.kit == null or sc.kit.counter == null:
		return
	var size := controller.viewport_size()
	var k := clampf(left / maxf(sc.kit.counter_window, 0.001), 0.0, 1.0)
	var c: Color = sc.kit.counter.color
	var w := 18.0
	for r in [Rect2(0, 0, size.x, w), Rect2(0, size.y - w, size.x, w), Rect2(0, 0, w, size.y), Rect2(size.x - w, 0, w, size.y)]:
		canvas.draw_rect(r, Color(c, 0.35 + 0.3 * k))
	var y := size.y * 0.72
	if sc.kit.counter.icon:  # 반격 아이콘이 깜빡이며 커진다
		var s := 64.0 + 16.0 * absf(sin(left * 12.0))
		canvas.draw_texture_rect(sc.kit.counter.icon, Rect2(Vector2(size.x * 0.5 - s * 0.5, y - 60.0 - s), Vector2(s, s)), false)
	canvas.draw_string_outline(font, Vector2(0, y), sc.kit.counter.display_name + "!", HORIZONTAL_ALIGNMENT_CENTER, size.x, 44, 8, Color(Ink.INK, 0.9))
	canvas.draw_string(font, Vector2(0, y), sc.kit.counter.display_name + "!", HORIZONTAL_ALIGNMENT_CENTER, size.x, 44, Color(c, 0.95))
	var bar := Rect2(size.x * 0.3, y + 16, size.x * 0.4, 10)
	canvas.draw_rect(bar, Color(0, 0, 0, 0.5))
	canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), Color(c, 0.9))


static func _draw_button(canvas: CanvasItem, controller: TouchController, sc: SkillCaster, font: Font) -> void:
	var center := controller.skill_button_center()
	var r := controller.skill_button_radius
	var slot := sc.preview_slot()
	var def := sc.def_of(slot)
	var base: Color = def.color if def else Color(0.3, 0.3, 0.3)
	var can_use := sc.is_ready(slot)
	canvas.draw_circle(center, r, Color(0, 0, 0, 0.35))
	_draw_face(canvas, def, base, center, r * 0.86, can_use, sc.cooldown_ratio(slot))
	if sc.input.state == SkillInput.State.CHARGING:
		var c := sc.input.charge_ratio(Time.get_ticks_usec() / 1_000_000.0)
		canvas.draw_arc(center, r * 0.95, -PI / 2, -PI / 2 + TAU * maxf(c, 0.02), 40, Color(1, 1, 1, 0.95), 8.0)
	elif sc.input.is_from(SkillInput.Source.BUTTON):
		canvas.draw_arc(center, r * 0.95, 0, TAU, 40, Color(1, 1, 1, 0.5), 4.0)
	canvas.draw_string(font, center + Vector2(-r, 10), sc.display_name(slot), HORIZONTAL_ALIGNMENT_CENTER,
		r * 2, 30, Color(1, 1, 1, 0.95 if can_use else 0.5))


## 버튼 없이 제스처로 쓸 때: 오른쪽 아래에 기술 3개 쿨타임 (탭 / 튕기고 탭 / 꾹).
static func _draw_status(canvas: CanvasItem, controller: TouchController, sc: SkillCaster, font: Font) -> void:
	var slots := [SkillCaster.Slot.TAP, SkillCaster.Slot.DASH, SkillCaster.Slot.CHARGE]
	var hints := ["탭", "대시 후 떼기", "꾹"]
	var size := controller.viewport_size()
	var r := 32.0
	for i in slots.size():
		var slot: SkillCaster.Slot = slots[i]
		var def := sc.def_of(slot)
		if def == null:
			continue
		var c := Vector2(size.x - 60 - (slots.size() - 1 - i) * 84, size.y - 74)
		_draw_face(canvas, def, def.color, c, r, sc.is_ready(slot), sc.cooldown_ratio(slot))
		canvas.draw_string(font, c + Vector2(-40, -r - 8), def.display_name, HORIZONTAL_ALIGNMENT_CENTER, 80, 16, Color(1, 1, 1, 0.85))
		canvas.draw_string(font, c + Vector2(-40, r + 18), hints[i], HORIZONTAL_ALIGNMENT_CENTER, 80, 14, Color(1, 1, 1, 0.6))


static func _draw_toggle(canvas: CanvasItem, controller: TouchController, font: Font) -> void:
	var rect := controller.toggle_rect()
	var on := controller.skill_button_enabled
	canvas.draw_rect(rect, Color(0, 0, 0, 0.4))
	canvas.draw_rect(rect, Color(1, 1, 1, 0.35), false, 2.0)
	var label := "버튼 켬" if on else "버튼 끔"
	canvas.draw_string(font, rect.position + Vector2(0, rect.size.y * 0.66), label, HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x, 22, Color(1, 1, 1, 0.9 if on else 0.6))


## 기술 얼굴: 아이콘이 있으면 아이콘(쿨타임은 위에서부터 어둡게 덮음), 없으면 색 원 + 부채꼴.
static func _draw_face(canvas: CanvasItem, def: SkillDef, base: Color, center: Vector2, r: float,
		can_use: bool, cooldown: float) -> void:
	if def and def.icon:
		var rect := Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0)
		canvas.draw_texture_rect(def.icon, rect, false, Color(1, 1, 1, 1.0 if can_use else 0.55))
		if cooldown > 0.0:
			canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * cooldown)), Color(0, 0, 0, 0.6))
		return
	canvas.draw_circle(center, r, Color(base, 0.85 if can_use else 0.35))
	_draw_cooldown(canvas, center, r, cooldown)


static func _draw_cooldown(canvas: CanvasItem, center: Vector2, r: float, ratio: float) -> void:
	if ratio <= 0.0:
		return
	var pts := PackedVector2Array([center])
	var steps := 24
	for i in steps + 1:
		pts.append(center + Vector2.from_angle(-PI / 2 + TAU * ratio * float(i) / steps) * r)
	canvas.draw_colored_polygon(pts, Color(0, 0, 0, 0.45))
