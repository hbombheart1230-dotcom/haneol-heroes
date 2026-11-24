class_name HitImpactLayer
extends Node2D
## 무기가 닿는 자리의 한 타 충격 그림 (HitImpactData): 밝은 심(빛 번짐은 어두운 바닥에서 읽히는 만큼만) → 먹 외곽선을
## 두른 붓 줄기·먹 튐이 주. 3타·큰 기술은 영웅마다 다른 줄기 (물보라·번개와 흙·금빛 획·먹과 꽃잎, HeroData.impact_style).
## 닿기 직전 칼끝의 작은 흰 불꽃(spark)도 여기서. 고정 크기 고리 버퍼를 돌려 쓴다 (타격마다·프레임마다 할당 없음).

enum Style { INK, WATER, THUNDER, GOLD, PETAL }
const SPARK := 0  ## _step 값: 칼끝 불꽃 (충격이 아님)

var data: HitImpactData
var _pos := PackedVector2Array()
var _dir := PackedVector2Array()
var _t := PackedFloat32Array()
var _step := PackedInt32Array()
var _style := PackedInt32Array()
var _color := PackedColorArray()
var _seed := PackedFloat32Array()
var _bolt := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])  # 번개 줄기 점 (돌려 씀)
var _next: int = 0
var _active: int = 0
var _glow: Node2D


func _init(p_data: HitImpactData = null) -> void:
	data = p_data if p_data else HitImpactData.new()
	var n := maxi(data.max_active, 1)
	_pos.resize(n)
	_dir.resize(n)
	_t.resize(n)
	_seed.resize(n)
	_step.resize(n)
	_style.resize(n)
	_color.resize(n)
	for i in n:
		_t[i] = -1.0
	z_as_relative = false
	z_index = data.draw_z  # 검기(영웅 쪽) 위에 그린다
	_glow = Node2D.new()  # 심의 빛 번짐만 더하기 섞기로 (줄기·먹은 보통 섞기)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = m
	_glow.draw.connect(_draw_glow)
	add_child(_glow)


## 충격 하나 (dir = 맞은 쪽으로 밀리는 방향, step = 1~3타, style = 3타·큰 기술 줄기 모양).
func add(pos: Vector2, dir: Vector2, step: int, color: Color, style: int = Style.INK) -> void:
	_put(pos, dir, clampi(step, 1, 3), color, style)


## 닿기 직전 칼끝의 작은 흰 불꽃.
func add_spark(pos: Vector2) -> void:
	_put(pos, Vector2.RIGHT, SPARK, Color.WHITE, Style.INK)


func _put(pos: Vector2, dir: Vector2, step: int, color: Color, style: int) -> void:
	var i := _next
	_next = (_next + 1) % _t.size()
	if _t[i] < 0.0:
		_active += 1
	_pos[i] = pos
	_dir[i] = dir.normalized() if dir.length_squared() > 0.0001 else Vector2.RIGHT
	_t[i] = 0.0
	_step[i] = step
	_style[i] = style
	_color[i] = color
	_seed[i] = randf() * TAU
	queue_redraw()
	_glow.queue_redraw()


func active_count() -> int:
	return _active


func _life(i: int) -> float:
	return data.spark_time if _step[i] == SPARK else data.duration


func _process(delta: float) -> void:
	if _active <= 0:
		return
	for i in _t.size():
		if _t[i] < 0.0:
			continue
		_t[i] += delta
		if _t[i] >= _life(i):
			_t[i] = -1.0
			_active -= 1
	queue_redraw()
	_glow.queue_redraw()


func _draw() -> void:
	for i in _t.size():
		if _t[i] >= 0.0:
			if _step[i] == SPARK:
				_draw_spark(i)
			else:
				_draw_one(i)


## 빛 번짐 (더하기): 심 둘레 옅은 빛, 앞 core_share 동안만.
func _draw_glow() -> void:
	for i in _t.size():
		if _t[i] < 0.0 or _step[i] == SPARK:
			continue
		var k := clampf(_t[i] / maxf(data.duration * data.core_share, 0.001), 0.0, 1.0)
		if k < 1.0:
			var r := HitImpactData.at_f(data.core_radius, _step[i], 24.0) * data.glow_mult
			_glow.draw_circle(_pos[i], r * (0.7 + 0.3 * k), Color(_color[i].lightened(0.5), data.glow_alpha * (1.0 - k)))


