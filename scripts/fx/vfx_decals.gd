class_name VfxDecals
extends Node2D
## 그려진 기술 이펙트 (물결·번개·유성·꽃잎…): 커지며 돌고, 수명이 다하면 먹 번지듯 사라진다.
## 아래에 더하기 빛(glow) 층을 깐다. 두 층 모두 노드 하나의 _draw (모바일에서 가볍다).
## 모양은 SkillVfxData의 "그림" 묶음, 셰이더 세기·상한은 CombatFeelData.

const SHADER := preload("res://shaders/ink_decal.gdshader")

var feel: CombatFeelData
## {data, pos, rot, spin, size, t, life, bright, glow, layer}
var _items: Array[Dictionary] = []
## 금빛 고리 {pos, r, t, life}
var _rings: Array[Dictionary] = []
var _glow: Node2D


func _init(p_feel: CombatFeelData = null) -> void:
	feel = p_feel if p_feel else CombatFeelData.new()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var noise := NoiseTexture2D.new()
	noise.noise = FastNoiseLite.new()
	noise.seamless = true
	mat.set_shader_parameter("noise_tex", noise)
	mat.set_shader_parameter("edge", feel.decal_edge)
	mat.set_shader_parameter("dissolve_from", feel.decal_dissolve_from)
	mat.set_shader_parameter("edge_ink", feel.decal_edge_ink)
	mat.set_shader_parameter("noise_uv", feel.decal_noise_uv)
	material = mat
	_glow = Node2D.new()
	_glow.show_behind_parent = true
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.draw.connect(_draw_glow)
	add_child(_glow)


func count() -> int:
	return _items.size()


func ring_count() -> int:
	return _rings.size()


## 그림 터뜨리기. level = 기술 강화 단계 (클수록 크고 밝고 겹이 많다).
func burst(d: SkillVfxData, pos: Vector2, dir: Vector2 = Vector2.ZERO, level: int = 0) -> void:
	if d == null or d.decal == null:
		return
	var base_rot := randf() * TAU
	if d.decal_upright:
		base_rot = 0.0
	elif d.decal_align and dir.length_squared() > 0.0001:
		base_rot = dir.angle() - deg_to_rad(d.decal_angle_deg)
	var size := d.decal_size * d.size_mult(level)
	var bright := 1.0 + d.level_glow * d.level_of(level)
	for i in d.layers_for(level):
		_items.append({"data": d, "pos": pos, "rot": base_rot + feel.decal_layer_turn * i,
			"spin": d.decal_spin * (1.0 if i % 2 == 0 else -1.0), "size": size * pow(feel.decal_layer_shrink, i),
			"t": 0.0, "life": d.decal_time, "bright": bright, "glow": d.glow_for(level) if i == 0 else 0.0})
	if d.level_of(level) >= d.ring_level:
		_rings.append({"pos": pos, "r": size * feel.flourish_ring_scale, "t": 0.0, "life": feel.flourish_ring_time})
		while _rings.size() > maxi(feel.max_flourish_rings, 0):
			_rings.pop_front()
	while _items.size() > maxi(feel.max_decals, 1):
		_items.pop_front()


func _process(delta: float) -> void:
	step(delta)
	queue_redraw()
	_glow.queue_redraw()


func step(delta: float) -> void:
	var i := _items.size() - 1
	while i >= 0:
		var it := _items[i]
		it["t"] = float(it["t"]) + delta
		if float(it["t"]) >= float(it["life"]):
			_items.remove_at(i)
		else:
			it["rot"] = float(it["rot"]) + float(it["spin"]) * delta
		i -= 1
	i = _rings.size() - 1
	while i >= 0:
		_rings[i]["t"] = float(_rings[i]["t"]) + delta
		if float(_rings[i]["t"]) >= float(_rings[i]["life"]):
			_rings.remove_at(i)
		i -= 1


## 0~1 진행, 크기, 남은 수명(셰이더의 번짐 기준).
func _shape(it: Dictionary) -> Vector3:
	var d: SkillVfxData = it["data"]
	var k := float(it["t"]) / float(it["life"])
	var s := float(it["size"]) * lerpf(1.0, d.decal_grow, 1.0 - pow(1.0 - k, 2.0))
	var appear := minf(float(it["t"]) / maxf(d.decal_fade_in, 0.001), 1.0)
	return Vector3(k, s * lerpf(0.6, 1.0, appear), (1.0 - k) * appear)


func _draw() -> void:
	for it in _items:
		var d: SkillVfxData = it["data"]
		var sh := _shape(it)
		var b := float(it["bright"])
		draw_set_transform(it["pos"], float(it["rot"]), Vector2.ONE)
		draw_texture_rect(d.decal, Rect2(Vector2.ONE * -sh.y * 0.5, Vector2.ONE * sh.y), false, Color(b, b, b, sh.z))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for r in _rings:  # 엔진 draw_arc (GDScript 배열을 매 프레임 만들지 않음), 세로로 눌러 바닥에 깐 고리
		var k := float(r["t"]) / float(r["life"])
		draw_set_transform(r["pos"], 0.0, Vector2(1.0, feel.flourish_ring_squash))
		draw_arc(Vector2.ZERO, float(r["r"]) * (0.5 + k), 0.0, TAU, 40, Color(Ink.GOLD, 1.0 - k),
			feel.flourish_ring_width * (1.0 - k) + 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_glow() -> void:
	var dot := VfxTextures.get_texture(SkillVfxData.Shape.DOT)
	for it in _items:
		var g := float(it["glow"])
		if g <= 0.0:
			continue
		var d: SkillVfxData = it["data"]
		var sh := _shape(it)
		var s := sh.y * d.glow_size
		_glow.draw_texture_rect(dot, Rect2(it["pos"] - Vector2.ONE * s * 0.5, Vector2.ONE * s), false,
			Color(d.glow_color, g * sh.z))
