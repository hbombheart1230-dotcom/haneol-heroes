class_name DeathFx
extends Node2D
## 속성별 처치 모습 (DeathStyleData): 물 = 번지며 씻겨 내려가는 물 얼룩·물 조각·젖은 자국, 번개 = 번쩍 → 재·먼지·금 간 자국,
## 글자 = 자모 획과 금빛 별이 떠오름, 먹 = 먹 방울(KillFx)과 꽃잎. 조각·자국은 칸을 미리 잡아 돌려 쓰고 (상한 max_bits·max_marks)
## 프레임마다 배열을 만들지 않는다.

enum Bit { TEX, GLYPH, BLOB, FLASH }

var data: DeathStyleData
## 조각
var _b_kind := PackedInt32Array()
var _b_pos := PackedVector2Array()
var _b_vel := PackedVector2Array()
var _b_t := PackedFloat32Array()
var _b_life := PackedFloat32Array()
var _b_size := PackedFloat32Array()
var _b_rot := PackedFloat32Array()
var _b_spin := PackedFloat32Array()
var _b_grav := PackedFloat32Array()
var _b_color := PackedColorArray()
var _b_glyph := PackedStringArray()
var _b_tex: Array[Texture2D] = []
var _b_next: int = 0
## 바닥 자국 (물 얼룩·젖은 자국·금 간 자국)
var _m_pos := PackedVector2Array()
var _m_t := PackedFloat32Array()
var _m_life := PackedFloat32Array()
var _m_size := PackedFloat32Array()
var _m_grow := PackedFloat32Array()
var _m_slide := PackedFloat32Array()
var _m_rot := PackedFloat32Array()
var _m_color := PackedColorArray()
var _m_tex: Array[Texture2D] = []
var _m_next: int = 0


func _init(p_data: DeathStyleData = null) -> void:
	data = p_data if p_data else DeathStyleData.new()
	var n := maxi(data.max_bits, 1)
	_b_kind.resize(n)
	_b_pos.resize(n)
	_b_vel.resize(n)
	_b_t.resize(n)
	_b_life.resize(n)
	_b_size.resize(n)
	_b_rot.resize(n)
	_b_spin.resize(n)
	_b_grav.resize(n)
	_b_color.resize(n)
	_b_glyph.resize(n)
	_b_tex.resize(n)
	for i in n:
		_b_t[i] = -1.0
	var m := maxi(data.max_marks, 1)
	_m_pos.resize(m)
	_m_t.resize(m)
	_m_life.resize(m)
	_m_size.resize(m)
	_m_grow.resize(m)
	_m_slide.resize(m)
	_m_rot.resize(m)
	_m_color.resize(m)
	_m_tex.resize(m)
	for i in m:
		_m_t[i] = -1.0


func bit_count() -> int:
	var n := 0
	for t in _b_t:
		if t >= 0.0:
			n += 1
	return n


func mark_count() -> int:
	var n := 0
	for t in _m_t:
		if t >= 0.0:
			n += 1
	return n


