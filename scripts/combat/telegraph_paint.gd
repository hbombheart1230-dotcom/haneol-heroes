class_name TelegraphPaint
extends RefCounted
## 적 근접 예고 영역 그리기 (EnemyArt.telegraph_part가 부른다): 원(SLAM·SHOCKWAVE)·부채(CONE)·띠(CHARGE·PULL·THRUST).
## 그림새는 TelegraphStyleData.look — (가) 지금 / (나) 먹 번짐 + 붉은 테 / (다) 탁한 인주 + 한지 결 + 먹 테.
## 모양·크기는 공격 데이터 그대로 (판정과 같은 자리). c는 적과 같은 좌표계. 채움(FILL)은 바닥, 테(RIM)는 TelegraphRim 층.
## 먹 번짐 그림은 InkPaint의 것 (assets/vfx/ink_wash*.png)을 다시 쓴다.

const SQUASH := 0.6  # 원 예고는 바닥 원근으로 납작 (Ink.blob·Ink.ring과 같게)
## 한지 결 채움: 먹 번짐 사각 그림의 가운데만 쓴다 (가장자리 흐림 없이 결만).
const GRAIN_UV := Rect2(0.08, 0.2, 0.84, 0.6)


## 공통 진입: shape = 원 [중심, 반지름] / 다각형 (부채·띠). grow(0~1) = 차오른 정도 (부채·띠는 번짐에만 쓴다).
static func circle(c: CanvasItem, center: Vector2, radius: float, k: float, flash: bool, fill: bool, rim: bool, seed: float) -> void:
	var s := TelegraphStyleData.default()
	match s.look:
		TelegraphStyleData.NOW:
			if fill:
				Ink.blob(c, center, radius * k, _now_fill(s, k, flash), seed, 0.06, SQUASH)
			if rim:
				Ink.ring(c, center, radius, 4.0, _now_edge(s, flash))
		TelegraphStyleData.DULL_SEAL:
			if fill:
				_tex_poly(c, _blob(center, radius * k, seed), Color(s.seal_dull, _dull_alpha(s, k, flash)))
			if rim:
				Ink.ring(c, center, radius, s.dull_rim_width + s.dull_ink_extra, Color(s.ink_color, s.dull_ink_alpha))
				Ink.ring(c, center, radius, s.dull_rim_width, _dull_edge(s, flash))
		_:
			if fill:
				_ellipse_wash(c, center, radius, Color(Ink.PAPER, s.paper_under_alpha))
				_ellipse_wash(c, center, radius * _bleed(s, k), Color(s.ink_color, _ink_alpha(s, k)))
				if flash:
					_ellipse_wash(c, center, radius, Color(s.seal_dull, s.stamp_alpha))
			if rim:
				var w := s.rim_width * (s.stamp_rim_mult if flash else 1.0)
				Ink.ring(c, center, radius, w + s.shadow_extra, Color(s.ink_color, s.shadow_alpha))
				Ink.ring(c, center, radius, w, _bleed_edge(s, flash))
				Ink.ring(c, center, radius, s.core_width, Color(Ink.PAPER, s.core_alpha))


## 부채: origin에서 aim 방향 반각 half, 반지름 radius.
static func cone(c: CanvasItem, origin: Vector2, a0: float, half: float, radius: float, k: float, flash: bool, fill: bool, rim: bool) -> void:
	var s := TelegraphStyleData.default()
	var full := _sector(origin, a0, half, radius)
	if fill:
		match s.look:
			TelegraphStyleData.NOW:
				c.draw_colored_polygon(full, _now_fill(s, k, flash))
			TelegraphStyleData.DULL_SEAL:
				_tex_poly(c, full, Color(s.seal_dull, _dull_alpha(s, k, flash)))
			_:
				_tex_poly(c, full, Color(Ink.PAPER, s.paper_under_alpha))
				_tex_poly(c, _sector(origin, a0, half, radius * _bleed(s, k)), Color(s.ink_color, _ink_alpha(s, k)))
				if flash:
					_tex_poly(c, full, Color(s.seal_dull, s.stamp_alpha))
	if rim:
		full.append(origin)
		_outline(c, full, s, flash)


