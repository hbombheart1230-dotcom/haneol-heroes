class_name RangedFxLayer
extends Node2D
## 원거리 한 발의 그림 (RangedFeel): 손·무기 끝 섬광, 맞은 탄이 부서져 흩어짐, 빗나간 탄이 먹으로 풀림.
## 칸을 미리 잡아 두고 돌려 쓴다 (RangedFeelData.max_active, 넘치면 가장 오래된 칸을 덮음). 프레임마다 배열을 만들지 않는다.

enum Kind { MUZZLE, BURST, FIZZLE }

const CORE := Color(1.0, 0.98, 0.9, 1.0)
const INK := Color(0.08, 0.06, 0.05, 0.85)

var data: RangedFeelData
var _kind := PackedInt32Array()
var _pos := PackedVector2Array()
var _dir := PackedVector2Array()
var _t := PackedFloat32Array()
var _step := PackedInt32Array()
var _color := PackedColorArray()
var _size := PackedVector2Array()
var _seed := PackedFloat32Array()
var _glyph := PackedStringArray()
var _tex: Array[Texture2D] = []
var _next: int = 0
var _active: int = 0


func _init(p_data: RangedFeelData = null) -> void:
	data = p_data if p_data else RangedFeelData.new()
	var n := maxi(data.max_active, 1)
	_kind.resize(n)  # Packed 배열은 값이라 하나씩 늘린다
	_pos.resize(n)
	_dir.resize(n)
	_t.resize(n)
	_step.resize(n)
	_color.resize(n)
	_size.resize(n)
	_seed.resize(n)
	_glyph.resize(n)
	_tex.resize(n)
	for i in n:
		_t[i] = -1.0
	z_as_relative = false
	z_index = 21  # 접점 섬광(HitImpactLayer, 20) 바로 위: 부서지는 탄이 섬광에 묻히지 않게


func active_count() -> int:
	return _active


func capacity() -> int:
	return _t.size()


## 쏘는 순간: 무기 끝에서 앞으로 뻗는 작은 섬광.
func muzzle(pos: Vector2, dir: Vector2, step: int, color: Color) -> void:
	_add(Kind.MUZZLE, pos, dir, step, color, null, Vector2.ZERO, "")


## 맞은 탄: 그 그림(또는 글자)이 앞으로 부풀며 갈라져 흩어진다.
func burst(pos: Vector2, dir: Vector2, step: int, color: Color, tex: Texture2D, size: Vector2, glyph: String) -> void:
	_add(Kind.BURST, pos, dir, step, color, tex, size, glyph)


## 빗나간 탄: 작아지며 먹색으로 풀려 사라진다.
func fizzle(pos: Vector2, dir: Vector2, color: Color, tex: Texture2D, size: Vector2, glyph: String) -> void:
	_add(Kind.FIZZLE, pos, dir, 1, color, tex, size, glyph)


func _add(kind: Kind, pos: Vector2, dir: Vector2, step: int, color: Color, tex: Texture2D, size: Vector2,
		glyph: String) -> void:
	var i := _next
	_next = (_next + 1) % _t.size()
	if _t[i] < 0.0:
		_active += 1
	_kind[i] = kind
	_pos[i] = pos
	_dir[i] = dir.normalized() if dir.length_squared() > 0.0001 else Vector2.RIGHT
	_t[i] = 0.0
	_step[i] = clampi(step, 1, 3)
	_color[i] = color
	_tex[i] = tex
	_size[i] = size
	_glyph[i] = glyph
	_seed[i] = randf() * TAU
	queue_redraw()


func duration_of(kind: int) -> float:
	match kind:
		Kind.MUZZLE:
			return data.muzzle_time
		Kind.BURST:
			return data.burst_time
	return data.fizzle_time


func _process(delta: float) -> void:
	if _active <= 0:
		return
	step(delta)
	queue_redraw()


func step(delta: float) -> void:
	for i in _t.size():
		if _t[i] < 0.0:
			continue
		_t[i] += delta
		if _t[i] >= duration_of(_kind[i]):
			_t[i] = -1.0
			_tex[i] = null
			_active -= 1


