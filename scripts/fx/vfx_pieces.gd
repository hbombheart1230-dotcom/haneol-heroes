class_name VfxPieces
extends Node2D
## 기술 그림 연출 (SkillVfxData "연출" 묶음): 그림 한 장을 그대로 내보내지 않고
##   조각 등장 — 부채꼴 조각이 시작 방향부터 차례로 튀어나와 자리 잡고 (감겨 들며 멈춤) → 다 모이면 번쩍 →
##   먹으로 번지며 조각이 바깥으로 흩어진다.
##   바늘·눈금 — 해시계 그림자 바늘이 한 바퀴 돌고, 지나는 눈금마다 번쩍인다.
##   베인 자국 — 맞은 적마다 초승달 붓 획이 긋고 번진다.
##   모이는 기운 — 지연 기술의 예고 (바깥에서 가운데로 빨려 드는 빛 줄기).
## VfxDecals의 수묵 번짐 셰이더를 같이 쓰고(use_parent_material), 빛은 더하기 층 하나에 그린다.
## 그릴 때 배열을 새로 만들지 않는다 (조각 다각형 버퍼를 한 번 만들어 채워 쓴다). 상한은 SkillStageFeel.

var stage: SkillStageFeel
## 조각 묶음 {data, pos, rot, start, size, t, life, bright}
var _sets: Array[Dictionary] = []
## 바늘 {data, pos, start, r, t, sweep, life}
var _hands: Array[Dictionary] = []
## 눈금·번쩍임 빛 {pos, size, color, t, life, star}
var _glints: Array[Dictionary] = []
## 베인 자국 {pos, rot, size, color, t, life}
var _marks: Array[Dictionary] = []
## 모이는 기운 {from, to, size, color, t, life}
var _gather: Array[Dictionary] = []
var _glow: Node2D
## 색을 입히는 붓 그림 층 (베인 자국·바늘·금빛 고리): 같은 수묵 셰이더의 tinted 판.
var _ink: Node2D
var _pts := PackedVector2Array()
## 조각을 가운데에서 펼친 부채꼴 삼각형으로 그리는 순서 (0, j+1, j+2). draw_polygon은 제멋대로 삼각형을 나눠서
## 양 끝의 투명한 꼭짓점이 안쪽 띠까지 번져, 고리 모양 그림(가운데가 빈 용)이 통째로 갉혔다.
var _fan := PackedInt32Array()
var _none_i := PackedInt32Array()
var _none_f := PackedFloat32Array()
var _uvs := PackedVector2Array()
var _cols := PackedColorArray()
## 두루마리 띠 하나 (네모 4점) 버퍼.
var _qpts := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _quvs := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _qcols := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])


func _init(p_stage: SkillStageFeel = null) -> void:
	stage = p_stage if p_stage else SkillStageFeel.get_default()
	use_parent_material = true
	var n := maxi(stage.piece_arc_steps, 1) + 2
	_pts.resize(n)
	for j in n - 2:
		_fan.append(0)
		_fan.append(j + 1)
		_fan.append(j + 2)
	_uvs.resize(n)
	_cols.resize(n)
	_glow = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	_ink = Node2D.new()
	_ink.draw.connect(_draw_ink)
	add_child(_ink)


func set_ink_material(m: Material) -> void:
	_ink.material = m


func ink_node() -> Node2D:
	return _ink


func set_count() -> int:
	return _sets.size()


func hand_count() -> int:
	return _hands.size()


func glint_count() -> int:
	return _glints.size()


func mark_count() -> int:
	return _marks.size()


func gather_count() -> int:
	return _gather.size()


## 오래된 것부터 지워 상한을 지킨다.
static func _cap(list: Array[Dictionary], n: int) -> void:
	while list.size() > maxi(n, 0):
		list.pop_front()


## 그림을 조각으로 펼친다. dir = 시작 방향 (없으면 위).
## size > 0이면 그 지름 (판정에 맞춘 크기), 아니면 데이터 크기 × 강화 배율.
func pieces(d: SkillVfxData, pos: Vector2, dir: Vector2, level: int, size: float = 0.0) -> void:
	if d == null or not d.has_decal() or d.piece_count <= 0:
		return
	if size <= 0.0:
		size = d.decal_size * d.size_mult(level)
	var start := dir.angle() if dir.length_squared() > 0.0001 else -PI * 0.5
	var rot := start - deg_to_rad(d.decal_angle_deg) if d.decal_align else randf() * TAU
	if d.decal_upright:
		rot = 0.0
	var life := maxf(d.decal_time, d.piece_sweep + stage.piece_settle + 0.25)
	_sets.append({"data": d, "pos": pos, "rot": rot, "start": start, "size": size,
		"t": 0.0, "life": life, "bright": 1.0 + d.level_glow * d.level_of(level), "glow": d.glow_for(level)})
	_cap(_sets, stage.max_piece_sets)
	if d.sweep_hand:
		_hands.append({"data": d, "pos": pos, "start": start, "r": size * 0.42,
			"t": 0.0, "sweep": maxf(d.piece_sweep, 0.01), "life": d.piece_sweep + stage.hand_linger})
		_cap(_hands, stage.max_hands)


