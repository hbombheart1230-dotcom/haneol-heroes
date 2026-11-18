extends SceneTree
## 3D 캐릭터(.glb) → 쿼터뷰 8방향 2D 스프라이트 시트 굽기 도구 (하데스식 "3D로 만들어 2D로 굽기").
## 창 모드로 실행해야 한다 (GPU 렌더링 필요):
##   godot --path . -s res://tools/bake/bake_sprites.gd
## 결과: assets/sprites/<name>/<anim>.png (행 = 방향 8개, 열 = 프레임) + <name>.tres (SpriteSheetSet)
## 모델·애니메이션 설정은 아래 JOBS에서 바꾼다. 새 모델(AI·외주)도 같은 방식으로 굽는다.

const DIRS := 8
## 굽기 대상. frame = 프레임 한 칸 크기(px). 적은 화면에서 작으니 작게 굽는다 (APK 용량).
const JOBS := [
	{
		"name": "knight", "model": "res://assets/models/kaykit/Knight.glb", "ortho_size": 3.2, "frame": 192,
		"anims": [
			{"key": "idle", "src": "Idle", "frames": 8, "fps": 8.0, "loop": true},
			{"key": "run", "src": "Running_A", "frames": 8, "fps": 14.0, "loop": true},
			{"key": "dash", "src": "Dodge_Forward", "frames": 6, "fps": 20.0, "loop": false},
			{"key": "attack", "src": "1H_Melee_Attack_Slice_Diagonal", "frames": 6, "fps": 16.0, "loop": false},
			{"key": "hit", "src": "Hit_A", "frames": 4, "fps": 12.0, "loop": false},
			{"key": "death", "src": "Death_A", "frames": 6, "fps": 10.0, "loop": false},
		],
	},
	{
		"name": "skeleton_minion", "model": "res://assets/models/kaykit_skeletons/Skeleton_Minion.glb", "ortho_size": 3.2, "frame": 128,
		"anims": [
			{"key": "idle", "src": "Idle", "frames": 4, "fps": 6.0, "loop": true},
			{"key": "run", "src": "Running_A", "frames": 6, "fps": 12.0, "loop": true},
			{"key": "attack", "src": "1H_Melee_Attack_Chop", "frames": 5, "fps": 10.0, "loop": false},
			{"key": "hit", "src": "Hit_A", "frames": 3, "fps": 12.0, "loop": false},
		],
	},
	{
		"name": "skeleton_rogue", "model": "res://assets/models/kaykit_skeletons/Skeleton_Rogue.glb", "ortho_size": 3.2, "frame": 128,
		"anims": [
			{"key": "idle", "src": "Idle", "frames": 4, "fps": 6.0, "loop": true},
			{"key": "run", "src": "Running_A", "frames": 6, "fps": 12.0, "loop": true},
			{"key": "attack", "src": "1H_Ranged_Shoot", "frames": 5, "fps": 10.0, "loop": false},
			{"key": "hit", "src": "Hit_A", "frames": 3, "fps": 12.0, "loop": false},
		],
	},
	{
		"name": "skeleton_warrior", "model": "res://assets/models/kaykit_skeletons/Skeleton_Warrior.glb", "ortho_size": 3.2, "frame": 144,
		"anims": [
			{"key": "idle", "src": "2H_Melee_Idle", "frames": 4, "fps": 6.0, "loop": true},
			{"key": "run", "src": "Walking_A", "frames": 6, "fps": 10.0, "loop": true},
			{"key": "attack", "src": "2H_Melee_Attack_Chop", "frames": 6, "fps": 8.0, "loop": false},
			{"key": "hit", "src": "Hit_A", "frames": 3, "fps": 12.0, "loop": false},
		],
	},
	{
		"name": "barbarian_boss", "model": "res://assets/models/kaykit/Barbarian.glb", "ortho_size": 3.2, "frame": 192,
		"anims": [
			{"key": "idle", "src": "2H_Melee_Idle", "frames": 4, "fps": 6.0, "loop": true},
			{"key": "run", "src": "Running_A", "frames": 6, "fps": 10.0, "loop": true},
			{"key": "attack", "src": "2H_Melee_Attack_Spin", "frames": 6, "fps": 10.0, "loop": false},
			{"key": "hit", "src": "Hit_A", "frames": 3, "fps": 12.0, "loop": false},
		],
	},
]

## 명령줄 인자 --only=<name>이면 그 하나만 굽는다.
var _vp: SubViewport
var _pivot: Node3D
## "style": "ink"이면 3D 렌더를 수묵 후처리 셰이더로 한 번 더 그린 화면 (없으면 null).
var _post: SubViewport


func _initialize() -> void:
	_bake_all()


func _bake_all() -> void:
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.substr(7)
	for job in _all_jobs():
		if only == "" or job["name"] == only:
			await _bake(job)
	print("BAKE DONE")
	quit()


## JOBS + tools/bake/jobs/*.json (AI 3D 도구 tools/ai3d가 만든 굽기 설정).
func _all_jobs() -> Array:
	var jobs: Array = JOBS.duplicate()
	var dir := "res://tools/bake/jobs"
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".json"):
			var job: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/%s" % [dir, file]))
			if job is Dictionary:
				jobs.append(job)
	return jobs


## 애니메이션 이름 찾기. src는 "a|b|c" 후보 목록일 수 있다 (앞 후보 우선).
## 후보마다 정확히 같은 이름 → 대소문자 무시 포함 순으로 찾는다 (가져오기 때 이름이 조금 바뀌는 경우).
static func find_anim(ap: AnimationPlayer, src: String, quiet: bool = false) -> String:
	for cand in src.split("|", false):
		if ap.has_animation(cand):
			return cand
		for anim_name in ap.get_animation_list():
			if name_matches(anim_name, cand):
				return anim_name
	if not quiet:
		push_error("animation not found: %s (have %s)" % [src, ap.get_animation_list()])
	return ""


