class_name FxWarmupLayer
extends Node2D
## 예열 그리기 (FxWarmup): 모은 그림을 효과가 쓰는 재질마다(그냥·더하기 빛·수묵 셰이더 둘) 사각형·다각형·선으로
## 거의 투명하게 frames프레임 그리고 사라진다. 셰이더 갈래 컴파일·텍스처 첫 사용·글꼴 크기 그리기를 판 시작 때 치른다.
## 화면 안(카메라 가운데)에 그려야 잘리지 않는다 (화면 밖은 그리기에서 빠진다). 3D 화면에서도 같은 2D 효과 층이다.

const INK_DECAL := preload("res://shaders/ink_decal.gdshader")
const INK_VFX := preload("res://shaders/ink_vfx.gdshader")
const ENEMY_RIM := preload("res://shaders/enemy_rim.gdshader")
## 거의 안 보이는 불투명도 (0이면 그리기에서 빠질 수 있다).
const ALPHA := 0.012

var textures: Array = []
## 기술 이름 (컷인 글씨).
var words: PackedStringArray = PackedStringArray()
## 몇 프레임 그리고 사라질지.
var frames: int = 2
var _left: int = 0
var _uv := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
var _cols := PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 1)])


func _ready() -> void:
	z_index = 100
	modulate = Color(1, 1, 1, ALPHA)
	_left = frames
	for mat in materials():
		var n := Node2D.new()
		n.material = mat
		n.draw.connect(_draw_set.bind(n))
		add_child(n)


## 효과가 쓰는 재질 갈래: 그냥(null), 더하기 빛, 수묵 자국(ink_decal), 기술 입자(ink_vfx), 적 테두리.
static func materials() -> Array:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var out: Array = [null, add]
	for sh in [INK_DECAL, INK_VFX, ENEMY_RIM]:
		var m := ShaderMaterial.new()
		m.shader = sh
		out.append(m)
	return out


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	global_position = cam.get_screen_center_position() if cam else Vector2.ZERO
	if _left <= 0:
		queue_free()
		return
	_left -= 1
	for c in get_children():
		(c as CanvasItem).queue_redraw()


func _draw_set(n: Node2D) -> void:
	var i := 0
	for t in textures:
		var tex := t as Texture2D
		if tex == null:
			continue
		var p := Vector2((i % 16) * 6.0, (i / 16) * 6.0) - Vector2(48, 48)
		n.draw_texture_rect(tex, Rect2(p, Vector2(4, 4)), false)
		n.draw_polygon(PackedVector2Array([p, p + Vector2(4, 0), p + Vector2(4, 4), p + Vector2(0, 4)]), _cols, _uv, tex)
		i += 1
	n.draw_line(Vector2(-8, 0), Vector2(8, 0), Color.WHITE, 2.0)
	n.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(0, 4)]), Color.WHITE)
	n.draw_circle(Vector2.ZERO, 3.0, Color.WHITE)
	if n.material == null and not words.is_empty():  # 기술 이름: 컷인과 같은 크기·테두리로 (글꼴 크기마다 글자 그림을 만든다)
		var st := SkillStageFeel.get_default()
		SkillCutin.draw_name(n, Vector2(-40, 0), " ".join(words), st.cutin_font_px if st else 84, 0.05, Color.WHITE)
