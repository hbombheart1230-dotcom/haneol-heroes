extends GdUnitTestSuite
## 내보내기 제외 목록 지킴이 (docs/research/apk_size.md).
## export_presets.cfg 의 exclude_filter 에 낱개 파일로 적은 그림은 APK 에 안 들어간다.
## 누가 그 그림을 다시 쓰기 시작하면 폰에서만 그림이 비므로, 게임 코드·데이터가 참조하지 않는지 여기서 확인한다.

const PRESETS := "res://export_presets.cfg"
const SCAN_DIRS := ["res://scripts", "res://scenes", "res://data", "res://assets", "res://shaders"]
const SCAN_EXT := ["gd", "tres", "tscn", "gdshader"]


func _excluded_files() -> PackedStringArray:
	var out := PackedStringArray()
	var text := FileAccess.get_file_as_string(PRESETS)
	for line in text.split("\n"):
		if not line.begins_with("exclude_filter="):
			continue
		for item in line.trim_prefix("exclude_filter=").trim_prefix("\"").trim_suffix("\"").split(","):
			var p := item.strip_edges()
			if p != "" and not p.contains("*") and p.get_extension() == "png" and not out.has(p):
				out.append(p)
	return out


func _collect(dir: String, into: PackedStringArray) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in SCAN_EXT:
			into.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(d), into)


func test_presets_list_the_unused_images() -> void:
	var files := _excluded_files()
	assert_bool(files.has("assets/props/hansan/wreck_banner.png")).is_true()
	assert_bool(files.has("assets/vfx/sea_dragon.png")).is_true()
	# build/ (미리보기 그림·백업 시트)는 gitignore 지만 Godot 은 가져오므로 내보내기에서 빼야 한다
	assert_str(FileAccess.get_file_as_string(PRESETS)).contains("exclude_filter=\"build/*, ")


func test_excluded_images_are_not_referenced_by_the_game() -> void:
	var excluded := _excluded_files()
	var uids := {}
	for p in excluded:
		var id := ResourceLoader.get_resource_uid("res://" + p)
		if id != ResourceUID.INVALID_ID:
			uids[p] = ResourceUID.id_to_text(id)
	var sources := PackedStringArray()
	for d in SCAN_DIRS:
		_collect(d, sources)
	var hits := PackedStringArray()
	for src in sources:
		var body := FileAccess.get_file_as_string(src)
		for p in excluded:
			if body.contains("res://" + p) or (uids.has(p) and body.contains(uids[p])):
				hits.append("%s -> %s" % [src, p])
	assert_array(hits).override_failure_message(
		"내보내기에서 빠진 그림을 게임이 씁니다. export_presets.cfg 제외 목록에서 지우세요: %s" % ", ".join(hits)
	).is_empty()