## 처치 한 번: pos = 쓰러진 몸, element = water·thunder·glyph·ink, big = 큰 처치.
func burst(pos: Vector2, element: StringName, big: bool) -> void:
	var d := data
	var k := d.size_k(big)
	var tk := d.time_k(big)
	match element:
		&"water":
			_mark(pos, d.water_stain, d.water_bloom * k, 0.6, d.water_slide * k, d.water_bloom_time * tk, Color(d.water_color, 0.75))
			_mark(pos, d.water_stain, d.water_bloom * 0.9 * k, 0.15, 0.0, d.water_stain_time * tk, Color(d.water_color.darkened(0.5), 0.35))
			for i in d.count(d.water_bits, big):
				var v := Vector2.from_angle(randf_range(-PI * 0.95, -PI * 0.05)) * randf_range(120.0, 280.0) * k
				_bit(Bit.TEX, pos + Vector2(0, -24), v, randf_range(0.35, 0.55) * tk, randf_range(28.0, 48.0) * k,
					700.0, Color.WHITE, _pick(d.water_parts), "")
		&"thunder":
			_bit(Bit.FLASH, pos + Vector2(0, -30), Vector2.ZERO, d.flash_time, d.flash_radius * k, 0.0, d.flash_color, null, "")
			_mark(pos, d.crack_art, d.crack_size * k, 0.1, 0.0, d.crack_time * tk, d.crack_color)
			for i in d.count(d.ash_bits, big):
				var v := Vector2(randf_range(-70.0, 70.0), randf_range(-150.0, -40.0)) * k
				_bit(Bit.TEX, pos + Vector2(randf_range(-18.0, 18.0), randf_range(-50.0, -10.0)), v,
					randf_range(0.55, 0.85) * tk, randf_range(16.0, 28.0) * k, 90.0, d.ash_color, _pick(d.ash_parts), "")
		&"glyph":
			for i in d.count(d.glyph_bits, big):
				var v := Vector2(randf_range(-60.0, 60.0), randf_range(-150.0, -70.0)) * k
				var g := d.glyphs[randi() % maxi(d.glyphs.length(), 1)] if d.glyphs != "" else "ㅇ"
				_bit(Bit.GLYPH, pos + Vector2(randf_range(-20.0, 20.0), randf_range(-60.0, -20.0)), v,
					randf_range(0.6, 0.9) * tk, randf_range(30.0, 44.0) * k, -40.0, d.glyph_color, null, g)
			for i in d.count(d.star_bits, big):
				var v := Vector2.from_angle(randf() * TAU) * randf_range(40.0, 120.0) * k + Vector2(0, -60.0)
				_bit(Bit.TEX, pos + Vector2(0, -36), v, randf_range(0.4, 0.6) * tk, randf_range(28.0, 42.0) * k,
					0.0, Color.WHITE, d.star_art, "")
		&"ink":
			var petal := VfxTextures.get_texture(SkillVfxData.Shape.PETAL)
			for i in d.count(d.petal_bits, big):
				var v := Vector2.from_angle(TAU * (i + randf() * 0.6) / d.count(d.petal_bits, big)) * randf_range(180.0, 300.0) * k 					+ Vector2(0, -120.0)  # 사방으로 흩날린 뒤 천천히 떨어진다
				_bit(Bit.TEX, pos + Vector2(randf_range(-12.0, 12.0), randf_range(-44.0, -20.0)), v,
					randf_range(0.7, 1.0) * tk, randf_range(20.0, 30.0) * k, 160.0, d.petal_color, petal, "")
			var fb := Feedback.instance
			if fb and fb.kill_fx:
				fb.kill_fx.drops(pos, Vector2.UP, d.count(d.ink_drops, big))


static func _pick(list: Array[Texture2D]) -> Texture2D:
	return list[randi() % list.size()] if not list.is_empty() else null


func _bit(kind: Bit, pos: Vector2, vel: Vector2, life: float, size: float, grav: float, color: Color,
		tex: Texture2D, glyph: String) -> void:
	if kind == Bit.TEX and tex == null:
		kind = Bit.BLOB
	var i := _b_next
	_b_next = (_b_next + 1) % _b_t.size()
	_b_kind[i] = kind
	_b_pos[i] = pos
	_b_vel[i] = vel
	_b_t[i] = 0.0
	_b_life[i] = maxf(life, 0.01)
	_b_size[i] = size
	_b_rot[i] = randf() * TAU
	_b_spin[i] = randf_range(-6.0, 6.0)
	_b_grav[i] = grav
	_b_color[i] = color
	_b_tex[i] = tex
	_b_glyph[i] = glyph


