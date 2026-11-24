class_name Arena
extends Node2D
## 쿼터뷰 바닥: 무대에 배경 지도가 있으면 그 그림, 없으면 한지 셰이더(shaders/hanji.gdshader) + 먹선 경계.

const HANJI := preload("res://shaders/hanji.gdshader")
const FLOOR_GRADE := preload("res://shaders/floor_grade.gdshader")

@export var rect: Rect2 = Rect2(-900, -1400, 1800, 2800)
## 무대 겉모습 (바닥 색·수묵 소품). 비어 있으면 기본 한지.
@export var theme: StageTheme

var props: StageProps
var map: MapLayer
## 바닥 빛 웅덩이 (무대 look이 있을 때만).
var lights: LightPools
## 가장자리 겹침 그림 (무대 look.overlay_texture, 지도 위·빛 아래).
var edge: MapLayer
var border: Node2D
var obstacles: Obstacles
## 화면 가장자리 먹 비네트 (HUD 아래, 무대 vignette가 0이면 숨김).
var vignette: Vignette
## 지도 밖 바닥 (카메라가 전장 끝에서 보는 곳)을 덮는 여유.
const OUTSIDE := 2000.0


func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = HANJI
	# 잡음은 엔진 기본 NoiseTexture2D로 한 번만 만든다 (셰이더에서 매 픽셀 계산하지 않음).
	var noise := NoiseTexture2D.new()
	noise.width = 256
	noise.height = 256
	noise.seamless = true
	noise.noise = FastNoiseLite.new()
	noise.noise.frequency = 0.02
	mat.set_shader_parameter("noise_tex", noise)
	material = mat
	map = MapLayer.new()
	map.use_parent_material = false
	add_child(map)
	edge = MapLayer.new()
	edge.use_parent_material = false
	add_child(edge)
	lights = LightPools.new()
	add_child(lights)
	props = StageProps.new()
	props.use_parent_material = false
	add_child(props)
	obstacles = Obstacles.new()
	add_child(obstacles)
	border = Border.new()
	border.rect = rect
	add_child(border)
	vignette = Vignette.new()
	add_child(vignette)
	if theme:
		apply_theme(theme)


## 무대 바꾸기: 바닥 셰이더 색과 소품을 다시 정한다.
func apply_theme(t: StageTheme) -> void:
	theme = t
	var mat := material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("paper", t.floor_base)
		mat.set_shader_parameter("ink", t.floor_stain)
	var tex: Texture2D = null
	if t.background_path != "" and ResourceLoader.exists(t.background_path):
		tex = load(t.background_path) as Texture2D
	if map:
		map.grade(t.floor_value, t.floor_saturation, t.look)
		map.texture = tex
		map.rect = t.background_rect if t.background_rect.has_area() else rect
		if map.material:
			(map.material as ShaderMaterial).set_shader_parameter("map_px", map.rect.size)
		map.queue_redraw()
	if edge:
		edge.texture = t.look.overlay_texture if t.look else null
		edge.rect = map.rect if map else rect
		edge.modulate = Color(1, 1, 1, t.look.overlay_alpha if t.look else 1.0)
		edge.queue_redraw()
	if vignette:
		vignette.set_strength(t.vignette)
	if border:
		border.visible = tex == null  # 지도에는 벽·난간·물가가 그려져 있다
	if props:
		props.setup(t, rect.grow(-t.prop_inset))
	if lights:
		lights.setup(t.look, map.rect if map else rect, props.items if props else [], t.prop_textures, t.seed)
	if obstacles:
		var list := t.map_blockers.duplicate() if tex else PackedVector3Array()
		if props:
			list.append_array(Obstacles.from_props(props.items, t))
		obstacles.build(list)
	queue_redraw()