func _draw_spark(i: int) -> void:
	var k := clampf(_t[i] / maxf(data.spark_time, 0.001), 0.0, 1.0)
	var r := data.spark_size * (1.0 - 0.5 * k)
	var c := Color(1, 1, 1, 1.0 - k)
	draw_line(_pos[i] + Vector2(-r, 0), _pos[i] + Vector2(r, 0), c, 2.0)
	draw_line(_pos[i] + Vector2(0, -r), _pos[i] + Vector2(0, r), c, 2.0)
	draw_circle(_pos[i], r * 0.3, c)


func _draw_one(i: int) -> void:
	var k := clampf(_t[i] / maxf(data.duration, 0.001), 0.0, 1.0)
	var s := _step[i]
	var p := _pos[i]
	var d := _dir[i]
	var core := HitImpactData.at_f(data.core_radius, s, 24.0)
	var style := _style[i] if s >= 3 else Style.INK  # 1·2타는 먹 줄기, 3타·큰 기술은 영웅 줄기
	var n := HitImpactData.at_i(data.streak_count, s, 5)
	var length := HitImpactData.at_f(data.streak_length, s, 40.0) * (0.55 + 0.45 * sqrt(k))
	var w := data.streak_width * (1.0 - k) * (1.3 if style == Style.GOLD else 1.0)
	var spread := deg_to_rad(data.streak_spread_deg)
	var fade := 1.0 - k
	var col := _stroke_color(style, _color[i])
	var ink := Color(data.ink_color, data.ink_color.a * fade)
	for j in n:
		var a := -spread * 0.5 + spread * (j + 0.5 + 0.3 * sin(_seed[i] + j * 1.7)) / n
		var v := d.rotated(a)
		var from := p + v * core * 0.4
		var to := p + v * (core * 0.4 + length * (0.8 + 0.2 * cos(_seed[i] * 2.0 + j)))
		if style == Style.THUNDER:  # 번개: 꺾인 줄기 (중간 점 하나를 옆으로)
			_bolt[0] = from
			_bolt[1] = from.lerp(to, 0.5) + v.orthogonal() * length * 0.12 * sin(_seed[i] * 3.0 + j)
			_bolt[2] = to
			draw_polyline(_bolt, ink, w + data.outline * 2.0)
			draw_polyline(_bolt, Color(col, fade), w)
		else:
			draw_line(from, to, ink, w + data.outline * 2.0)
			draw_line(from, to, Color(col, fade), w)
		_draw_bits(style, to, v, w, fade, j)
	# 고리 (먹 + 영웅색)와 밝은 심
	var ring_r := core * (1.0 + (data.ring_mult - 1.0) * k)
	draw_arc(p, ring_r, 0.0, TAU, 24, Color(data.ink_color, 0.6 * fade), data.ring_width * fade + data.outline + 1.0)
	draw_arc(p, ring_r, 0.0, TAU, 24, Color(col, 0.9 * fade), data.ring_width * fade + 1.0)
	var ck := clampf(k / maxf(data.core_share, 0.001), 0.0, 1.0)
	if ck < 1.0:
		draw_circle(p, core * (1.0 - 0.6 * ck), Color(data.core_color.lerp(_color[i], data.core_tint), 1.0 - ck))


## 줄기 색: 물보라는 밝은 물빛, 금빛 획은 금색, 먹·꽃잎은 먹, 번개는 흰노랑, 그 밖은 영웅색을 밝게.
func _stroke_color(style: int, hero: Color) -> Color:
	match style:
		Style.WATER:
			return data.water_color
		Style.GOLD:
			return data.gold_color
		Style.PETAL:
			return data.petal_stroke_color
		Style.THUNDER:
			return data.thunder_color
	return hero.lightened(data.color_lighten)


## 줄기 끝 장식: 물방울·흙덩이·꽃잎 (3타·큰 기술만).
func _draw_bits(style: int, at: Vector2, v: Vector2, w: float, fade: float, j: int) -> void:
	match style:
		Style.WATER:
			draw_circle(at + v * w * 1.2, w * 0.55, Color(data.water_drop_color, fade))
		Style.THUNDER:
			if j % 2 == 0:
				draw_circle(at + v * w, w * 0.6, Color(data.earth_color, fade))  # 흙덩이
		Style.PETAL:
			draw_circle(at + v * w * 1.4, w * 0.6, Color(data.petal_color, fade))  # 매화 꽃잎
