extends GdUnitTestSuite
## 그림 가져오기 압축 규칙 지킴이 (APK 용량, docs/research/apk_size.md).
## 규칙은 tools/build/import_rules.json. 새 그림이 기본값(무손실)으로 들어오면 여기서 실패한다.
## 고치기: python tools/build/import_rules.py → godot --headless --path . --import

const RULES := "res://tools/build/import_rules.json"


func _imports_under(dir: String, into: PackedStringArray) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".png.import"):
			into.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_imports_under(dir.path_join(d), into)


func _param(text: String, key: String) -> String:
	for line in text.split("\n"):
		if line.begins_with(key + "="):
			return line.trim_prefix(key + "=")
	return ""


func test_rules_cover_vfx_intro_backgrounds() -> void:
	var rules: Array = JSON.parse_string(FileAccess.get_file_as_string(RULES))["rules"]
	var dirs := rules.map(func(r): return r["dir"])
	assert_array(dirs).contains(["assets/vfx", "assets/intro", "assets/backgrounds"])


func test_every_image_follows_its_folder_rule() -> void:
	var rules: Array = JSON.parse_string(FileAccess.get_file_as_string(RULES))["rules"]
	var bad := PackedStringArray()
	var seen := 0
	for r in rules:
		var files := PackedStringArray()
		_imports_under("res://" + r["dir"], files)
		for p in files:
			var t := FileAccess.get_file_as_string(p)
			if not t.contains("importer=\"texture\""):
				continue
			seen += 1
			var mode := int(_param(t, "compress/mode"))
			var q := float(_param(t, "compress/lossy_quality"))
			if mode != int(r["mode"]) or not is_equal_approx(q, float(r["lossy_quality"])):
				bad.append(p)
	assert_int(seen).is_greater(50)
	assert_array(bad).override_failure_message(
		"압축 규칙과 다른 그림 (python tools/build/import_rules.py 로 맞추세요): %s" % ", ".join(bad)
	).is_empty()
