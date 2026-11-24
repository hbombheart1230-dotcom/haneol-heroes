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
## 직선 기술 띠 {tex, a, b, w, t, life, reveal, bright}
var _strips: Array[Dictionary] = []
var _glow: Node2D
## 조각 등장·바늘·눈금·베인 자국·모이는 기운 (같은 수묵 셰이더), 바닥 자국 (적 아래).
var pieces: VfxPieces
var ground: VfxGround


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
	pieces = VfxPieces.new()
	var tinted := mat.duplicate() as ShaderMaterial  # 베인 자국·바늘: 색을 입히는 붓 그림 (움직임 없음)
	tinted.set_shader_parameter("tinted", true)
	pieces.set_ink_material(tinted)
	add_child(pieces)
	pieces.ink_node().draw.connect(_draw_rings)
	ground = VfxGround.new()
	add_child(ground)


func count() -> int:
	return _items.size()


func ring_count() -> int:
	return _rings.size()


func strip_count() -> int:
	return _strips.size()


## 경로 a→b를 따라 그림 띠를 펼친다 (직선 기술·회피 자취). 강화 단계만큼 커지고 밝아진다.
## data가 있으면 그 일렁임·프레임 시트를 쓴다.
func strip(tex: Texture2D, a: Vector2, b: Vector2, width: float, time: float, reveal: float, level_mult: float = 1.0,
		bright: float = 1.0, data: SkillVfxData = null) -> void:
	if tex == null or a.distance_squared_to(b) < 1.0:
		return
	_strips.append({"tex": tex, "a": a, "b": b, "w": width * level_mult, "t": 0.0, "life": maxf(time, 0.01),
		"reveal": maxf(reveal, 0.001), "bright": bright, "data": data})
	while _strips.size() > maxi(feel.max_strips, 1):
		_strips.pop_front()


## 기술 데이터의 띠 설정으로 펼친다.
func strip_for(d: SkillVfxData, a: Vector2, b: Vector2, level: int = 0) -> void:
	if d and (d.strip or d.strip_sheet):
		strip(d.strip_at(0.0), a, b, d.strip_width, d.strip_time, d.strip_reveal, d.size_mult(level),
			d.bright_for(level), d)


## 그림 터뜨리기. level = 기술 강화 단계 (클수록 크고 밝고 겹이 많다).
## fit_radius > 0이면 (기술이 판정 반경을 알려 줌) 그림 지름을 판정에 맞춘다 (SkillVfxData.fit_to_hit).
## band_radius > 0이면 고리 띠 두께는 그 반경에 맞췄을 때 그대로 (조각 그림, SkillVfxData.band_inner_uv).
func burst(d: SkillVfxData, pos: Vector2, dir: Vector2 = Vector2.ZERO, level: int = 0, fit_radius: float = 0.0,
		band_radius: float = 0.0) -> void:
	if d == null or not d.has_decal():
		return
	var base_rot := randf() * TAU
	if d.decal_upright:
		base_rot = 0.0
	elif d.decal_align and dir.length_squared() > 0.0001:
		base_rot = dir.angle() - deg_to_rad(d.decal_angle_deg)
	var pl := FxCoverage.plan(d, level, fit_radius, pieces.stage, FxCoverage.view_width(self))  # 화면 덮기 상한
	var size := float(pl["size"])
	var bright := d.bright_for(level)
	ground.mark(d, pos, level, float(pl["ground_k"]))
	if d.piece_count > 0:  # 조각으로 펼침 (한 장 통째 대신)
		if band_radius > 0.0 and size > 0.0:
			pl["band_k"] = d.fitted_size(band_radius) / size
		pieces.pieces(d, pos, dir, level, size, pl)
	for i in (0 if d.piece_count > 0 else d.layers_for(level)):
		_items.append({"data": d, "pos": pos, "rot": base_rot + feel.decal_layer_turn * i,
			"spin": d.decal_spin * (1.0 if i % 2 == 0 else -1.0), "size": size * pow(feel.decal_layer_shrink, i),
			"t": 0.0, "life": d.decal_time * float(pl["time"]), "bright": bright, "grow": pl["grow"],
			"glow_k": pl["glow_k"], "glow": d.glow_for(level) * float(pl["light"]) if i == 0 else 0.0})
	if d.ring_for(level):
		if pl.get("exact", false):  # 판정 끝에 고정한 그림: 금빛 고리도 칠해진 둘레 그대로 (커지지도 눌리지도 않음)
			_rings.append({"pos": pos, "r": size * d.art_fill * 0.5, "t": 0.0, "life": feel.flourish_ring_time, "exact": true})
		else:
			_rings.append({"pos": pos, "r": size * feel.flourish_ring_scale, "t": 0.0, "life": feel.flourish_ring_time})
		while _rings.size() > maxi(feel.max_flourish_rings, 0):
			_rings.pop_front()
	while _items.size() > maxi(feel.max_decals, 1):
		_items.pop_front()


