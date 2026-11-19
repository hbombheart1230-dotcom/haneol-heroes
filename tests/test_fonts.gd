extends GdUnitTestSuite
## 글꼴은 게임에서 쓰는 글자만 남겼다 (tools/fonts/subset_fonts.py). 새 글자를 쓰고 다시 만들지 않으면 여기서 잡힌다.


func _used_chars() -> Dictionary:
	var chars := {}
	for dir in ["res://data", "res://scripts", "res://scenes"]:
		_collect(dir, chars)
	return chars


func _collect(dir: String, chars: Dictionary) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") or f.ends_with(".tres") or f.ends_with(".tscn"):
			var text := FileAccess.get_file_as_string(dir.path_join(f))
			for i in text.length():
				var c := text.unicode_at(i)
				if (c >= 0xAC00 and c <= 0xD7A3) or (c >= 0x3131 and c <= 0x318E):  # 한글 음절·자모 (영문·숫자는 항상 들어 있다)
					chars[c] = true
	for d in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(d), chars)


func test_title_and_body_fonts_cover_every_hangul_in_the_game() -> void:
	var missing := []
	for font in [UiStyle.TITLE_FONT, UiStyle.BODY_FONT]:
		for c in _used_chars():
			if not (font as Font).has_char(c):
				missing.append(String.chr(c))
	assert_array(missing).override_failure_message("글꼴에 없는 글자: %s → tools/fonts/subset_fonts.py 다시 실행" % "".join(missing)).is_empty()