func _mark(pos: Vector2, tex: Texture2D, size: float, grow: float, slide: float, life: float, color: Color) -> void:
	var i := _m_next
	_m_next = (_m_next + 1) % _m_t.size()
	_m_pos[i] = pos
	_m_t[i] = 0.0
	_m_life[i] = maxf(life, 0.01)
	_m_size[i] = size
	_m_grow[i] = grow
	_m_slide[i] = slide
	_m_rot[i] = randf() * TAU
	_m_color[i] = color
	_m_tex[i] = tex


func _process(delta: float) -> void:
	step(delta)
	queue_redraw()


func step(delta: float) -> void:
	for i in _b_t.size():
		if _b_t[i] < 0.0:
			continue
		_b_t[i] += delta
		if _b_t[i] >= _b_life[i]:
			_b_t[i] = -1.0
			_b_tex[i] = null
			continue
		_b_vel[i] = _b_vel[i] * maxf(1.0 - 2.5 * delta, 0.0) + Vector2(0, _b_grav[i]) * delta
		_b_pos[i] += _b_vel[i] * delta
		_b_rot[i] += _b_spin[i] * delta
	for i in _m_t.size():
		if _m_t[i] < 0.0:
			continue
		_m_t[i] += delta
		if _m_t[i] >= _m_life[i]:
			_m_t[i] = -1.0
			_m_tex[i] = null


func _draw() -> void:
	for i in _m_t.size():  # 바닥 자국 먼저 (세로로 눌러 바닥에 깐다)
		if _m_t[i] < 0.0:
			continue
		var k := _m_t[i] / _m_life[i]
		var s := _m_size[i] * (1.0 + _m_grow[i] * (1.0 - pow(1.0 - k, 2.0)))
		var c := _m_color[i]
		c.a *= 1.0 - k * k
		var at := _m_pos[i] + Vector2(0, _m_slide[i] * k)
		if _m_tex[i]:
			draw_set_transform(at, 0.0, Vector2(1.0, 0.5))
			draw_texture_rect(_m_tex[i], Rect2(-s * 0.5, -s * 0.5, s, s), false, c)
		else:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			Ink.splash(self, at, s * 0.4, c, _m_rot[i])
	for i in _b_t.size():
		if _b_t[i] < 0.0:
			continue
		var k := _b_t[i] / _b_life[i]
		var c := _b_color[i]
		c.a *= 1.0 - k * k
		var s := _b_size[i]
		match _b_kind[i]:
			Bit.TEX:
				var tex := _b_tex[i]
				draw_set_transform(_b_pos[i], _b_rot[i], Vector2.ONE * (1.0 - 0.3 * k))
				var h := s * tex.get_height() / maxf(tex.get_width(), 1.0)
				draw_texture_rect(tex, Rect2(-s * 0.5, -h * 0.5, s, h), false, c)
			Bit.GLYPH:
				draw_set_transform(_b_pos[i], 0.0, Vector2.ONE)
				UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(-s * 0.5, s * 0.35), _b_glyph[i], int(s), c, s,
					Color(0, 0, 0, 0.6 * c.a), maxi(roundi(s / 9.0), 2))
			Bit.BLOB:
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				draw_circle(_b_pos[i], s * 0.35 * (1.0 - 0.4 * k), c)
			Bit.FLASH:  # 부드러운 빛 덩이 (평평한 원판이 아니게) + 가는 흰 심
				var dot := VfxTextures.get_texture(SkillVfxData.Shape.DOT)
				var r := s * (0.8 + 0.7 * k)
				draw_set_transform(_b_pos[i], 0.0, Vector2(1.0, 1.25))
				draw_texture_rect(dot, Rect2(-r, -r, r * 2.0, r * 2.0), false, Color(c, 0.85 * c.a))
				var star := VfxTextures.get_texture(SkillVfxData.Shape.STAR)
				var rs := s * 0.9 * (1.0 - 0.5 * k)
				draw_set_transform(_b_pos[i], _b_rot[i], Vector2.ONE)
				draw_texture_rect(star, Rect2(-rs, -rs, rs * 2.0, rs * 2.0), false, Color(1, 1, 1, c.a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