## 그릴 지름: 판정 반경을 알면 거기에 맞추고, 모르면 데이터 크기 × 강화 배율.
static func fit_size(d: SkillVfxData, level: int, fit_radius: float) -> float:
	if fit_radius > 0.0 and d.fit_to_hit:  # 성장 단계면 판정(반경)이 이미 단계 배율로 커져 있다 (SkillGrowthData.scaled_def)
		return d.fitted_size(fit_radius)
	return d.decal_size * d.size_mult(level)


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
	i = _strips.size() - 1
	while i >= 0:
		_strips[i]["t"] = float(_strips[i]["t"]) + delta
		if float(_strips[i]["t"]) >= float(_strips[i]["life"]):
			_strips.remove_at(i)
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
	var s := float(it["size"]) * lerpf(1.0, float(it.get("grow", d.decal_grow)), 1.0 - pow(1.0 - k, 2.0))
	var appear := minf(float(it["t"]) / maxf(d.decal_fade_in, 0.001), 1.0)
	return Vector3(k, s * lerpf(0.6, 1.0, appear), (1.0 - k) * appear)


func _draw() -> void:
	for it in _items:
		var d: SkillVfxData = it["data"]
		var sh := _shape(it)
		var b := float(it["bright"])
		var tex := d.decal_at(float(it["t"]))
		if tex == null:
			continue
		draw_set_transform(it["pos"], float(it["rot"]), Vector2.ONE)
		draw_texture_rect(tex, Rect2(Vector2.ONE * -sh.y * 0.5, Vector2.ONE * sh.y), false, d.ink_color(b, sh.z))
	for s in _strips:
		_draw_strip(s)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 금빛 고리는 색을 입히는 층(VfxPieces 먹 층)에 그린다 (움직이는 그림 셰이더는 밝기만 쓰므로).
func _draw_rings() -> void:
	var ink := pieces.ink_node()
	for r in _rings:  # 엔진 draw_arc (GDScript 배열을 매 프레임 만들지 않음), 세로로 눌러 바닥에 깐 고리
		var k := float(r["t"]) / float(r["life"])
		var exact: bool = r.get("exact", false)
		ink.draw_set_transform(r["pos"], 0.0, Vector2(1.0, 1.0 if exact else feel.flourish_ring_squash))
		ink.draw_arc(Vector2.ZERO, float(r["r"]) * (1.0 if exact else 0.5 + k), 0.0, TAU, 40, Color(Ink.GOLD, 1.0 - k),
			feel.flourish_ring_width * (1.0 - k) + 2.0)
	ink.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 앞으로 펼쳐지는 띠를 조각으로: 펼쳐지는 머리는 굵게 부풀고, 꼬리부터 먹으로 번져 사라진다
## (한 장이 통째로 밀려 나가 보이지 않게). 조각 수는 SkillStageFeel.strip_slices.
func _draw_strip(s: Dictionary) -> void:
	var st := pieces.stage
	var data: SkillVfxData = s["data"]
	var tex: Texture2D = s["tex"]
	if data and data.strip_sheet:
		tex = data.strip_at(float(s["t"]))
	var a: Vector2 = s["a"]
	var d: Vector2 = (s["b"] as Vector2) - a
	var t := float(s["t"])
	var k := minf(t / float(s["reveal"]), 1.0)
	var life := 1.0 - t / float(s["life"])
	var w := float(s["w"])
	var br := float(s["bright"])
	var n := maxi(st.strip_slices, 1)
	var shown := d.length() * k
	var tw := float(tex.get_width())
	draw_set_transform(a, d.angle(), Vector2.ONE)
	for i in n:
		var u0 := float(i) / n  # 보이는 길이 중 이 조각의 시작 (0 = 꼬리)
		var u1 := float(i + 1) / n
		var head := u1  # 머리 쪽일수록 늦게 사라지고 펼쳐질 때 부푼다
		var alpha := clampf(life * (1.0 + st.strip_tail_lead) - (1.0 - head) * st.strip_tail_lead, 0.0, 1.0)
		if alpha <= 0.0:
			continue
		var swell := 1.0 + st.strip_head_swell * (1.0 - k) * head
		var sw := w * swell * lerpf(0.75, 1.0, head)
		draw_texture_rect_region(tex, Rect2(shown * u0, -sw * 0.5, shown * (u1 - u0) + 1.0, sw),
			Rect2(tw * (1.0 - k) + tw * k * u0, 0.0, tw * k * (u1 - u0), tex.get_height()),
			data.ink_color(br, alpha) if data else Color(br, 0.0, 0.0, alpha))


func _draw_glow() -> void:
	var dot := VfxTextures.get_texture(SkillVfxData.Shape.DOT)
	for it in _items:
		var g := float(it["glow"])
		if g <= 0.0:
			continue
		var d: SkillVfxData = it["data"]
		var sh := _shape(it)
		var s := sh.y * float(it.get("glow_k", d.glow_size))
		_glow.draw_texture_rect(dot, Rect2(it["pos"] - Vector2.ONE * s * 0.5, Vector2.ONE * s), false,
			Color(d.glow_color, g * sh.z))