func _draw() -> void:
	for i in _t.size():
		if _t[i] < 0.0:
			continue
		var k := clampf(_t[i] / maxf(duration_of(_kind[i]), 0.001), 0.0, 1.0)
		match _kind[i]:
			Kind.MUZZLE:
				_draw_muzzle(i, k)
			Kind.BURST:
				_draw_shot(i, k, true)
			Kind.FIZZLE:
				_draw_shot(i, k, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_muzzle(i: int, k: float) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)  # 앞 칸(탄 그림·글자)이 옮기고 늘린 그리기 좌표를 되돌린다
	var s := _step[i]
	var p := _pos[i]
	var core := HitImpactData.at_f(data.muzzle_core, s, 12.0)
	var n := HitImpactData.at_i(data.muzzle_streaks, s, 3)
	var length := HitImpactData.at_f(data.muzzle_length, s, 26.0) * (0.5 + 0.5 * sqrt(k))
	var spread := deg_to_rad(data.muzzle_spread_deg)
	var fade := 1.0 - k
	var col := _color[i].lightened(0.45)
	for j in n:  # 먹 테두리 → 색 줄기 (붓 끝처럼 앞으로 튐)
		var a := -spread * 0.5 + spread * (j + 0.5 + 0.25 * sin(_seed[i] + j * 1.9)) / n
		var v := _dir[i].rotated(a)
		var to := p + v * (core * 0.5 + length * (0.75 + 0.25 * cos(_seed[i] + j)))
		draw_line(p + v * core * 0.3, to, Color(INK, INK.a * fade), 7.0 * fade + 1.0)
		draw_line(p + v * core * 0.3, to, Color(col, fade), 4.0 * fade + 0.5)
	var ck := 1.0 - pow(k, 0.6)
	draw_circle(p, core * (0.6 + 0.6 * k), Color(col, 0.5 * ck))
	draw_circle(p, core * 0.55 * ck + 1.0, Color(CORE, ck))


## 탄 그림(또는 글자): 맞으면 앞으로 부풀며 위아래로 갈라져 흩어지고, 빗나가면 작아지며 먹색으로 풀린다.
func _draw_shot(i: int, k: float, hit: bool) -> void:
	var p := _pos[i]
	var d := _dir[i]
	var fade := 1.0 - k
	var grow := lerpf(1.0, data.burst_grow, 1.0 - pow(1.0 - k, 2.0)) if hit else lerpf(1.0, 0.7, k)
	var tint := Color.WHITE.lerp(_color[i].lightened(0.5), k * 0.6) if hit else Color.WHITE.lerp(INK, k)
	var tex := _tex[i]
	if tex:
		var sz := _size[i] * grow
		var rect := Rect2(-sz.x * 0.6, -sz.y * 0.5, sz.x, sz.y)
		if hit:  # 위아래 반쪽이 벌어지며 적을 지나 앞으로 흩어진다 (가운데 한 장은 금방 사라짐)
			var gap := _size[i].y * 0.6 * k
			for side in 2:
				var off := Vector2(_size[i].x * 0.55 * k, gap * (1.0 if side == 1 else -1.0)).rotated(d.angle())
				draw_set_transform(p + off, d.angle() + (0.35 if side == 1 else -0.35) * k, Vector2(1.0, 0.6))
				draw_texture_rect(tex, rect, false, Color(tint, 0.9 * fade))
			fade *= fade
		draw_set_transform(p, d.angle(), Vector2.ONE)
		draw_texture_rect(tex, rect, false, Color(tint, fade * 0.9))
	elif _glyph[i] != "":
		var px := maxi(int(_size[i].x), 8)  # 글꼴은 탄 글자 크기 그대로, 커지는 것은 늘려 그린다 (새 글꼴 크기 = 첫 사용 멈칫)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if hit:  # 글자 밑으로 먹이 번진다
			Ink.splash(self, p, _size[i].x * data.glyph_bloom * (0.6 + 0.8 * k), Color(INK, data.glyph_bloom_alpha * fade), _seed[i])
		draw_set_transform(p, 0.0, Vector2.ONE * grow)
		UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(-px * 0.5, px * 0.35), _glyph[i], px,
			Color(UiStyle.GOLD.lerp(tint, 0.5), fade), float(px), Color(0, 0, 0, 0.7 * fade), maxi(roundi(px / 8.0), 3))
