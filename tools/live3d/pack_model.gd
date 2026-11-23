extends SceneTree
## Meshy 원본(.glb, gitignore) → 게임에 넣는 가공 리소스 (커밋 가능, README "외부 자산"):
##   assets/live3d/<이름>/albedo.png   텍스처: 기본은 원본 크기·무손실 (화질 우선, 2026-11-23 사용자).
##                                     줄이려면 --tex=<px> 또는 굽기 작업의 "live3d_tex" → 그 크기로 줄이고 VRAM 압축
##   assets/live3d/<이름>/material.tres
##   assets/live3d/<이름>/model.scn    뼈대 + 스킨 메시 (LOD·그림자 메시·동작 없이)
##   assets/live3d/<이름>/anims/*.res   동작 원본 (구간 자르기는 게임이 한다: live3d_library.gd)
##   data/live3d/<이름>.tres           설정 (굽기 작업 tools/bake/jobs/<이름>.json에서)
## 두 번 돌린다 (사이에 가져오기):
##   godot --headless --path . -s res://tools/live3d/pack_model.gd -- yi_sun_sin --stage=1 [--tex=1024 (줄이기)]
##   godot --headless --path . --import
##   godot --headless --path . -s res://tools/live3d/pack_model.gd -- yi_sun_sin --stage=2
## 굽기 작업의 동작 구간(start·end·loop·times)만 바꿨으면 (예: 평타 다시 자르기) 모델 없이 설정만 맞춘다:
##   godot --headless --path . -s res://tools/live3d/pack_model.gd -- yi_sun_sin --stage=sync
## (구간의 정본은 굽기 작업 JSON. tests/test_live3d.gd가 둘이 다르면 실패한다.)

const Lib := preload("res://scripts/art/live3d/live3d_library.gd")
## 달리며 공격할 때 공격 동작을 따르는 윗몸 뼈 (Meshy 자동 뼈대 이름).
const UPPER := ["Spine02", "Spine01", "Spine", "neck", "Head", "head_end", "headfront",
	"LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand"]


func _initialize() -> void:
	var args := {}
	var names: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.trim_prefix("--").split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else ""
		else:
			names.append(a)
	for n in names:
		var job: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/bake/jobs/%s.json" % n))
		var out := "res://assets/live3d/%s" % n
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out + "/anims"))
		if args.get("stage", "1") == "sync":
			_sync(job, n)
		elif args.get("stage", "1") == "1":
			_stage1(job, out, int(args.get("tex", str(job.get("live3d_tex", 0)))))
		else:
			_stage2(job, out, n)
	quit()


## 텍스처 줄이기 + 재질 (가져오기 전이라 텍스트로 쓴다).
func _stage1(job: Dictionary, out: String, tex: int) -> void:
	var model: Node = (load(job["model"]) as PackedScene).instantiate()
	var mi := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var src := mi.get_active_material(0) as BaseMaterial3D
	var img := src.albedo_texture.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGB8)
	if tex > 0 and tex < img.get_width():  # 줄이기는 고를 때만 (VRAM 압축 함께)
		img.resize(tex, tex, Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path(out + "/albedo.png"))
	var mode := 2 if tex > 0 else 0  # 0 = 무손실 (원래 화질), 2 = VRAM 압축
	_write(out + "/albedo.png.import", "[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n\n[params]\n\n"
		+ "compress/mode=%d\ncompress/high_quality=false\nmipmaps/generate=true\ndetect_3d/compress_to=0\n" % mode)
	_write(out + "/material.tres", "[gd_resource type=\"StandardMaterial3D\" format=3]\n\n"
		+ "[ext_resource type=\"Texture2D\" path=\"%s/albedo.png\" id=\"1\"]\n\n[resource]\n" % out
		+ "albedo_texture = ExtResource(\"1\")\nroughness = %s\nmetallic_specular = %s\n" % [src.roughness, src.metallic_specular])
	model.free()
	print("stage1 ", out, " tex ", img.get_width(), " lossless" if tex <= 0 else " vram")


