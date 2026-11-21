extends GdUnitTestSuite
## 덕온공주체는 현대 한글 2,788자만 있다. 그 밖의 글자를 쓰면 여기서 잡힌다 (다른 낱말로 바꾼다).
## 공공누리 제3유형(변경 금지)이라 원본 파일 그대로여야 한다 (줄이거나 고치면 해시가 달라진다).

const ORIGINAL_SHA256 := "35ae40e50d3223253a95095de2b5a0340308b9fa18f8b609b608678741610119"


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
	assert_array(missing).override_failure_message("덕온공주체에 없는 글자: %s → 다른 낱말로 바꾼다" % "".join(missing)).is_empty()


func test_font_file_is_the_unmodified_original() -> void:
	assert_str(FileAccess.get_sha256("res://assets/fonts/DeogonPrincess.ttf")).is_equal(ORIGINAL_SHA256)