## 눈금 하나 번쩍 (해시계 바늘이 지날 때, SweepRun.on_tick). i번째 / n개, 시작 방향 start.
func tick_glint(d: SkillVfxData, center: Vector2, start: float, i: int, level: int) -> void:
	if d == null or d.tick_count <= 0:
		return
	var a := start + d.piece_dir * TAU * float(i) / float(d.tick_count)
	var r := d.decal_size * d.size_mult(level) * 0.4
	glint(center + Vector2.from_angle(a) * r, d.tick_size * d.size_mult(level), d.tick_color, true)


func glint(pos: Vector2, size: float, color: Color, star: bool = false) -> void:
	_glints.append({"pos": pos, "size": size, "color": color, "t": 0.0, "life": stage.tick_time, "star": star})
	_cap(_glints, stage.max_ticks)


## 맞은 자리 베인 자국 (맞은 방향에 가로로).
func hit_mark(d: SkillVfxData, pos: Vector2, dir: Vector2, level: int) -> void:
	if d == null or d.hit_mark_size <= 0.0:
		return
	var a := dir.angle() if dir.length_squared() > 0.0001 else randf() * TAU
	_marks.append({"pos": pos, "rot": a + PI * 0.5 + randf_range(-0.35, 0.35), "size": d.hit_mark_size * d.size_mult(level),
		"color": d.hit_mark_color, "t": 0.0, "life": maxf(d.hit_mark_time, 0.05)})
	_cap(_marks, stage.max_hit_marks)


## 예고: 바깥에서 가운데로 빨려 드는 기운 (gather_time초).
func gather(d: SkillVfxData, pos: Vector2, level: int) -> void:
	if d == null or d.gather_time <= 0.0 or d.gather_count <= 0:
		return
	var n := roundi(d.gather_count * (1.0 + d.level_count * d.level_of(level)))
	for i in n:
		var a := TAU * float(i) / float(n) + randf_range(-0.3, 0.3)
		var r := d.gather_radius * d.size_mult(level) * randf_range(0.7, 1.15)
		_gather.append({"from": pos + Vector2.from_angle(a) * r, "to": pos, "size": randf_range(28.0, 46.0),
			"color": d.gather_color, "t": -randf() * d.gather_time * 0.35, "life": d.gather_time})
	_cap(_gather, stage.max_gather)


func _process(delta: float) -> void:
	step(delta)
	queue_redraw()
	_glow.queue_redraw()
	_ink.queue_redraw()


func step(delta: float) -> void:
	_age(_sets, delta)
	_age(_hands, delta)
	_age(_glints, delta)
	_age(_marks, delta)
	_age(_gather, delta)


static func _age(list: Array[Dictionary], delta: float) -> void:
	var i := list.size() - 1
	while i >= 0:
		var it := list[i]
		it["t"] = float(it["t"]) + delta
		if float(it["t"]) >= float(it["life"]):
			list.remove_at(i)
		i -= 1


## 조각 i의 등장 진행 (0 = 아직, 1 = 자리 잡음). 순수 계산 (테스트).
static func piece_progress(t: float, i: int, n: int, sweep: float, settle: float) -> float:
	var at := sweep * float(i) / float(maxi(n, 1))
	if t < at:
		return 0.0
	return clampf((t - at) / maxf(settle, 0.001), 0.0, 1.0)


func _draw() -> void:
	for st in _sets:
		_draw_set(st)


