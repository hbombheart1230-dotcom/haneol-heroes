class_name BrushFlickFx
extends Node2D
## 사임당 먹 털기 그림 (BrushFlickData): 판정 모양을 따라 붓 획(CombatFeelData.stroke_art)이 휘둘러지듯 그려지고 먹으로 풀린다.
## 부채꼴 = 휘어진 획, 한 줄 = 곧은 획, 고리 = 둘레를 도는 획. 바닥 먹 방울 자국. 칸을 미리 잡아 돌려 쓰고
## 프레임마다 배열을 만들지 않는다 (꼭짓점 버퍼 재사용).

var data: BrushFlickData
var stroke: Texture2D
var _shape := PackedInt32Array()
var _origin := PackedVector2Array()
var _angle := PackedFloat32Array()
var _range := PackedFloat32Array()
var _arc := PackedFloat32Array()
var _t := PackedFloat32Array()
var _color := PackedColorArray()
var _next: int = 0
var _s_pos := PackedVector2Array()
var _s_t := PackedFloat32Array()
var _s_r := PackedFloat32Array()
var _s_seed := PackedFloat32Array()
var _s_next: int = 0
var _pts := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _uvs := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _cols := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])


func _init(p_data: BrushFlickData = null, p_stroke: Texture2D = null) -> void:
	data = p_data if p_data else BrushFlickData.new()
	stroke = p_stroke
	var n := maxi(data.max_strokes, 1)
	_shape.resize(n)
	_origin.resize(n)
	_angle.resize(n)
	_range.resize(n)
	_arc.resize(n)
	_t.resize(n)
	_color.resize(n)
	for i in n:
		_t[i] = -1.0
	var m := maxi(data.max_splats, 1)
	_s_pos.resize(m)
	_s_t.resize(m)
	_s_r.resize(m)
	_s_seed.resize(m)
	for i in m:
		_s_t[i] = -1.0
	z_as_relative = false
	z_index = 19  # 접점 섬광(20) 바로 아래


func stroke_count() -> int:
	var n := 0
	for t in _t:
		if t >= 0.0:
			n += 1
	return n


func splat_count() -> int:
	var n := 0
	for t in _s_t:
		if t >= 0.0:
			n += 1
	return n


## 한 번 털기: origin = 영웅 가운데, dir = 겨눈 방향, reach = 판정 거리(px), arc_deg = 판정 각도, step = 1~3타.
func flick(origin: Vector2, dir: Vector2, reach: float, arc_deg: float, step: int, color: Color) -> void:
	var i := _next
	_next = (_next + 1) % _t.size()
	var shape := data.shape_of(arc_deg)
	_shape[i] = shape
	_origin[i] = origin
	_angle[i] = dir.angle() if dir.length_squared() > 0.0001 else 0.0
	_range[i] = reach
	_arc[i] = deg_to_rad(clampf(arc_deg, 1.0, 360.0))
	_t[i] = 0.0
	_color[i] = color
	for j in HitImpactData.at_i(data.splats, step, 3):  # 바닥 먹 자국: 판정 모양 안 아무 데나
		var a := _angle[i] + randf_range(-0.5, 0.5) * (TAU if shape == 2 else _arc[i])
		var d := reach * (randf_range(0.75, 1.0) if shape == 2 else randf_range(0.4, 1.0))
		_splat(origin + Vector2.from_angle(a) * d)
	queue_redraw()


func _splat(pos: Vector2) -> void:
	var i := _s_next
	_s_next = (_s_next + 1) % _s_t.size()
	_s_pos[i] = pos
	_s_t[i] = 0.0
	_s_r[i] = randf_range(data.splat_radius.x, data.splat_radius.y)
	_s_seed[i] = randf() * 10.0


func _process(delta: float) -> void:
	step(delta)
	queue_redraw()


func step(delta: float) -> void:
	var life := data.life()
	for i in _t.size():
		if _t[i] >= 0.0:
			_t[i] += delta
			if _t[i] >= life:
				_t[i] = -1.0
	for i in _s_t.size():
		if _s_t[i] >= 0.0:
			_s_t[i] += delta
			if _s_t[i] >= data.splat_time:
				_s_t[i] = -1.0


## 먹 자국(단색)과 붓 조각(획 그림 한 장)을 각각 모아 한 번에 (InkBatch, 모양·색·차례 그대로).
var _b := InkBatch.new()
var _bt := InkBatch.new()


