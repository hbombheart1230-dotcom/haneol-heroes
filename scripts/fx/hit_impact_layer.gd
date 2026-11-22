class_name HitImpactLayer
extends Node2D
## 무기가 닿는 자리의 한 타 충격 그림 (HitImpactData): 밝은 심 → 영웅색 고리 → 먹 외곽선을 두른 튐 줄기.
## 고정 크기 고리 버퍼(max_active)를 돌려 쓴다 (타격마다·프레임마다 배열·사전을 새로 만들지 않음).

var data: HitImpactData
var _pos := PackedVector2Array()
var _dir := PackedVector2Array()
var _t := PackedFloat32Array()
var _step := PackedInt32Array()
var _color := PackedColorArray()
var _seed := PackedFloat32Array()
var _next: int = 0
var _active: int = 0


func _init(p_data: HitImpactData = null) -> void:
	data = p_data if p_data else HitImpactData.new()
	var n := maxi(data.max_active, 1)
	_pos.resize(n)
	_dir.resize(n)
	_t.resize(n)
	_step.resize(n)
	_color.resize(n)
	_seed.resize(n)
	for i in n:
		_t[i] = -1.0
	z_as_relative = false
	z_index = data.draw_z  # 검기(영웅 쪽) 위에 그린다


## 충격 하나 (dir = 맞은 쪽으로 밀리는 방향, step = 1~3타).
func add(pos: Vector2, dir: Vector2, step: int, color: Color) -> void:
	var i := _next
	_next = (_next + 1) % _t.size()
	if _t[i] < 0.0:
		_active += 1
	_pos[i] = pos
	_dir[i] = dir.normalized() if dir.length_squared() > 0.0001 else Vector2.RIGHT
	_t[i] = 0.0
	_step[i] = clampi(step, 1, 3)
	_color[i] = color
	_seed[i] = randf() * TAU
	queue_redraw()


func active_count() -> int:
	return _active


func _process(delta: float) -> void:
	if _active <= 0:
		return
	for i in _t.size():
		if _t[i] < 0.0:
			continue
		_t[i] += delta
		if _t[i] >= data.duration:
			_t[i] = -1.0
			_active -= 1
	queue_redraw()


func _draw() -> void:
	for i in _t.size():
		if _t[i] >= 0.0:
			_draw_one(i)


func _draw_one(i: int) -> void:
	var k := clampf(_t[i] / maxf(data.duration, 0.001), 0.0, 1.0)
	var s := _step[i]
	var p := _pos[i]
	var d := _dir[i]
	var core := HitImpactData.at_f(data.core_radius, s, 24.0)
	# 튐 줄기: 먹 외곽선 먼저, 영웅색 위에 (바깥으로 뻗으며 가늘어짐)
	var n := HitImpactData.at_i(data.streak_count, s, 5)
	var length := HitImpactData.at_f(data.streak_length, s, 40.0) * (0.55 + 0.45 * sqrt(k))
	var w := data.streak_width * (1.0 - k)
	var spread := deg_to_rad(data.streak_spread_deg)
	var fade := 1.0 - k
	var col := _color[i].lightened(data.color_lighten)
	for j in n:
		var a := -spread * 0.5 + spread * (j + 0.5 + 0.3 * sin(_seed[i] + j * 1.7)) / n
		var v := d.rotated(a)
		var from := p + v * core * 0.4
		var to := p + v * (core * 0.4 + length * (0.8 + 0.2 * cos(_seed[i] * 2.0 + j)))
		draw_line(from, to, Color(data.ink_color, data.ink_color.a * fade), w + data.outline * 2.0)
		draw_line(from, to, Color(col, fade), w)
	# 영웅색 고리 (퍼지며 옅어짐)
	draw_arc(p, core * (1.0 + (data.ring_mult - 1.0) * k), 0.0, TAU, 24, Color(data.ink_color, 0.6 * fade), data.ring_width * fade + data.outline + 1.0)
	draw_arc(p, core * (1.0 + (data.ring_mult - 1.0) * k), 0.0, TAU, 24, Color(col, 0.9 * fade), data.ring_width * fade + 1.0)
	# 밝은 심: 앞 core_share 동안 크게 번쩍, 그 뒤 줄어듦
	var ck := clampf(k / maxf(data.core_share, 0.001), 0.0, 1.0)
	if ck < 1.0:
		draw_circle(p, core * (1.0 - 0.6 * ck), Color(data.core_color.lerp(_color[i], data.core_tint), 1.0 - ck))