## 띠: back → front (가운데 줄), 폭의 반 n (수직 벡터).
static func band(c: CanvasItem, back: Vector2, front: Vector2, n: Vector2, k: float, flash: bool, fill: bool, rim: bool) -> void:
	var s := TelegraphStyleData.default()
	var full := PackedVector2Array([back + n, front + n, front - n, back - n])
	if fill:
		match s.look:
			TelegraphStyleData.NOW:
				c.draw_colored_polygon(full, _now_fill(s, k, flash))
			TelegraphStyleData.DULL_SEAL:
				_tex_poly(c, full, Color(s.seal_dull, _dull_alpha(s, k, flash)))
			_:
				_tex_poly(c, full, Color(Ink.PAPER, s.paper_under_alpha))
				var f := back.lerp(front, _bleed(s, k))  # 뒤(적 쪽)에서 앞으로 번진다
				_tex_poly(c, PackedVector2Array([back + n, f + n, f - n, back - n]), Color(s.ink_color, _ink_alpha(s, k)))
				if flash:
					_tex_poly(c, full, Color(s.seal_dull, s.stamp_alpha))
	if rim:
		full.append(back + n)
		_outline(c, full, s, flash)


## 닫힌 선 테 (부채·띠): 그림새마다.
static func _outline(c: CanvasItem, pts: PackedVector2Array, s: TelegraphStyleData, flash: bool) -> void:
	match s.look:
		TelegraphStyleData.NOW:
			c.draw_polyline(pts, _now_edge(s, flash), 4.0)
		TelegraphStyleData.DULL_SEAL:
			c.draw_polyline(pts, Color(s.ink_color, s.dull_ink_alpha), s.dull_rim_width + s.dull_ink_extra)
			c.draw_polyline(pts, _dull_edge(s, flash), s.dull_rim_width)
		_:
			var w := s.rim_width * (s.stamp_rim_mult if flash else 1.0)
			c.draw_polyline(pts, Color(s.ink_color, s.shadow_alpha), w + s.shadow_extra)
			c.draw_polyline(pts, _bleed_edge(s, flash), w)
			c.draw_polyline(pts, Color(Ink.PAPER, s.core_alpha), s.core_width)


static func _now_fill(s: TelegraphStyleData, k: float, flash: bool) -> Color:
	return Color(s.seal_bright, (0.12 + 0.3 * k) + (0.2 if flash else 0.0))


static func _now_edge(s: TelegraphStyleData, flash: bool) -> Color:
	return Color(s.seal_bright.lightened(0.45), 1.0) if flash else Color(s.seal_bright, 0.85)


static func _dull_alpha(s: TelegraphStyleData, k: float, flash: bool) -> float:
	return s.fill_base + s.fill_gain * k + (s.fill_flash if flash else 0.0)


static func _dull_edge(s: TelegraphStyleData, flash: bool) -> Color:
	return Color(s.seal_dull.lightened(s.stamp_lighten), 1.0) if flash else Color(s.seal_dull, 0.9)


static func _bleed_edge(s: TelegraphStyleData, flash: bool) -> Color:
	return Color(s.seal_dull.lightened(s.stamp_lighten), 1.0) if flash else Color(s.seal_dull, s.rim_alpha)


static func _bleed(s: TelegraphStyleData, k: float) -> float:
	return lerpf(s.bleed_start, 1.0, clampf(k, 0.0, 1.0))


static func _ink_alpha(s: TelegraphStyleData, k: float) -> float:
	return lerpf(s.ink_alpha.x, s.ink_alpha.y, clampf(k, 0.0, 1.0))


static func _sector(origin: Vector2, a0: float, half: float, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array([origin])
	for i in 17:
		pts.append(origin + Vector2.from_angle(a0 - half + 2.0 * half * i / 16.0) * radius)
	return pts


static func _blob(center: Vector2, radius: float, seed: float) -> PackedVector2Array:
	var pts := Ink.unit_blob(seed, 0.06, SQUASH)
	for i in pts.size():
		pts[i] = center + pts[i] * radius
	return pts


## 먹 번짐 원판을 바닥 원근으로 납작하게 (가장자리가 번진 그림).
static func _ellipse_wash(c: CanvasItem, center: Vector2, radius: float, col: Color) -> void:
	if radius <= 0.5:
		return
	c.draw_texture_rect(InkPaint.WASH, Rect2(center - Vector2(radius, radius * SQUASH), Vector2(radius, radius * SQUASH) * 2.0), false, col)


## 한지 결 있는 채움: 다각형에 먹 번짐 사각 그림의 결을 입힌다 (모양은 그대로).
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