func _draw() -> void:
	for i in _s_t.size():
		if _s_t[i] < 0.0:
			continue
		var k := _s_t[i] / data.splat_time
		_b.splash(_s_pos[i], _s_r[i] * (0.8 + 0.4 * minf(k * 4.0, 1.0)), Color(data.ink_color, data.splat_alpha * (1.0 - k)), _s_seed[i])
	_b.flush(self)
	if stroke == null:
		return
	for i in _t.size():
		if _t[i] >= 0.0:
			_draw_stroke(i)
	_bt.flush(self, stroke)


func _draw_stroke(i: int) -> void:
	var d := data
	var t := _t[i]
	var shown := clampf(t / maxf(d.reveal, 0.001), 0.0, 1.0)
	var fade := 1.0 - clampf((t - d.reveal - d.hold) / maxf(d.fade, 0.001), 0.0, 1.0)
	if fade <= 0.0:
		return
	var n := maxi(d.segments, ceili(rad_to_deg(_arc[i]) / d.seg_deg) if _shape[i] != 1 else 2)  # 고리는 더 잘게 (각이 보이지 않게)
	var ink := Color(d.ink_color, d.ink_color.a * fade)
	var sheen := Color(_color[i].lightened(0.3).lerp(Color.WHITE, d.sheen_mix), d.sheen_alpha * fade)
	var thin := lerpf(0.55, 1.0, fade)  # 풀릴 때 가늘어진다
	for pass_i in 2:  # 먹 → 젖은 윤기 (가운데 가늘게)
		var col := ink if pass_i == 0 else sheen
		var wk := thin * (1.0 if pass_i == 0 else 0.35)
		for j in n:
			var u0 := float(j) / n
			var u1 := float(j + 1) / n
			if u0 >= shown:
				break
			u1 = minf(u1, shown)
			_quad(i, u0, u1, wk, col)
			_bt.tex_quad(_pts, _cols, _uvs)


## u0~u1 구간의 획 조각 꼭짓점 (붓 끝은 가늘게: 양 끝으로 갈수록 폭이 줄어든다).
func _quad(i: int, u0: float, u1: float, wk: float, col: Color) -> void:
	var d := data
	var o := _origin[i]
	var r := _range[i]
	var taper0 := pow(sin(PI * clampf(u0, 0.02, 0.98)), 0.6)
	var taper1 := pow(sin(PI * clampf(u1, 0.02, 0.98)), 0.6)
	match _shape[i]:
		1:  # 한 줄 곧은 획
			var dir := Vector2.from_angle(_angle[i])
			var side := dir.orthogonal()
			var a := o + dir * r * lerpf(d.streak_from, 1.0, u0)
			var b := o + dir * r * lerpf(d.streak_from, 1.0, u1)
			var h0 := d.streak_width * 0.5 * wk * taper0
			var h1 := d.streak_width * 0.5 * wk * taper1
			_pts[0] = a - side * h0
			_pts[1] = b - side * h1
			_pts[2] = b + side * h1
			_pts[3] = a + side * h0
		_:  # 부채꼴·고리: 판정 각도를 따라 휘어진 획
			var ring := _shape[i] == 2
			var mid := r * (d.ring_mid if ring else d.arc_mid)
			var w := (d.ring_width if ring else d.arc_width) * 0.5 * wk
			if ring:
				taper0 = 0.6 + 0.4 * taper0
				taper1 = 0.6 + 0.4 * taper1
			var start := _angle[i] - _arc[i] * 0.5 if not ring else _angle[i]
			var a0 := start + _arc[i] * u0
			var a1 := start + _arc[i] * u1
			var v0 := Vector2.from_angle(a0)
			var v1 := Vector2.from_angle(a1)
			_pts[0] = o + v0 * (mid - w * taper0)
			_pts[1] = o + v1 * (mid - w * taper1)
			_pts[2] = o + v1 * (mid + w * taper1)
			_pts[3] = o + v0 * (mid + w * taper0)
	_uvs[0] = Vector2(u0, 1.0)
	_uvs[1] = Vector2(u1, 1.0)
	_uvs[2] = Vector2(u1, 0.0)
	_uvs[3] = Vector2(u0, 0.0)
	for k in 4:
		_cols[k] = col
