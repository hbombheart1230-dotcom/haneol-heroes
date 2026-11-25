class_name RangedTelegraph
extends RefCounted
## 원거리(사격) 예고 그리기 (EnemyArt가 부른다): 날아가는 길을 실제 맞는 폭 그대로 굵은 띠로 보이고
## (먹 테두리 + 인주 속 + 밝은 속줄: 밝은 한지에서도 어두운 바닥에서도 읽힘), 선택에 따라 폭이 좁아지거나
## 쏘는 적 머리 위 표시·화면 밖 사수 방향 쐐기를 더한다. 수치는 RangedTelegraphData. c는 적과 같은 좌표계.


static func draw(e: Enemy, c: CanvasItem, k: float, flash: bool) -> void:
	var a := e.attack
	var d := RangedTelegraphData.default()
	var hit_w := a.data.projectile_radius * 2.0
	var w := hit_w
	if d.style == 1:
		w = lerpf(hit_w * d.narrow_from, hit_w, k)
	var dir := a.aim_dir
	var end := dir * a.data.projectile_range
	var n := dir.orthogonal()
	var fill_a := lerpf(d.fill_alpha_from, d.fill_alpha_to, k)
	var fill := Color(Ink.SEAL.lightened(0.45), d.flash_alpha) if flash else Color(Ink.SEAL, fill_a)
	_band(c, Vector2.ZERO, end, n, w + d.border_px * 2.0, Color(Ink.INK, d.border_alpha))
	_band(c, Vector2.ZERO, end, n, w, fill)
	c.draw_line(Vector2.ZERO, end, Color(Ink.PAPER, 1.0 if flash else d.core_alpha), d.core_px)
	if d.style == 2:
		_head_mark(e, c, k, flash, d)
		_edge_arrow(e, c, flash, d)


static func _band(c: CanvasItem, from: Vector2, to: Vector2, n: Vector2, w: float, col: Color) -> void:
	var h := n * w * 0.5
	c.draw_colored_polygon(PackedVector2Array([from + h, to + h, to - h, from - h]), col)


## 쏘는 적 머리 위: 먹 테두리 인주 삼각형 + 가운데 한지 점 ("곧 쏜다"), 예고가 차오를수록 커졌다 마지막엔 번쩍.
static func _head_mark(e: Enemy, c: CanvasItem, k: float, flash: bool, d: RangedTelegraphData) -> void:
	var s := d.head_mark_px * (0.75 + 0.25 * k) * (1.2 if flash else 1.0)
	var top := Vector2(0, -e.body_radius * d.head_mark_lift)
	var tri := PackedVector2Array([top + Vector2(0, s * 0.5), top + Vector2(-s * 0.5, -s * 0.5), top + Vector2(s * 0.5, -s * 0.5)])
	c.draw_colored_polygon(_grow(tri, top, 1.0 + 7.0 / s), Color(Ink.INK, d.border_alpha))
	c.draw_colored_polygon(tri, Color(Ink.SEAL.lightened(0.45), 1.0) if flash else Color(Ink.SEAL, 0.95))
	c.draw_circle(top + Vector2(0, -s * 0.12), s * 0.1, Ink.PAPER)


## 사수가 화면 밖이면 그쪽 화면 끝에 인주 쐐기 (그 방향에서 쏜다). 화면 안이면 아무것도 안 그린다.
static func _edge_arrow(e: Enemy, c: CanvasItem, flash: bool, d: RangedTelegraphData) -> void:
	if not e.is_inside_tree():
		return
	var vp := e.get_viewport()
	var view: Rect2 = vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	if view.has_point(e.global_position):
		return
	var inner := view.grow(-d.edge_margin)
	var p := e.global_position.clamp(inner.position, inner.end)
	var out := (e.global_position - p).normalized()
	var s := d.edge_arrow_px
	var tip := e.to_local(p + out * s * 0.6)
	var o := e.to_local(p)
	var pts := PackedVector2Array([tip, o + out.orthogonal() * s * 0.5, o - out.orthogonal() * s * 0.5])
	c.draw_colored_polygon(_grow(pts, o, 1.35), Color(Ink.INK, d.border_alpha))
	c.draw_colored_polygon(pts, Color(Ink.SEAL.lightened(0.45), 1.0) if flash else Color(Ink.SEAL, 0.95))


static func _grow(pts: PackedVector2Array, center: Vector2, f: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(center + (p - center) * f)
	return out
