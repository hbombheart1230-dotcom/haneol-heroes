extends Node
## 실시간 3D 영웅 한 명 (시험): 자기 SubViewport(투명 배경, 굽기와 같은 직교 카메라)에 모델을 그리고
## 그 화면 텍스처를 2D 스프라이트가 쓴다. 방향은 8칸 없이 바라보는 쪽으로 돌고, 동작은 AnimationTree로 섞는다.
## 3D를 끈 엔진에서는 불러오지 않는다 (PlayerView3D가 경로로만 불러온다).

const Library := preload("res://scripts/art/live3d/live3d_library.gd")
const TreeBuilder := preload("res://scripts/art/live3d/live3d_tree.gd")

var data: Live3DHeroData
var viewport: SubViewport
var pivot: Node3D
var tree: AnimationTree
var _yaw: float = 0.0
var _body: String = ""
var _upper: String = ""
var _upper_w: float = 0.0
## 마지막 요청 (테스트·확인용): 몸 재생 속도, 마지막 seek 시각(-1 = 없음).
var _speed: float = 1.0
var _seek: float = -1.0


## durations: 동작 키 → 초 (구운 시트와 같은 길이). own_world = false면 부모 세계를 같이 쓴다 (성능 비교용).
func setup(d: Live3DHeroData, durations: Dictionary) -> void:
	data = d
	viewport = SubViewport.new()
	viewport.size = Vector2i(d.frame, d.frame)
	viewport.transparent_bg = true
	viewport.own_world_3d = true  # 인스턴스마다 자기 세계 (다른 영웅·적 모델이 비치지 않게)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	_add_camera(world, d)
	_add_lights(world, d.light)
	pivot = Node3D.new()
	world.add_child(pivot)
	var model: Node3D = (load(d.model_path) as PackedScene).instantiate()
	pivot.add_child(model)
	if not d.rigid.is_empty():  # 무기 손뼈 고정 (시험: 굽기 도구 것을 그대로, 실제 전환 땐 가져오기 단계로)
		load("res://tools/bake/rigid_weapon.gd").apply(model, d.rigid)
	var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var lib := Library.get_or_build(d, model, durations)
	if ap:
		ap.active = false
	tree = TreeBuilder.build(model, d, lib)
	play_body("idle", true, 0.0, 1.0)


func texture() -> Texture2D:
	return viewport.get_texture()


func _add_camera(world: Node3D, d: Live3DHeroData) -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = d.ortho_size
	cam.transform = Transform3D(Basis.looking_at(d.cam_target - d.cam_pos, Vector3.UP), d.cam_pos)
	world.add_child(cam)
	cam.current = true


## 굽기(bake_sprites.gd _setup)와 같은 조명. 그림자는 끈다 (발밑 먹 그림자는 2D가 그린다).
func _add_lights(world: Node3D, light: Dictionary) -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(float(light.get("key_pitch", -50.0)), float(light.get("key_yaw", -30.0)), 0)
	sun.light_energy = float(light.get("key", 1.2))
	sun.light_color = Color(light.get("key_color", "#ffffff"))
	world.add_child(sun)
	if float(light.get("rim", 0.0)) > 0.0:
		var rim := DirectionalLight3D.new()
		rim.rotation_degrees = Vector3(-25, 160, 0)
		rim.light_energy = float(light["rim"])
		rim.light_color = Color(light.get("rim_color", "#cfe0ff"))
		world.add_child(rim)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.9, 0.88, 0.85)
	env.environment.ambient_light_energy = float(light.get("ambient", 0.6))
	world.add_child(env)


## 화면 방향(2D, y 아래) → 모델 회전. 굽기의 방향 d와 같은 식, 칸 없이 turn_speed로 따라간다.
func set_facing(v: Vector2, delta: float) -> void:
	if v.length_squared() < 0.0001:
		return
	_yaw = rotate_toward(_yaw, target_yaw(v), data.turn_speed * delta)
	pivot.rotation.y = _yaw


static func target_yaw(v: Vector2) -> float:
	return atan2(v.x, v.y)


func has_anim(anim: String) -> bool:
	return tree.tree_root.has_node("body_" + anim)


## 몸 동작: 바뀌거나 restart면 섞어서 seek초(없으면 처음)부터, 그대로면 seek >= 0일 때만 그 시각으로.
## speed 0 = 멈춤 (역경직·착지 멈칫·충전 자세).
func play_body(anim: String, restart: bool, seek: float, speed: float) -> void:
	if not has_anim(anim):
		anim = "idle"
	if anim != _body or restart:
		# 멈춘 채(speed 0) 바꾸면 섞기 시간도 멈춰 앞 동작에 갇힌다 → 그때는 바로 바꾼다
		(tree.tree_root.get_node("body") as AnimationNodeTransition).xfade_time = data.blend_time if speed > 0.0 else 0.0
		tree.set("parameters/body/transition_request", anim)
		_body = anim
		seek = maxf(seek, 0.0)  # 입력을 되돌리지 않으므로 시작 시각을 늘 준다
	if seek >= 0.0:
		tree.set(TreeBuilder.seek_param("body", anim), seek)
		_seek = seek
	_speed = speed
	tree.set("parameters/body_ts/scale", speed)


## 윗몸 겹치기: on이면 윗몸 뼈만 anim을 따른다 (달리며 공격). 무게는 upper_blend_time에 걸쳐 바뀐다.
func set_upper(anim: String, restart: bool, on: bool, speed: float, delta: float) -> void:
	if on and has_anim(anim) and (anim != _upper or restart):
		tree.set("parameters/upper/transition_request", anim)
		tree.set(TreeBuilder.seek_param("upper", anim), 0.0)
		_upper = anim
	var step := delta / maxf(data.upper_blend_time, 0.001)
	_upper_w = move_toward(_upper_w, 1.0 if on else 0.0, step)
	tree.set("parameters/layer/blend_amount", _upper_w)
	tree.set("parameters/upper_ts/scale", speed)


func body_anim() -> String:
	return _body


func body_speed() -> float:
	return _speed


func last_seek() -> float:
	return _seek


func upper_weight() -> float:
	return _upper_w
