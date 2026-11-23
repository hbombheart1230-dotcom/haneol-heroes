extends SceneTree
## 동작 고르기용 시트: 영웅 가공 모델로 동작 전체를 8방향 × fps칸으로 그려 시트(행 = 방향, 열 = 칸)와 가슴 위치를 쓴다.
## 게임처럼 뿌리 뼈 수평 이동은 고정. 측정은 tools/live3d/motion_pick.py (measure_motion.py와 같은 몸 기울기·무게 이동 + 칼끝 호).
## 창 모드: godot --path . -s res://tools/live3d/motion_scan.gd -- <영웅> <출력 폴더> <동작 .res>... [--fps=15]

const CELL := 128
const DIRS := 8


func _initialize() -> void:
	_run()


func _run() -> void:
	var hero := ""
	var out := ""
	var fps := 15.0
	var clips: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fps="):
			fps = float(a.substr(6))
		elif hero == "":
			hero = a
		elif out == "":
			out = a
		else:
			clips.append(a)
	DirAccess.make_dir_recursive_absolute(out)
	var model: Node3D = (load("res://assets/live3d/%s/model.scn" % hero) as PackedScene).instantiate()
	var vp := SubViewport.new()
	vp.size = Vector2i(CELL, CELL)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var pivot := Node3D.new()
	vp.add_child(pivot)
	pivot.add_child(model)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.6
	var pos := Vector3(0, 6.0, 7.0)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0, 0.9, 0) - pos, Vector3.UP), pos)
	vp.add_child(cam)
	cam.current = true
	var sun := DirectionalLight3D.new()
	vp.add_child(sun)
	var sk := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var hips := sk.find_bone("Hips")
	var chest := sk.find_bone("Spine")
	var ap := AnimationPlayer.new()
	model.add_child(ap)
	var lib := AnimationLibrary.new()
	ap.add_animation_library(&"", lib)
	for path in clips:
		var anim: Animation = load(path)
		lib.add_animation(&"c", anim)
		var n := maxi(int(anim.length * fps), 1)
		var sheet := Image.create(CELL * n, CELL * DIRS, false, Image.FORMAT_RGBA8)
		var meta := {"fps": fps, "frames": n, "cell": CELL, "length": anim.length, "chest": []}
		for d in DIRS:
			var sd := Vector2.from_angle(d * TAU / DIRS)
			pivot.rotation.y = atan2(sd.x, sd.y)
			var row: Array = []
			for f in n:
				ap.play(&"c")
				ap.seek(f / fps, true)
				ap.pause()
				var hp := sk.get_bone_pose_position(hips)
				var rest := sk.get_bone_rest(hips).origin
				sk.set_bone_pose_position(hips, Vector3(rest.x, hp.y, rest.z))
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var img := vp.get_texture().get_image()
				img.convert(Image.FORMAT_RGBA8)
				sheet.blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i(f * CELL, d * CELL))
				var c := cam.unproject_position(sk.global_transform * sk.get_bone_global_pose(chest).origin)
				row.append([c.x, c.y])
			meta["chest"].append(row)
		lib.remove_animation(&"c")
		var name: String = path.get_file().get_basename()
		sheet.save_png("%s/%s.png" % [out, name])
		var f := FileAccess.open("%s/%s.json" % [out, name], FileAccess.WRITE)
		f.store_string(JSON.stringify(meta))
		f.close()
		print("SCAN ", name, " frames ", n)
	quit()