## 후보가 이름 속 어떤 단어의 앞부분이면 일치 (Running_A ← run, Soldier_Idle ← die 아님).
## 단어 = 영문자 덩어리, 낙타 표기도 나눈다 (HitReaction → hit, reaction). tools/ai3d의 name_matches와 같다.
static func name_matches(anim_name: String, cand: String) -> bool:
	var re := RegEx.create_from_string("[A-Z]?[a-z]+|[A-Z]+(?![a-z])")
	for m in re.search_all(anim_name):
		if m.get_string().to_lower().begins_with(cand.to_lower()):
			return true
	return false


## 동작이 다른 .glb에 따로 있으면 (웹에서 동작별로 받은 파일) 같은 뼈대로 보고 가져와 붙인다.
static func import_anim(ap: AnimationPlayer, from_path: String, src: String, key: String) -> String:
	var other: Node = (load(from_path) as PackedScene).instantiate()
	var oap := other.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var found := ""
	if oap:
		found = find_anim(oap, src, true)
		var clips := Array(oap.get_animation_list()).filter(func(n: StringName) -> bool: return n != &"RESET")
		if found == "" and clips.size() == 1:
			found = clips[0]  # 동작 하나만 든 파일이면 이름과 상관없이 그것
		if found == "":
			push_error("animation not found in %s: %s (have %s)" % [from_path, src, clips])
	var result := ""
	if found != "":
		if not ap.has_animation_library(&"ext"):
			ap.add_animation_library(&"ext", AnimationLibrary.new())
		ap.get_animation_library(&"ext").add_animation(key, oap.get_animation(found).duplicate(true))
		result = "ext/" + key
	other.free()
	return result


func _setup(job: Dictionary) -> AnimationPlayer:
	_vp = SubViewport.new()
	_vp.size = Vector2i(int(job["frame"]), int(job["frame"]))
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
	_post = _make_post(job) if job.get("style", "") == "ink" else null
	return model.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _make_post(job: Dictionary) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = _vp.size
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var rect := TextureRect.new()
	rect.texture = _vp.get_texture()
	rect.size = Vector2(_vp.size)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://tools/bake/ink_post.gdshader")
	for key in job.get("ink", {}):
		mat.set_shader_parameter(key, job["ink"][key])
	rect.material = mat
	vp.add_child(rect)
	return vp


func _bake(job: Dictionary) -> void:
	var ap := _setup(job)
	var FRAME: int = int(job["frame"])
	var out_dir := "res://assets/sprites/%s" % job["name"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var meta: Array = []
	for anim in job["anims"]:
		var frames: int = int(anim["frames"])
		var sheet := Image.create(FRAME * frames, FRAME * DIRS, false, Image.FORMAT_RGBA8)
		var src := ""
		if anim.has("from"):
			src = import_anim(ap, anim["from"], anim["src"], anim["key"])
		else:
			src = find_anim(ap, anim["src"])
		if src == "":
			continue
		var a: Animation = ap.get_animation(src)
		for d in DIRS:
			# 방향 d: 화면 오른쪽(0)부터 시계 방향 45도씩 (화면 y는 아래)
			var sd := Vector2.from_angle(d * TAU / DIRS)
			_pivot.rotation.y = atan2(sd.x, sd.y)
			for f in frames:
				ap.play(src)
				var t := a.length * f / float(frames if anim["loop"] else maxi(frames - 1, 1))
				ap.seek(minf(t, a.length), true)
				ap.pause()
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				if _post:
					await RenderingServer.frame_post_draw
				var img := (_post if _post else _vp).get_texture().get_image()
				img.convert(Image.FORMAT_RGBA8)
				sheet.blit_rect(img, Rect2i(0, 0, FRAME, FRAME), Vector2i(f * FRAME, d * FRAME))
		var png := "%s/%s.png" % [out_dir, anim["key"]]
		sheet.save_png(ProjectSettings.globalize_path(png))
		_write_import(png, 0.5 if _post else 0.75)
		meta.append({"key": anim["key"], "png": png, "frames": frames, "fps": float(anim["fps"]), "loop": anim["loop"]})
		print("baked ", png)
	_write_set(job["name"], out_dir, meta, FRAME)
	_vp.queue_free()
	if _post:
		_post.queue_free()


## 처음 구운 시트는 손실 압축으로 가져오게 한다 (APK 30 MiB 제한). 이미 있으면 그대로 둔다.
## 수묵 시트는 먹선·결 때문에 압축이 덜 돼 품질을 더 낮춘다.
func _write_import(png: String, quality: float) -> void:
	var path := ProjectSettings.globalize_path(png + ".import")
	if FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n'
		+ "compress/mode=1\ncompress/lossy_quality=%s\nmipmaps/generate=false\n" % quality)
	f.close()


## SpriteSheetSet .tres를 텍스트로 쓴다 (PNG는 다음 import 때 텍스처가 된다).
func _write_set(name: String, out_dir: String, meta: Array, frame_px: int) -> void:
	var lines := PackedStringArray()
	lines.append('[gd_resource type="Resource" script_class="SpriteSheetSet" format=3]\n')
	lines.append('[ext_resource type="Script" path="res://scripts/art/sprite_sheet_set.gd" id="1_set"]')
	for i in meta.size():
		lines.append('[ext_resource type="Texture2D" path="%s" id="t%d"]' % [meta[i]["png"], i])
	lines.append("\n[resource]")
	lines.append('script = ExtResource("1_set")')
	lines.append("frame_size = %d" % frame_px)
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