## 메시·뼈대 장면, 동작, 설정.
func _stage2(job: Dictionary, out: String, n: String) -> void:
	var model: Node3D = (load(job["model"]) as PackedScene).instantiate()
	var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var d := Live3DHeroData.from_job(job)
	d.upper_bones = PackedStringArray(UPPER)
	var saved := {}
	for c in d.clips:
		var f := String(c.get("file", ""))
		var key := f + ":" + String(c["src"])
		if not saved.has(key):
			saved[key] = _save_clip(ap, f, String(c["src"]), out)
		c["file"] = saved[key]
		c.erase("src")
	ap.get_parent().remove_child(ap)
	ap.free()
	if not d.rigid.is_empty():  # 무기를 손뼈에만 묶어 저장 (게임은 다시 하지 않는다: tools/는 APK에 없다)
		print("rigid weapon verts: ", RigidWeapon.apply(model, d.rigid))
		d.rigid = {}
	var mat := load(out + "/material.tres") as Material
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		mi.mesh = _plain_mesh(mi.mesh as ArrayMesh, mat)
		mi.skin = mi.skin.duplicate() if mi.skin else null
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for node in model.find_children("*", "", true, false):
		node.owner = model
	var ps := PackedScene.new()
	ps.pack(model)
	print("scene ", ResourceSaver.save(ps, out + "/model.scn", ResourceSaver.FLAG_COMPRESS))
	model.free()
	d.model_path = out + "/model.scn"
	print("data ", ResourceSaver.save(d, "res://data/live3d/%s.tres" % n), " clips ", d.clips.size())


## 설정의 동작 구간을 굽기 작업과 같게 (동작 파일·모델은 그대로: 자르기는 게임이 한다).
func _sync(job: Dictionary, n: String) -> void:
	var path := "res://data/live3d/%s.tres" % n
	var d: Live3DHeroData = load(path)
	var fresh := Live3DHeroData.from_job(job)
	for c in d.clips:
		var f := fresh.clip(String(c["key"]))
		# 원본 동작이 바뀌었으면 (예: 2타를 다른 동작에서) 이미 꺼내 둔 anims/<이름>.res로. 없으면 stage 2부터 다시.
		var res := "res://assets/live3d/%s/anims/%s.res" % [n, Lib.norm(String(f.get("src", "")))]
		if String(f.get("file", "")).get_extension() == "res":  # 굽기도 쓰는 옮긴 동작 (reuse.from)
			res = String(f["file"])
		if ResourceLoader.exists(res):
			c["file"] = res
		else:
			push_error("%s: clip %s not packed yet (%s) — run stage 1·2" % [n, f.get("src", ""), res])
		for k in ["start", "end", "times"]:
			if f.has(k):
				c[k] = f[k]
			else:
				c.erase(k)
		c["loop"] = f.get("loop", false)
	print("sync ", path, " ", ResourceSaver.save(d, path))


## LOD·그림자 메시 없이 표면만 새로 (경로 없는 리소스 → 장면 안에 저장된다).
static func _plain_mesh(src: ArrayMesh, mat: Material) -> ArrayMesh:
	var m := ArrayMesh.new()
	for s in src.get_surface_count():
		var fmt := src.surface_get_format(s)
		var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS else 0
		m.add_surface_from_arrays(src.surface_get_primitive_type(s), src.surface_get_arrays(s), [], {}, flags)
		m.surface_set_material(s, mat)
	return m


## 동작 하나 → anims/<이름>.res. file이 비면 모델 안 동작, 아니면 그 .glb의 동작 (여럿이면 src 이름으로).
func _save_clip(ap: AnimationPlayer, file: String, src: String, out: String) -> String:
	if file.get_extension() == "res":  # 이미 이 뼈대로 옮겨 둔 동작 (retarget_clip.gd, 굽기도 같은 것을 쓴다)
		return file
	var s: Node = null
	if file != "":
		s = (load(file) as PackedScene).instantiate()
		ap = s.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var names := Array(ap.get_animation_list()).filter(func(x: StringName) -> bool: return x != &"RESET")
	var pick: String = names[0] if file != "" and names.size() == 1 else ""
	for x in names:
		if pick == "" and Lib.norm(_bare(x)) == Lib.norm(src):
			pick = x
	if pick == "":
		push_error("clip not found: %s in %s %s" % [src, file, names])
		return ""
	var a := ap.get_animation(pick)
	var path := "%s/anims/%s.res" % [out, Lib.norm(_bare(pick))]
	print(path, " ", ResourceSaver.save(a.duplicate(true), path, ResourceSaver.FLAG_COMPRESS))
	if s:
		s.free()
	return path


## "Armature|Mage_Soell_Cast_3|baselayer" → "Mage_Soell_Cast_3"
static func _bare(n: String) -> String:
	return n.get_slice("|", 1) if "|" in n else n


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
