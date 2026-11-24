class_name WaveTrackDrawer
extends RefCounted
## 물결 진행 표시 그리기: 점(먹 고리)이 한 줄. 끝낸 물결은 금빛으로 차고, 지금 물결은 크고 숨 쉬는 금빛 호,
## 중간 우두머리 물결은 마름모, 우두머리 물결은 겹고리. 내닫기 충전 표시와 같은 그림·색 (InkUiStyle).


## center_x = 줄 가운데, flash = 방금 끝낸 물결 번짐 (1 → 0), time = 숨 쉬는 박자용 초.
static func draw(c: CanvasItem, kinds: PackedInt32Array, states: PackedInt32Array, number: int, center_x: float,
		flash: float, flash_at: int, time: float) -> void:
	var n := mini(kinds.size(), states.size())
	if n <= 0:
		return
	var st := InkUiStyle.default()
	var gap := minf(st.wave_spacing, st.wave_max_width / maxf(n - 1, 1))
	var scale := minf(1.0, gap / st.wave_spacing * 1.15)  # 많으면 점도 줄여 그린다
	var x0 := center_x - gap * (n - 1) * 0.5
	var y := st.wave_row_y
	for i in n:
		_dot(c, Vector2(x0 + gap * i, y), kinds[i], states[i], st, scale, time)
	if flash > 0.0 and flash_at >= 0 and flash_at < n:  # 방금 끝낸/시작한 점에서 금빛 고리가 번진다
		var k := 1.0 - flash
		InkPaint.ring(c, Vector2(x0 + gap * flash_at, y), st.wave_radius * scale * (1.0 + 1.4 * k), Color(st.pip_gold, flash * 0.9))
	var label := "물결 %d/%d" % [number, n]
	UiStyle.text(c, UiStyle.BODY_FONT, Vector2(x0 - st.wave_radius - 160.0, y + 7), label, st.wave_label_size,
		Color(UiStyle.PAPER, 0.92), 150.0, Color(0, 0, 0, 0.85), 5)


static func _dot(c: CanvasItem, at: Vector2, kind: int, state: int, st: InkUiStyle, scale: float, time: float) -> void:
	var r := st.wave_radius * scale
	if kind == WaveTrack.Kind.BOSS:
		r *= st.wave_boss_scale
	if state == WaveTrack.State.CURRENT:
		r *= st.wave_current_scale
	var lit := state != WaveTrack.State.FUTURE
	var ring_col := st.pip_ring if lit else st.pip_empty
	if kind == WaveTrack.Kind.ELITE:
		_diamond(c, at, r * 1.15, lit, ring_col, st, state == WaveTrack.State.CURRENT)
	else:
		if lit:
			InkPaint.wash(c, at, r * st.pip_fill_scale, Color(st.pip_gold, 0.55 if state == WaveTrack.State.CURRENT else 1.0))
		InkPaint.ring(c, at, r, ring_col)
		if kind == WaveTrack.Kind.BOSS:
			InkPaint.ring(c, at, r * 0.62, ring_col)  # 우두머리: 겹고리
	if state == WaveTrack.State.CURRENT:
		var a := 0.55 + 0.35 * sin(time * 4.0)  # 숨 쉬듯
		c.draw_arc(at, r * 1.25, 0.0, TAU, 28, Color(st.pip_gold, a), 3.0)


static func _diamond(c: CanvasItem, at: Vector2, r: float, filled: bool, ring_col: Color, st: InkUiStyle, dim: bool) -> void:
	var pts := PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)])
	if filled:
		c.draw_colored_polygon(pts, Color(st.pip_gold, 0.55 if dim else 0.95))
	pts.append(pts[0])
	c.draw_polyline(pts, Color(ring_col, 0.95), 3.0)
