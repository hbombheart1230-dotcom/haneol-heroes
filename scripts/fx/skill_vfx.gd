class_name SkillVfx
extends Node2D
## 기술 이펙트 입자 (물방울·불똥·별·글자·먹·꽃잎). KillFx처럼 노드 하나의 _draw로 모두 그린다.
## 모양은 SkillVfxData, 개수 상한·수묵 셰이더 세기는 CombatFeelData("기술 이펙트").

const SHADER := preload("res://shaders/ink_vfx.gdshader")

var feel: CombatFeelData
## {data, pos, vel, t, life, size, rot, spin, glyph}
var _parts: Array[Dictionary] = []
var _glyph_i: int = 0


func _init(p_feel: CombatFeelData = null) -> void:
	feel = p_feel if p_feel else CombatFeelData.new()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var noise := NoiseTexture2D.new()
	noise.noise = FastNoiseLite.new()
	noise.seamless = true
	mat.set_shader_parameter("noise_tex", noise)
	mat.set_shader_parameter("roughness", feel.vfx_roughness)
	mat.set_shader_parameter("edge_ink", feel.vfx_edge_ink)
	mat.set_shader_parameter("noise_scale", feel.vfx_noise_scale)
	material = mat


func count() -> int:
	return _parts.size()


## 터뜨리기. dir은 FORWARD일 때 방향 (없으면 위).
func burst(data: SkillVfxData, pos: Vector2, dir: Vector2 = Vector2.ZERO) -> void:
	if data == null or data.count <= 0:
		return
	var base := dir.normalized() if dir.length_squared() > 0.0001 else Vector2.UP
	if data.aim == SkillVfxData.Aim.UP:
		base = Vector2.UP
	var half := deg_to_rad(data.spread_deg) * 0.5
	for i in data.count:
		var a := randf() * TAU if data.aim == SkillVfxData.Aim.RADIAL else base.angle() + randf_range(-half, half)
		var v := Vector2.from_angle(a) * randf_range(data.speed.x, data.speed.y)
		var glyph := ""
		if data.shape == SkillVfxData.Shape.GLYPH and data.glyphs != "":
			glyph = data.glyphs[_glyph_i % data.glyphs.length()]
			_glyph_i += 1
		_parts.append({"data": data, "pos": pos + Vector2.from_angle(randf() * TAU) * randf() * data.spawn_radius,
			"vel": v, "t": 0.0, "life": randf_range(data.life.x, data.life.y),
			"size": randf_range(data.size.x, data.size.y), "rot": randf() * TAU,
			"spin": randf_range(-data.spin, data.spin), "glyph": glyph})
	while _parts.size() > maxi(feel.max_vfx_particles, 0):
		_parts.pop_front()


func _process(delta: float) -> void:
	step(delta)
	queue_redraw()


## 시간 진행 (테스트에서 직접 부른다). 제자리에서 지운다.
func step(delta: float) -> void:
	var i := _parts.size() - 1
	while i >= 0:
		var p := _parts[i]
		p["t"] = float(p["t"]) + delta
		if float(p["t"]) >= float(p["life"]):
			_parts.remove_at(i)
		else:
			var d: SkillVfxData = p["data"]
			var v: Vector2 = p["vel"]
			v = v * maxf(1.0 - d.damping * delta, 0.0) + Vector2(0, d.gravity * delta)
			p["vel"] = v
			p["pos"] = (p["pos"] as Vector2) + v * delta
			p["rot"] = float(p["rot"]) + float(p["spin"]) * delta
		i -= 1


func _draw() -> void:
	for p in _parts:
		var d: SkillVfxData = p["data"]
		var k := float(p["t"]) / float(p["life"])
		var s := float(p["size"]) * lerpf(1.0, d.size_end, k)
		var col := d.color.lerp(d.color_end, k)
		var rot := float(p["rot"])
		if d.shape == SkillVfxData.Shape.GLYPH:  # 글자는 똑바로 시작해 천천히 돈다
			rot = float(p["spin"]) * float(p["t"])
		var scale := Vector2.ONE
		if d.align_to_velocity:
			rot = (p["vel"] as Vector2).angle()
			scale = Vector2(d.stretch, 1.0)
		draw_set_transform(p["pos"], rot, scale)
		if d.shape == SkillVfxData.Shape.GLYPH and p["glyph"] != "":
			var fs := int(maxf(s, 8.0))
			draw_string(UiStyle.TITLE_FONT, Vector2(-s * 0.5, s * 0.35), p["glyph"], HORIZONTAL_ALIGNMENT_LEFT,
				-1, fs, col)
		else:
			draw_texture_rect(VfxTextures.get_texture(d.shape), Rect2(Vector2(-s, -s) * 0.5, Vector2(s, s)), false, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
