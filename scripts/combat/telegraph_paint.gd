class_name TelegraphPaint
extends RefCounted
## 적 근접 예고 영역 그리기 (EnemyArt.telegraph_part가 부른다): 원(SLAM·SHOCKWAVE)·부채(CONE)·띠(CHARGE·PULL·THRUST).
## 그림새는 TelegraphStyleData.look — (가) 지금 / (바) 먹 붓 테 + 먹 번짐 (인주 조금·더).
## 붓 테: 판정 경계를 따라 짧은 붓 획(InkPaint.EDGE 그림)을 이어 긋되 굵기가 들쭉날쭉하고 군데군데 끊긴다 (마른 붓).
## 그 아래 한지색 밑획(어두운 바닥), 위에 가는 속심 — 속심이 가장 또렷한 선이고 정확히 판정 경계 위다 (보이는 가장자리 = 맞는 가장자리).
## 모양·크기는 공격 데이터 그대로. c는 적과 같은 좌표계. 채움(FILL)은 바닥, 테(RIM)는 TelegraphRim 층 (z 22).

const SQUASH := 0.6  # 원 예고는 바닥 원근으로 납작 (Ink.blob·Ink.ring과 같게)
## 번짐 결 채움: 먹 번짐 사각 그림의 가운데만 쓴다 (가장자리 흐림 없이 결만).
const GRAIN_UV := Rect2(0.08, 0.2, 0.84, 0.6)


static func circle(c: CanvasItem, center: Vector2, radius: float, k: float, flash: bool, fill: bool, rim: bool, seed: float) -> void:
	var s := TelegraphStyleData.default()
	if s.look == TelegraphStyleData.NOW:
		if fill:
			Ink.blob(c, center, radius * k, _now_fill(s, k, flash), seed, 0.06, SQUASH)
		if rim:
			Ink.ring(c, center, radius, 4.0, _now_edge(s, flash))
		return
	if fill:
		_ellipse_wash(c, center, radius, Color(Ink.PAPER, s.paper_under_alpha))
		_ellipse_wash(c, center, radius * _bleed(s, k), Color(s.fill_color(), _ink_alpha(s, k)))  # 가운데서 번진다
	if rim:
		var n := maxi(24, int(TAU * radius * 0.8 / s.seg_px))
		var pts := PackedVector2Array()
		for i in n + 1:
			var a := TAU * i / n
			pts.append(center + Vector2(cos(a), sin(a) * SQUASH) * radius)
		_brush(c, pts, s, flash, seed)
		_stamp(c, center + Vector2(cos(-0.8), sin(-0.8) * SQUASH) * radius, s, k, flash)


## 부채: origin에서 aim 방향 a0, 반각 half, 반지름 radius.
static func cone(c: CanvasItem, origin: Vector2, a0: float, half: float, radius: float, k: float, flash: bool, fill: bool, rim: bool) -> void:
	var s := TelegraphStyleData.default()
	var full := _sector(origin, a0, half, radius)
	if s.look == TelegraphStyleData.NOW:
		if fill:
			c.draw_colored_polygon(full, _now_fill(s, k, flash))
		if rim:
			full.append(origin)
			c.draw_polyline(full, _now_edge(s, flash), 4.0)
		return
	if fill:
		_tex_poly(c, full, Color(Ink.PAPER, s.paper_under_alpha))
		_tex_poly(c, _sector(origin, a0, half, radius * _bleed(s, k)), Color(s.fill_color(), _ink_alpha(s, k)))  # 적 쪽에서 번진다
	if rim:
		full.append(origin)
		_brush(c, _dense(full, s.seg_px), s, flash, 5.0)
		_stamp(c, origin + Vector2.from_angle(a0) * radius, s, k, flash)