func _draw_ink() -> void:
	var needle := VfxTextures.get_texture(SkillVfxData.Shape.SHARD)  # 양끝이 가는 그림자 바늘 (먹 셰이더가 갉음)
	for h in _hands:
		_draw_hand(h, needle)
	var cres := Feedback.feel_data().crescent_art
	for m in _marks:
		if cres == null:
			break
		var k := float(m["t"]) / float(m["life"])
		var drawn := minf(k / maxf(stage.hit_mark_draw, 0.01), 1.0)
		var s := float(m["size"])
		var c: Color = m["color"]
		_ink.draw_set_transform(m["pos"], float(m["rot"]), Vector2(lerpf(0.25, 1.1, 1.0 - pow(1.0 - drawn, 3.0)), 1.0))
		_ink.draw_texture_rect(cres, Rect2(-s * 0.5, -s * stage.hit_mark_thickness * 0.5, s, s * stage.hit_mark_thickness),
			false, Color(c.r, c.g, c.b, c.a * (1.0 - k)))
	_ink.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_set(st: Dictionary) -> void:
	var d: SkillVfxData = st["data"]
	var t := float(st["t"])
	var k := t / float(st["life"])
	var n := d.piece_count
	var settle := stage.piece_settle
	var all_in := clampf(t / maxf(d.piece_sweep + settle, 0.001), 0.0, 1.0)
	var rot := float(st["rot"]) - d.piece_dir * d.piece_spin_in * pow(1.0 - all_in, 3.0)
	var size := float(st["size"]) * lerpf(1.0, d.decal_grow, 1.0 - pow(1.0 - k, 2.0))
	var scatter := d.piece_scatter * maxf((k - 0.55) / 0.45, 0.0)
	var b := float(st["bright"])
	var center: Vector2 = st["pos"]
	var radius := size * 0.53
	var tex := d.decal_at(t)
	if tex == null:
		return
	if d.piece_mode == SkillVfxData.PieceMode.SCROLL:
		_draw_scroll(st, d, tex, t, k, size)
		return
	var steps := _pts.size() - 2
	var wedge := TAU / float(n)
	for i in n:
		var p := piece_progress(t, i, n, d.piece_sweep, settle)
		if p <= 0.0:
			continue
		var ease := 1.0 - pow(1.0 - p, 3.0)
		var a0 := float(st["start"]) + d.piece_dir * wedge * i
		var mid := Vector2.from_angle(a0 + d.piece_dir * wedge * 0.5)
		var shift := mid * (d.piece_push * (1.0 - ease) + scatter)
		var grow := 1.0 + d.piece_pop * (1.0 - ease)
		var col := d.ink_color(b, (1.0 - k) * minf(p * 2.0, 1.0))
		_pts[0] = center + shift
		_uvs[0] = Vector2(0.5, 0.5)
		_cols[0] = col
		# 양옆 조각 쪽으로 겹쳐 뻗고 양 끝은 투명 → 곧은 칼선 대신 셰이더가 붓 자국처럼 갉는다
		var f := maxf(stage.piece_feather, 0.001)
		for j in steps + 1:
			var s := -f + (1.0 + 2.0 * f) * float(j) / float(steps)
			var a := a0 + d.piece_dir * wedge * s
			var off := Vector2.from_angle(a) * radius
			_pts[j + 1] = center + shift + off * grow
			_uvs[j + 1] = off.rotated(-rot) / size + Vector2(0.5, 0.5)
			var edge := clampf(minf(s + f, 1.0 + f - s) / f, 0.0, 1.0)
			_cols[j + 1] = Color(col.r, col.g, col.b, col.a * edge)
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _fan, _pts, _cols, _uvs, _none_i, _none_f, tex.get_rid())


## 두루마리 펼침: 세로 띠가 가운데부터 양옆으로 차례로 펼쳐진다 (바깥 가장자리는 투명 → 먹으로 갉힘).
func _draw_scroll(st: Dictionary, d: SkillVfxData, tex: Texture2D, t: float, k: float, size: float) -> void:
	var n := maxi(d.piece_count, 2)
	var center: Vector2 = st["pos"]
	var b := float(st["bright"])
	var half := (n - 1) * 0.5
	var slice := size / float(n)
	var scatter := d.piece_scatter * maxf((k - 0.55) / 0.45, 0.0)
	for i in n:
		var rank := int(round(absf(i - half)))
		var p := piece_progress(t, rank, int(ceil(half)) + 1, d.piece_sweep, stage.piece_settle)
		if p <= 0.0:
			continue
		var ease := 1.0 - pow(1.0 - p, 3.0)
		var side := signf(i - half)
		var x0 := -size * 0.5 + slice * i
		var w := slice * (ease if side != 0.0 else 1.0)
		if side < 0.0:
			x0 += slice - w  # 왼쪽은 오른쪽 가장자리에서 펼쳐 나간다
		var lift := Vector2(side * scatter, scatter * 0.3 * sin(i * 1.7))
		var aspect := tex.get_height() / maxf(tex.get_width(), 1.0)  # 가로로 긴 두루마리 띠 그림도 비율대로
		var hh := size * 0.5 * aspect * (1.0 + d.piece_pop * (1.0 - ease) * 0.3)
		var col := d.ink_color(b, (1.0 - k) * minf(p * 2.0, 1.0))
		var outer := Color(col.r, col.g, col.b, col.a * (0.1 + 0.6 * ease))  # 펼쳐지는 끝은 먹으로 갉힘
		_qpts[0] = center + lift + Vector2(x0, -hh)
		_qpts[1] = center + lift + Vector2(x0 + w + 1.0, -hh)
		_qpts[2] = center + lift + Vector2(x0 + w + 1.0, hh)
		_qpts[3] = center + lift + Vector2(x0, hh)
		var u0 := (x0 + size * 0.5) / size
		var u1 := (x0 + w + size * 0.5) / size
		_quvs[0] = Vector2(u0, 0.0)
		_quvs[1] = Vector2(u1, 0.0)
		_quvs[2] = Vector2(u1, 1.0)
		_quvs[3] = Vector2(u0, 1.0)
		var left_outer := side < 0.0
		_qcols[0] = outer if left_outer else col
		_qcols[3] = outer if left_outer else col
		_qcols[1] = col if left_outer or side == 0.0 else outer
		_qcols[2] = col if left_outer or side == 0.0 else outer
		draw_polygon(_qpts, _qcols, _quvs, tex)


