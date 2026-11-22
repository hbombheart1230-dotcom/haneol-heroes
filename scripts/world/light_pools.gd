class_name LightPools
extends Node2D
## 바닥에 까는 빛 웅덩이 (StageLook): 화톳불 둘레, 흩어진 달빛, 영웅 발밑.
## 2D 조명 노드 대신 더하기 혼합 그라디언트 한 장을 여러 번 그린다 (그림자 계산 없음 → 저사양 폰에서 가볍다).
## 바닥(지도) 위, 소품·캐릭터 아래에 놓는다. 위치는 한 번만 정하고 _draw도 무대가 바뀔 때만 다시 한다.

var look: StageLook
## [중심, 반지름, 색, 세로 배율] — 한 번 정해 두고 그리기만.
var pools: Array = []
var hero_glow: HeroGlow
static var _tex: Texture2D


func _init() -> void:
	material = additive()
	hero_glow = HeroGlow.new()
	hero_glow.material = material
	add_child(hero_glow)


## 무대 조명을 깐다. props_items는 StageProps.items, textures는 그 그림 목록.
func setup(p_look: StageLook, rect: Rect2, props_items: Array, textures: Array[Texture2D], seed: int) -> void:
	look = p_look
	pools.clear()
	if look:
		pools = place(look, rect, props_items, textures, seed)
	visible = look != null
	hero_glow.setup(look)
	queue_redraw()


## 영웅 발밑 빛이 따라갈 노드.
func follow(target: Node2D) -> void:
	hero_glow.target = target


## 순수 계산 (테스트용): 소품 빛 + 흩어진 웅덩이 위치·크기·색.
static func place(l: StageLook, rect: Rect2, props_items: Array, textures: Array[Texture2D], seed: int) -> Array:
	var out: Array = []
	if not l.lit_props.is_empty():
		for it in props_items:
			if it[1] != 2:
				continue
			var tex: Texture2D = textures[int(it[3])]
			if l.lit_props.has(tex.resource_path.get_file().get_basename()):
				out.append([(it[0] as Vector2) + l.prop_light_offset * float(it[2]), l.prop_light_radius,
					l.prop_light_color, 0.7])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 7919
	var n := roundi(rect.get_area() / 1_000_000.0 * l.pools_per_mpx)
	var placed: Array[Vector2] = []
	for i in n * 4:
		if placed.size() >= n:
			break
		var p := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
		if placed.any(func(q: Vector2) -> bool: return q.distance_to(p) < l.pool_spacing):
			continue
		placed.append(p)
		out.append([p, rng.randf_range(l.pool_radius_min, l.pool_radius_max), l.pool_color, l.pool_squash])
	return out


func _draw() -> void:
	var tex := glow_texture()
	for p in pools:
		var r: float = p[1]
		var sq: float = p[3]
		draw_texture_rect(tex, Rect2(p[0] - Vector2(r, r * sq), Vector2(r * 2.0, r * 2.0 * sq)), false, p[2])


static func additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


## 가운데 밝고 가장자리로 부드럽게 사라지는 원 (한 번만 만든다).
static func glow_texture() -> Texture2D:
	if _tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_tex = t
	return _tex


## 영웅 발밑의 옅은 빛. 매 프레임 위치만 옮긴다.
class HeroGlow extends Node2D:
	var target: Node2D
	var _rect := Rect2()
	var _color := Color.TRANSPARENT

	func setup(l: StageLook) -> void:
		var on := l != null and l.hero_light_color.a > 0.0
		visible = on
		set_process(on)
		if on:
			var r := l.hero_light_radius
			_rect = Rect2(-r, -r * 0.6, r * 2.0, r * 1.2)
			_color = l.hero_light_color
		queue_redraw()

	func _process(_dt: float) -> void:
		if is_instance_valid(target):
			global_position = target.global_position

	func _draw() -> void:
		draw_texture_rect(LightPools.glow_texture(), _rect, false, _color)