## 띠: back → front (가운데 줄), 폭의 반 n (수직 벡터).
static func band(c: CanvasItem, back: Vector2, front: Vector2, n: Vector2, k: float, flash: bool, fill: bool, rim: bool) -> void:
	var s := TelegraphStyleData.default()
	var full := PackedVector2Array([back + n, front + n, front - n, back - n])
	if s.look == TelegraphStyleData.NOW:
		if fill:
			c.draw_colored_polygon(full, _now_fill(s, k, flash))
		if rim:
			full.append(back + n)
			c.draw_polyline(full, _now_edge(s, flash), 4.0)
		return
	if fill:
		_tex_poly(c, full, Color(Ink.PAPER, s.paper_under_alpha))
		var f := back.lerp(front, _bleed(s, k))  # 뒤(적 쪽)에서 앞으로 번진다
		_tex_poly(c, PackedVector2Array([back + n, f + n, f - n, back - n]), Color(s.fill_color(), _ink_alpha(s, k)))
	if rim:
		full.append(back + n)
		_brush(c, _dense(full, s.seg_px), s, flash, 7.0)
		_stamp(c, front, s, k, flash)


static func _bleed(s: TelegraphStyleData, k: float) -> float:
	return lerpf(s.bleed_start, 1.0, clampf(k, 0.0, 1.0))


static func _ink_alpha(s: TelegraphStyleData, k: float) -> float:
	return lerpf(s.ink_alpha.x, s.ink_alpha.y, clampf(k, 0.0, 1.0))


## 먹 번짐 원판을 바닥 원근으로 납작하게 (가장자리가 번진 그림, InkPaint.WASH).
static func _ellipse_wash(c: CanvasItem, center: Vector2, radius: float, col: Color) -> void:
	if radius <= 0.5:
		return
	c.draw_texture_rect(InkPaint.WASH, Rect2(center - Vector2(radius, radius * SQUASH), Vector2(radius, radius * SQUASH) * 2.0), false, col)


## 마른 붓 테: pts(판정 경계를 따라 촘촘한 점)를 짧은 붓 획으로. 끊김·굵기는 자리마다 고정 (프레임마다 같은 모양).
static func _brush(c: CanvasItem, pts: PackedVector2Array, s: TelegraphStyleData, flash: bool, seed: float) -> void:
	var w := s.brush_width * (s.flash_width_mult if flash else 1.0)
	var col := Color(s.ink_color.lerp(s.seal_dull, s.rim_tint), s.flash_alpha if flash else s.brush_alpha)
	var dark := s.dark_floor()  # 어두운 바닥: 한지색 밑획·속심을 키워 먹 선을 띄운다
	var under := Color(Ink.PAPER, s.dark_under_alpha if dark else s.under_alpha)
	var extra := s.dark_under_extra if dark else s.under_extra
	var gaps := s.gap_rate * (0.3 if flash else 1.0)  # 짙어질 땐 끊김도 줄어든다
	var runs: Array = []  # 끊기지 않은 토막 묶음 [시작, 끝] (점 번호)
	var start := -1
	for i in pts.size() - 1:
		var on := _wave(i, seed + 31.0, 0.33) >= gaps  # 끊김은 몇 토막씩 이어서 (마른 붓이 뜨는 자리)
		if on and start < 0:
			start = i
		elif not on and start >= 0:
			runs.append([start, i])
			start = -1
	if start >= 0:
		runs.append([start, pts.size() - 1])
	for r in runs:
		_ribbon(c, pts, r[0], r[1], w + extra, under, s, seed)
	for r in runs:
		_ribbon(c, pts, r[0], r[1], w, col, s, seed)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	c.draw_polyline(pts, Color(Ink.PAPER, s.dark_core_alpha if dark else s.core_alpha),
		s.dark_core_width if dark else s.core_width)  # 판정 경계: 가장 또렷한 선