func _draw_hand(h: Dictionary, stroke: Texture2D) -> void:
	if stroke == null:
		return
	var d: SkillVfxData = h["data"]
	var t := float(h["t"])
	var swept := minf(t / float(h["sweep"]), 1.0)
	var fade := 1.0 - maxf(t - float(h["sweep"]), 0.0) / maxf(stage.hand_linger, 0.01)
	var a := float(h["start"]) + d.piece_dir * TAU * swept
	var r := float(h["r"])
	var art := d.hand_art  # 그려 넣은 바늘이 있으면 그것 (색 그대로), 없으면 코드 바늘을 그림자 색으로
	var tex := art if art else stroke
	var hw := r * 1.15 * art.get_height() / maxf(art.get_width(), 1.0) if art else d.hand_width
	var tint := Color.WHITE if art else d.hand_color
	for g in range(stage.hand_ghosts, -1, -1):  # 잔상(옅게) → 바늘(진하게)
		var ga := a - d.piece_dir * stage.hand_ghost_gap * g
		var alpha := d.hand_color.a * fade * (1.0 - float(g) / float(stage.hand_ghosts + 1))
		_ink.draw_set_transform(h["pos"], ga, Vector2.ONE)
		_ink.draw_texture_rect(tex, Rect2(-r * 0.15, -hw * 0.5, r * 1.15, hw), false, Color(tint.r, tint.g, tint.b, alpha))
	_ink.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_glow() -> void:
	var dot := VfxTextures.get_texture(SkillVfxData.Shape.DOT)
	var star := VfxTextures.get_texture(SkillVfxData.Shape.STAR)
	var shard := VfxTextures.get_texture(SkillVfxData.Shape.SHARD)
	for st in _sets:  # 바닥 빛 (조각이 모이는 만큼) + 다 모인 순간 번쩍
		var d: SkillVfxData = st["data"]
		var t := float(st["t"])
		var k := t / float(st["life"])
		var gathered := clampf(t / maxf(d.piece_sweep, 0.001), 0.0, 1.0)
		var since := t - d.piece_sweep
		var f := 1.0 - since / stage.flash_time if since >= 0.0 and since <= stage.flash_time else 0.0
		var a := float(st["glow"]) * gathered * (1.0 - k) + d.piece_flash * f
		if a <= 0.0:
			continue
		var s := float(st["size"]) * lerpf(d.glow_size, stage.flash_scale * 1.3, f)
		_glow.draw_texture_rect(dot, Rect2(st["pos"] - Vector2.ONE * s * 0.5, Vector2.ONE * s), false,
			Color(d.glow_color, minf(a, 1.0)))
	for g in _glints:
		var k := float(g["t"]) / float(g["life"])
		var s := float(g["size"]) * (0.6 + 0.6 * sin(minf(k * 2.0, 1.0) * PI * 0.5))
		var c: Color = g["color"]
		_glow.draw_set_transform(g["pos"], k * 1.5, Vector2.ONE)
		_glow.draw_texture_rect(star if g["star"] else dot, Rect2(-Vector2.ONE * s * 0.5, Vector2.ONE * s), false,
			Color(c, c.a * (1.0 - k)))
	for q in _gather:
		var t := float(q["t"])
		if t < 0.0:
			continue
		var k := t / float(q["life"])
		var e := k * k  # 점점 빨라지며 빨려 듦
		var from: Vector2 = q["from"]
		var to: Vector2 = q["to"]
		var p := from.lerp(to, e)
		var s := float(q["size"]) * (1.0 - 0.5 * k)
		var c: Color = q["color"]
		_glow.draw_set_transform(p, (to - from).angle(), Vector2(1.0 + 2.0 * k, 0.5))
		_glow.draw_texture_rect(shard, Rect2(-Vector2.ONE * s * 0.5, Vector2.ONE * s), false,
			Color(c, c.a * minf(k * 3.0, 1.0)))
	_glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