## 카메라가 지도 밖(맨바닥)을 보지 않게 지도 영역으로 묶는다. 지도가 없으면 풀어 둔다.
## 무대 확대(theme.camera_zoom)도 여기서 (마무리 줌이 돌아올 기준 base_zoom도 같이).
func clamp_camera(cam: Camera2D) -> void:
	if cam == null:
		return
	cam.zoom = Vector2.ONE * (theme.camera_zoom if theme else 1.0)
	cam.set_meta(&"base_zoom", cam.zoom)
	var r: Rect2 = map.rect if has_map() else Rect2(-10000000, -10000000, 20000000, 20000000)
	cam.limit_left = int(r.position.x)
	cam.limit_top = int(r.position.y)
	cam.limit_right = int(r.end.x)
	cam.limit_bottom = int(r.end.y)


func has_map() -> bool:
	return map != null and map.texture != null


func _draw() -> void:
	var r := rect.grow(OUTSIDE) if has_map() else rect
	draw_rect(r, theme.floor_base if theme else Ink.PAPER)


## 배경 지도 한 장 (명도·채도 배율이 1이 아니면 floor_grade 셰이더).
class MapLayer extends Node2D:
	var texture: Texture2D
	var rect: Rect2

	func grade(value: float, sat: float, look: StageLook = null) -> void:
		if look == null and is_equal_approx(value, 1.0) and is_equal_approx(sat, 1.0):
			material = null
			return
		var m := ShaderMaterial.new()
		m.shader = FLOOR_GRADE
		m.set_shader_parameter("value_mult", look.value_mult if look else value)
		m.set_shader_parameter("saturation", look.saturation if look else sat)
		if look:
			m.set_shader_parameter("contrast", look.contrast)
			m.set_shader_parameter("pivot", look.pivot)
			m.set_shader_parameter("shadow_tint", look.shadow_tint)
			m.set_shader_parameter("light_tint", look.light_tint)
			m.set_shader_parameter("tint_mix", look.tint_mix)
			m.set_shader_parameter("tint_split", look.tint_split)
			if look.detail_texture and look.detail_strength > 0.0:
				m.set_shader_parameter("detail_tex", look.detail_texture)
				m.set_shader_parameter("detail_strength", look.detail_strength)
				m.set_shader_parameter("detail_px", look.detail_px)
		material = m

	func _draw() -> void:
		if texture:
			draw_texture_rect(texture, rect, false)


## 화면 가장자리 먹 비네트: 가운데 투명 → 가장자리 먹. 그라디언트 그림 한 장을 화면에 늘린다.
class Vignette extends CanvasLayer:
	var _rect: TextureRect

	func _init() -> void:
		layer = 1  # HUD(같은 1)보다 먼저 트리에 있어 아래에 그려진다
		_rect = TextureRect.new()
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_rect.stretch_mode = TextureRect.STRETCH_SCALE
		var g := Gradient.new()
		g.set_color(0, Color(Ink.INK, 0.0))
		g.set_color(1, Color(Ink.INK, 1.0))
		g.add_point(0.55, Color(Ink.INK, 0.0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.05, 0.5)
		t.width = 128
		t.height = 128
		_rect.texture = t
		add_child(_rect)
		visible = false

	func set_strength(a: float) -> void:
		visible = a > 0.0
		_rect.modulate = Color(1, 1, 1, clampf(a, 0.0, 1.0))


## 경계는 셰이더 없이 먹선으로 (자식 노드라 부모 셰이더를 물려받지 않게 use_parent_material 끔).
class Border extends Node2D:
	var rect: Rect2

	func _draw() -> void:
		var c := Color(Ink.INK, 0.75)
		Ink.stroke(self, rect.position, Vector2(rect.end.x, rect.position.y), 14.0, c)
		Ink.stroke(self, Vector2(rect.end.x, rect.position.y), rect.end, 14.0, c)
		Ink.stroke(self, rect.end, Vector2(rect.position.x, rect.end.y), 14.0, c)
		Ink.stroke(self, Vector2(rect.position.x, rect.end.y), rect.position, 14.0, c)
