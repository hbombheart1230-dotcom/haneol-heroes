class_name Arena
extends Node2D
## 임시 쿼터뷰 바닥: 한지 셰이더(shaders/hanji.gdshader) + 먹선 경계. 정식 그래픽 아님.

const HANJI := preload("res://shaders/hanji.gdshader")

@export var rect: Rect2 = Rect2(-900, -1400, 1800, 2800)
## 무대 겉모습 (바닥 색·수묵 소품). 비어 있으면 기본 한지.
@export var theme: StageTheme

var props: StageProps


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
	props = StageProps.new()
	props.use_parent_material = false
	add_child(props)
	if theme:
		apply_theme(theme)
	var border := Border.new()
	border.rect = rect
	add_child(border)


## 무대 바꾸기: 바닥 셰이더 색과 소품을 다시 정한다.
func apply_theme(t: StageTheme) -> void:
	theme = t
	var mat := material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("paper", t.floor_base)
		mat.set_shader_parameter("ink", t.floor_stain)
	if props:
		props.setup(t, rect)
	queue_redraw()


func _draw() -> void:
	draw_rect(rect, theme.floor_base if theme else Ink.PAPER)


## 경계는 셰이더 없이 먹선으로 (자식 노드라 부모 셰이더를 물려받지 않게 use_parent_material 끔).
class Border extends Node2D:
	var rect: Rect2

	func _draw() -> void:
		var c := Color(Ink.INK, 0.75)
		Ink.stroke(self, rect.position, Vector2(rect.end.x, rect.position.y), 14.0, c)
		Ink.stroke(self, Vector2(rect.end.x, rect.position.y), rect.end, 14.0, c)
		Ink.stroke(self, rect.end, Vector2(rect.position.x, rect.end.y), 14.0, c)
		Ink.stroke(self, Vector2(rect.position.x, rect.end.y), rect.position, 14.0, c)
