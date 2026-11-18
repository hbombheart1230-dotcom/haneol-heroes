extends SceneTree
## 3D 캐릭터(.glb) → 쿼터뷰 8방향 2D 스프라이트 시트 굽기 도구 (하데스식 "3D로 만들어 2D로 굽기").
## 창 모드로 실행해야 한다 (GPU 렌더링 필요):
##   godot --path . -s res://tools/bake/bake_sprites.gd
## 결과: assets/sprites/<name>/<anim>.png (행 = 방향 8개, 열 = 프레임) + <name>.tres (SpriteSheetSet)
## 모델·애니메이션 설정은 아래 JOBS에서 바꾼다. 새 모델(AI·외주)도 같은 방식으로 굽는다.

const FRAME := 192
const DIRS := 8
const JOBS := [
	{
		"name": "knight",
		"model": "res://assets/models/kaykit/Knight.glb",
		"ortho_size": 3.2,
		"anims": [
			{"key": "idle", "src": "Idle", "frames": 8, "fps": 8.0, "loop": true},
			{"key": "run", "src": "Running_A", "frames": 8, "fps": 14.0, "loop": true},
			{"key": "dash", "src": "Dodge_Forward", "frames": 6, "fps": 20.0, "loop": false},
			{"key": "attack", "src": "1H_Melee_Attack_Slice_Diagonal", "frames": 6, "fps": 16.0, "loop": false},
			{"key": "hit", "src": "Hit_A", "frames": 4, "fps": 12.0, "loop": false},
			{"key": "death", "src": "Death_A", "frames": 6, "fps": 10.0, "loop": false},
		],
	},
]

var _vp: SubViewport
var _pivot: Node3D


func _initialize() -> void:
	_bake_all()


func _bake_all() -> void:
	for job in JOBS:
		await _bake(job)
	print("BAKE DONE")
	quit()


func _setup(job: Dictionary) -> AnimationPlayer:
	_vp = SubViewport.new()
	_vp.size = Vector2i(FRAME, FRAME)
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var world := Node3D.new()
	_vp.add_child(world)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = job["ortho_size"]
	# 쿼터뷰: 앞에서 40도 내려다봄 (화면 아래 = 모델 앞 +Z)
	var cam_pos := Vector3(0, 6.0, 7.0)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0, 0.9, 0) - cam_pos, Vector3.UP), cam_pos)
	world.add_child(cam)
	cam.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.2
	world.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.9, 0.88, 0.85)
	env.environment.ambient_light_energy = 0.6
	world.add_child(env)
	_pivot = Node3D.new()
	world.add_child(_pivot)
	var model: Node3D = (load(job["model"]) as PackedScene).instantiate()
	_pivot.add_child(model)
	return model.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _bake(job: Dictionary) -> void:
	var ap := _setup(job)
	var out_dir := "res://assets/sprites/%s" % job["name"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var meta: Array = []
	for anim in job["anims"]:
		var frames: int = anim["frames"]
		var sheet := Image.create(FRAME * frames, FRAME * DIRS, false, Image.FORMAT_RGBA8)
		var a: Animation = ap.get_animation(anim["src"])
		for d in DIRS:
			# 방향 d: 화면 오른쪽(0)부터 시계 방향 45도씩 (화면 y는 아래)
			var sd := Vector2.from_angle(d * TAU / DIRS)
			_pivot.rotation.y = atan2(sd.x, sd.y)
			for f in frames:
				ap.play(anim["src"])
				var t := a.length * f / float(frames if anim["loop"] else maxi(frames - 1, 1))
				ap.seek(minf(t, a.length), true)
				ap.pause()
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var img := _vp.get_texture().get_image()
				img.convert(Image.FORMAT_RGBA8)
				sheet.blit_rect(img, Rect2i(0, 0, FRAME, FRAME), Vector2i(f * FRAME, d * FRAME))
		var png := "%s/%s.png" % [out_dir, anim["key"]]
		sheet.save_png(ProjectSettings.globalize_path(png))
		meta.append({"key": anim["key"], "png": png, "frames": frames, "fps": anim["fps"], "loop": anim["loop"]})
		print("baked ", png)
	_write_set(job["name"], out_dir, meta)
	_vp.queue_free()


## SpriteSheetSet .tres를 텍스트로 쓴다 (PNG는 다음 import 때 텍스처가 된다).
func _write_set(name: String, out_dir: String, meta: Array) -> void:
	var lines := PackedStringArray()
	lines.append('[gd_resource type="Resource" script_class="SpriteSheetSet" format=3]\n')
	lines.append('[ext_resource type="Script" path="res://scripts/art/sprite_sheet_set.gd" id="1_set"]')
	for i in meta.size():
		lines.append('[ext_resource type="Texture2D" path="%s" id="t%d"]' % [meta[i]["png"], i])
	lines.append("\n[resource]")
	lines.append('script = ExtResource("1_set")')
	lines.append("frame_size = %d" % FRAME)
	lines.append("directions = %d" % DIRS)
	var keys: Array = []
	var tex: Array = []
	var counts: Array = []
	var fps: Array = []
	var loops: Array = []
	for i in meta.size():
		keys.append('"%s"' % meta[i]["key"])
		tex.append('ExtResource("t%d")' % i)
		counts.append(str(meta[i]["frames"]))
		fps.append(str(meta[i]["fps"]))
		loops.append("true" if meta[i]["loop"] else "false")
	lines.append("anim_names = PackedStringArray(%s)" % ", ".join(keys))
	lines.append("textures = Array[Texture2D]([%s])" % ", ".join(tex))
	lines.append("frame_counts = PackedInt32Array(%s)" % ", ".join(counts))
	lines.append("fps = PackedFloat32Array(%s)" % ", ".join(fps))
	lines.append("loops = Array[bool]([%s])" % ", ".join(loops))
	var f := FileAccess.open("%s/%s.tres" % [out_dir, name], FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
