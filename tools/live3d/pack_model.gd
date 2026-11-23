extends SceneTree
## Meshy 원본(.glb, gitignore) → 게임에 넣는 가공 리소스 (커밋 가능, README "외부 자산"):
##   assets/live3d/<이름>/albedo.png   텍스처 (원본 2048 → tex px, VRAM 압축으로 가져온다)
##   assets/live3d/<이름>/material.tres
##   assets/live3d/<이름>/model.scn    뼈대 + 스킨 메시 (LOD·그림자 메시·동작 없이)
##   assets/live3d/<이름>/anims/*.res   동작 원본 (구간 자르기는 게임이 한다: live3d_library.gd)
##   data/live3d/<이름>.tres           설정 (굽기 작업 tools/bake/jobs/<이름>.json에서)
## 두 번 돌린다 (사이에 가져오기):
##   godot --headless --path . -s res://tools/live3d/pack_model.gd -- yi_sun_sin --stage=1 [--tex=1024]
##   godot --headless --path . --import
##   godot --headless --path . -s res://tools/live3d/pack_model.gd -- yi_sun_sin --stage=2

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
		if args.get("stage", "1") == "1":
			_stage1(job, out, int(args.get("tex", "1024")))
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
	img.resize(tex, tex, Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path(out + "/albedo.png"))
	_write(out + "/albedo.png.import", "[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n\n[params]\n\n"
		+ "compress/mode=2\ncompress/high_quality=false\nmipmaps/generate=true\ndetect_3d/compress_to=0\n")
	_write(out + "/material.tres", "[gd_resource type=\"StandardMaterial3D\" format=3]\n\n"
		+ "[ext_resource type=\"Texture2D\" path=\"%s/albedo.png\" id=\"1\"]\n\n[resource]\n" % out
		+ "albedo_texture = ExtResource(\"1\")\nroughness = %s\nmetallic_specular = %s\n" % [src.roughness, src.metallic_specular])
	model.free()
	print("stage1 ", out, " tex ", tex)


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
