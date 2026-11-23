extends SceneTree
## 굽기 작업(tools/bake/jobs/<이름>.json) → 실시간 3D 설정 data/live3d/<이름>.tres (시험).
## godot --headless --path . -s res://tools/live3d/make_live3d_data.gd -- yi_sun_sin
## 추가 동작 파일(.glb, 파일마다 모델·2048 텍스처가 중복)은 동작만 꺼내 같은 폴더 anims/<파일>.res로 저장하고
## 설정이 그것을 가리키게 한다 (APK 용량·불러오는 시간). 모델 폴더는 gitignore라 .res도 커밋되지 않는다.

## 달리며 공격할 때 공격 동작을 따르는 윗몸 뼈 (Meshy 자동 뼈대 이름).
const UPPER := ["Spine02", "Spine01", "Spine", "neck", "Head", "head_end", "headfront",
	"LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand"]


func _initialize() -> void:
	for n in OS.get_cmdline_user_args():
		var job: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/bake/jobs/%s.json" % n))
		var d := Live3DHeroData.from_job(job)
		d.upper_bones = PackedStringArray(UPPER)
		var done := {}
		for c in d.clips:
			var f := String(c.get("file", ""))
			if f.get_extension() != "glb" or not ResourceLoader.exists(f):
				continue
			if not done.has(f):
				done[f] = _extract(f)
			c["file"] = done[f]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/live3d"))
		var path := "res://data/live3d/%s.tres" % n
		print(path, " ", ResourceSaver.save(d, path), " clips ", d.clips.size(), " extracted ", done.size())
	quit()


## .glb 안의 동작 하나 → <폴더>/anims/<파일 이름>.res
func _extract(glb: String) -> String:
	var s: Node = (load(glb) as PackedScene).instantiate()
	var ap := s.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var names := Array(ap.get_animation_list()).filter(func(x: StringName) -> bool: return x != &"RESET")
	var out := "%s/anims/%s.res" % [glb.get_base_dir(), glb.get_file().get_basename()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	var a := (ap.get_animation(names[0]) as Animation).duplicate(true)
	print(out, " ", ResourceSaver.save(a, out))
	s.free()
	return out
