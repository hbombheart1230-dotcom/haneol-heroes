class_name Arena
extends Node2D
## 쿼터뷰 바닥: 무대에 배경 지도가 있으면 그 그림, 없으면 한지 셰이더(shaders/hanji.gdshader) + 먹선 경계.

const HANJI := preload("res://shaders/hanji.gdshader")

@export var rect: Rect2 = Rect2(-900, -1400, 1800, 2800)
## 무대 겉모습 (바닥 색·수묵 소품). 비어 있으면 기본 한지.
@export var theme: StageTheme

var props: StageProps
var map: MapLayer
var border: Node2D
var obstacles: Obstacles
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
	props = StageProps.new()
	props.use_parent_material = false
	add_child(props)
	obstacles = Obstacles.new()
	add_child(obstacles)
	border = Border.new()
	border.rect = rect
	add_child(border)
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
		map.texture = tex
		map.rect = t.background_rect if t.background_rect.has_area() else rect
		map.queue_redraw()
	if border:
		border.visible = tex == null  # 지도에는 벽·난간·물가가 그려져 있다
	if props:
		props.setup(t, rect.grow(-t.prop_inset))
	if obstacles:
		var list := t.map_blockers.duplicate() if tex else PackedVector3Array()
		if props:
			list.append_array(Obstacles.from_props(props.items, t))
		obstacles.build(list)
	queue_redraw()


## 카메라가 지도 밖(맨바닥)을 보지 않게 지도 영역으로 묶는다. 지도가 없으면 풀어 둔다.
func clamp_camera(cam: Camera2D) -> void:
	if cam == null:
		return
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


## 배경 지도 한 장 (셰이더 없이 그대로).
class MapLayer extends Node2D:
	var texture: Texture2D
	var rect: Rect2

	func _draw() -> void:
		if texture:
			draw_texture_rect(texture, rect, false)


## 경계는 셰이더 없이 먹선으로 (자식 노드라 부모 셰이더를 물려받지 않게 use_parent_material 끔).
class Border extends Node2D:
	var rect: Rect2

	func _draw() -> void:
		var c := Color(Ink.INK, 0.75)
		Ink.stroke(self, rect.position, Vector2(rect.end.x, rect.position.y), 14.0, c)
		Ink.stroke(self, Vector2(rect.end.x, rect.position.y), rect.end, 14.0, c)
		Ink.stroke(self, rect.end, Vector2(rect.position.x, rect.end.y), 14.0, c)
		Ink.stroke(self, Vector2(rect.position.x, rect.end.y), rect.position, 14.0, c)
