extends SceneTree
## 옮긴 동작 확인: 위 = 원본 뼈대 모델(.glb)이 자기 동작을, 아래 = 영웅 가공 모델이 옮긴 동작을 같은 시각에 (칸 n개).
## 창 모드: godot --path . -s res://tools/live3d/retarget_check.gd -- <영웅> <원본 .glb> <원본 동작 이름> <옮긴 .res> <출력 png> [칸=8] [방향 각도=30]

const FRAME := 256


func _initialize() -> void:
	_run()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var n := int(a[5]) if a.size() > 5 else 8
	var yaw := deg_to_rad(float(a[6]) if a.size() > 6 else 30.0)
	var src_scene: Node3D = (load(a[1]) as PackedScene).instantiate()
	var dst_scene: Node3D = (load(_model_path(a[0])) as PackedScene).instantiate()
	var vs := _viewport(src_scene, yaw)
	var vd := _viewport(dst_scene, yaw)
	var sap := src_scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var anim: Animation = load(a[3])
	var dap := AnimationPlayer.new()
	dst_scene.add_child(dap)
	var lib := AnimationLibrary.new()
	lib.add_animation(&"r", anim)
	dap.add_animation_library(&"", lib)
	var out := Image.create(FRAME * n, FRAME * 2, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.85, 0.82, 0.75))
	for i in n:
		var t := anim.length * i / float(maxi(n - 1, 1))
		sap.play(StringName(a[2]))
		sap.seek(t, true)
		sap.pause()
		dap.play(&"r")
		dap.seek(t, true)
		dap.pause()
		for k in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		for row in 2:
			var img := (vs if row == 0 else vd).get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			out.blend_rect(img, Rect2i(0, 0, FRAME, FRAME), Vector2i(i * FRAME, row * FRAME))
	out.save_png(a[4])
	quit()


## 모델 크기를 맞춰(메시 높이 1.8m) 굽기와 같은 직교 카메라 앞에 세운다.
func _viewport(model: Node3D, yaw: float) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(FRAME, FRAME)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var pivot := Node3D.new()
	vp.add_child(pivot)
	pivot.add_child(model)
	var aabb := AABB()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var box := m.global_transform * m.get_aabb() if m.is_inside_tree() else m.get_aabb()
		aabb = box if aabb.size == Vector3.ZERO else aabb.merge(box)
	if aabb.size.y > 0.0:
		model.scale = Vector3.ONE * (1.8 / aabb.size.y) * model.scale.x
	pivot.rotation.y = yaw
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.4
	var pos := Vector3(0, 6.0, 7.0)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0, 0.9, 0) - pos, Vector3.UP), pos)
	vp.add_child(cam)
	cam.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	vp.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.9, 0.88, 0.85)
	env.environment.ambient_light_energy = 0.6
	vp.add_child(env)
	return vp


## 영웅·적의 가공 3D 모델, 없으면 굽기 원본 (3D가 없는 적).
static func _model_path(id: String) -> String:
	var p := "res://assets/live3d/%s/model.scn" % id
	return p if ResourceLoader.exists(p) else "res://assets/models/meshy/%s/animated.glb" % id