## 낙관 점: 기본은 치기 직전에만 (stamp_idle 0). 찍힐 때 짙고 조금 크게.
static func _stamp(c: CanvasItem, at: Vector2, s: TelegraphStyleData, k: float, flash: bool) -> void:
	var alpha := s.stamp_flash_alpha if flash else s.stamp_idle * clampf(k * 1.5, 0.0, 1.0)
	if alpha <= 0.01:
		return
	var px := s.stamp_px * (s.stamp_flash_scale if flash else 1.0)
	c.draw_set_transform(at, 0.18, Vector2.ONE)
	c.draw_rect(Rect2(-px * 0.5, -px * 0.5, px, px), Color(s.seal_dull, alpha))
	c.draw_rect(Rect2(-px * 0.3, -px * 0.3, px * 0.6, px * 0.6), Color(Ink.PAPER, alpha * 0.45), false, 1.5)  # 도장 안 글자 자리
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 붓 한 획: pts[i0..i1]을 따라 이어진 띠 (굵기는 획을 따라 출렁, 양 끝은 가늘게), 붓 획 그림(InkPaint.EDGE)을 길이로 늘여 입힌다.
static func _ribbon(c: CanvasItem, pts: PackedVector2Array, i0: int, i1: int, w: float, col: Color, s: TelegraphStyleData,
		seed: float) -> void:
	var n := i1 - i0 + 1
	if n < 2:
		return
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var ul := PackedVector2Array()
	var ur := PackedVector2Array()
	for j in n:
		var i := i0 + j
		var d := (pts[mini(i + 1, i1)] - pts[maxi(i - 1, i0)]).normalized()
		var nrm := d.orthogonal()
		var t := float(j) / float(n - 1)
		var taper := minf(1.0, minf(t, 1.0 - t) * 4.0 + 0.25)  # 붓을 대고 떼는 끝
		var th := w * taper * (1.0 - s.brush_jitter * 0.5 + s.brush_jitter * _wave(i, seed, 0.5)) * 0.5
		left.append(pts[i] + nrm * th)
		right.append(pts[i] - nrm * th)
		ul.append(Vector2(t, 0.0))
		ur.append(Vector2(t, 1.0))
	right.reverse()
	ur.reverse()
	left.append_array(right)
	ul.append_array(ur)
	if Geometry2D.triangulate_polygon(left).is_empty():
		return  # 꼬인 띠 (아주 짧은 굽이) — 건너뛴다
	c.draw_polygon(left, PackedColorArray([col]), ul, InkPaint.EDGE)


## 0~1 부드러운 출렁임 (획을 따라 이웃 토막끼리 이어지게).
static func _wave(i: int, seed: float, freq: float) -> float:
	var x := float(i) * freq + seed
	return clampf(0.5 + 0.32 * sin(x) + 0.18 * sin(x * 2.3 + 1.7), 0.0, 1.0)


static func _hash(i: int, seed: float) -> float:
	var x := sin(float(i) * 12.9898 + seed * 78.233) * 43758.5453
	return x - floorf(x)


## 닫힌 꺾은선을 step(px)마다 잘게 (붓 획 한 토막 길이).
static func _dense(pts: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var n := maxi(1, int(a.distance_to(b) / step))
		for j in n:
			out.append(a.lerp(b, float(j) / n))
	out.append(pts[pts.size() - 1])
	return out


static func _now_fill(s: TelegraphStyleData, k: float, flash: bool) -> Color:
	return Color(s.seal_bright, (0.12 + 0.3 * k) + (0.2 if flash else 0.0))


static func _now_edge(s: TelegraphStyleData, flash: bool) -> Color:
	return Color(s.seal_bright.lightened(0.45), 1.0) if flash else Color(s.seal_bright, 0.85)


static func _sector(origin: Vector2, a0: float, half: float, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array([origin])
	for i in 17:
		pts.append(origin + Vector2.from_angle(a0 - half + 2.0 * half * i / 16.0) * radius)
	return pts


## 번짐 결 채움: 다각형에 먹 번짐 사각 그림의 결을 입힌다 (모양은 그대로).
static func _tex_poly(c: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3:
		return
	var box := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		box = box.expand(p)
	var size := Vector2(maxf(box.size.x, 1.0), maxf(box.size.y, 1.0))
	var uvs := PackedVector2Array()
	uvs.resize(pts.size())
	for i in pts.size():
		uvs[i] = GRAIN_UV.position + (pts[i] - box.position) / size * GRAIN_UV.size
	c.draw_polygon(pts, PackedColorArray([col]), uvs, InkPaint.WASH_RECT)
