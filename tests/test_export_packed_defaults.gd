extends GdUnitTestSuite
## 내보내기에서 값이 사라지는 꼴 지킴이 (2026-11-26, 영웅 대사 #163이 폰에서 처음부터 안 보이던 까닭).
## `@export var x: PackedStringArray = []`처럼 Packed*Array 칸의 기본값을 배열 글자 `[]`로 적으면, 편집기·PC에서는
## .tres 값이 잘 읽히지만 Android 내보내기(텍스트 → 바이너리 변환)에서 그 칸 값이 빠져 폰에서는 빈 배열이 된다
## (Godot 4.7.2, HeroLines.lines·CreditsData 세 칸에서 확인: 내보낸 pck를 --main-pack으로 읽으면 0줄).
## 기본값을 `PackedStringArray()`처럼 그 형의 생성자로 적으면 값이 남는다 (IntroSlide.lines가 그 꼴이라 이야기 글은 멀쩡했다).

const SCAN_DIRS := ["res://scripts"]
const BAD := "@export[^\\n]*var\\s+\\w+\\s*:\\s*Packed\\w+Array\\s*=\\s*\\["


func _collect(dir: String, into: PackedStringArray) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() == "gd":
			into.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(d), into)


func test_no_packed_array_export_with_array_literal_default() -> void:
	var files := PackedStringArray()
	for d in SCAN_DIRS:
		_collect(d, files)
	assert_int(files.size()).is_greater(50)
	var re := RegEx.create_from_string(BAD)
	var bad := PackedStringArray()
	for f in files:
		for m in re.search_all(FileAccess.get_file_as_string(f)):
			bad.append("%s: %s" % [f, m.get_string()])
	assert_array(bad).is_empty()


func test_hero_lines_and_credits_load_with_text() -> void:
	# 편집기에서는 늘 통과하지만, 데이터가 비어 있지 않음을 같이 지킨다 (내보낸 판 점검: tools/shots/hero_line_probe.gd 설명).
	for id in [&"yi_sun_sin", &"gwanggaeto", &"sejong", &"shin_saimdang"]:
		assert_int(HeroLines.for_hero(id).lines.size()).is_equal(HeroLines.Case.size())
	var c := load(CreditsData.PATH) as CreditsData
	assert_int(c.required.size()).is_greater(0)
	assert_int(c.licenses.size()).is_greater(0)
