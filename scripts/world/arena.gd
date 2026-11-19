class_name Arena
extends Node2D
## 임시 쿼터뷰 바닥: 흙빛 전장 (잡음 텍스처 셰이더 shaders/hanji.gdshader 재사용) + 돌 경계. 정식 그래픽 아님.
## 3D에서 구운 캐릭터와 어울리도록 한지·먹 대신 흙과 풀 얼룩 색을 쓴다 (사용자 선택: 3D 방식).

const GROUND := Color(0.36, 0.33, 0.27)
const PATCH := Color(0.22, 0.27, 0.16)
const STONE := Color(0.72, 0.68, 0.58, 0.85)

const HANJI := preload("res://shaders/hanji.gdshader")

@export var rect: Rect2 = Rect2(-900, -1400, 1800, 2800)


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
	mat.set_shader_parameter("paper", GROUND)
	mat.set_shader_parameter("ink", PATCH)
	material = mat
	var border := Border.new()
	border.rect = rect
	add_child(border)


func _draw() -> void:
	draw_rect(rect, GROUND)


## 경계는 셰이더 없이 먹선으로 (자식 노드라 부모 셰이더를 물려받지 않게 use_parent_material 끔).
class Border extends Node2D:
	var rect: Rect2

	func _draw() -> void:
		var c := STONE
		Ink.stroke(self, rect.position, Vector2(rect.end.x, rect.position.y), 14.0, c)
		Ink.stroke(self, Vector2(rect.end.x, rect.position.y), rect.end, 14.0, c)
		Ink.stroke(self, rect.end, Vector2(rect.position.x, rect.end.y), 14.0, c)
		Ink.stroke(self, Vector2(rect.position.x, rect.end.y), rect.position, 14.0, c)
