extends SceneTree
## 굽기 작업(tools/bake/jobs/<이름>.json) → 실시간 3D 설정 data/live3d/<이름>.tres (시험).
## godot --headless --path . -s res://tools/live3d/make_live3d_data.gd -- yi_sun_sin

## 달리며 공격할 때 공격 동작을 따르는 윗몸 뼈 (Meshy 자동 뼈대 이름).
const UPPER := ["Spine02", "Spine01", "Spine", "neck", "Head", "head_end", "headfront",
	"LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand"]


func _initialize() -> void:
	for n in OS.get_cmdline_user_args():
		var job: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/bake/jobs/%s.json" % n))
		var d := Live3DHeroData.from_job(job)
		d.upper_bones = PackedStringArray(UPPER)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/live3d"))
		var path := "res://data/live3d/%s.tres" % n
		print(path, " ", ResourceSaver.save(d, path), " clips ", d.clips.size())
	quit()
