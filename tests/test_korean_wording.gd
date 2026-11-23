extends GdUnitTestSuite
## 화면에 나오는 글씨에 외래어가 다시 섞이지 않게: 금지어가 문자열에 있으면 실패 (규칙·예외는 data/ui/wording_rules.json).
## 주석·@export 줄·코드 식별자는 보지 않는다 (화면 글씨만).

const RULES := "res://data/ui/wording_rules.json"


func _rules() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(RULES))


## 한 줄에서 따옴표 안 문자열만 (주석 # 이후는 버림).
static func strings_in(line: String) -> Array[String]:
	var out: Array[String] = []
	var s := line.strip_edges()
	if s.begins_with("#") or s.begins_with("@export"):
		return out
	var inq := false
	var cur := ""
	for i in s.length():
		var ch := s[i]
		if ch == "\"":
			if inq:
				out.append(cur)
				cur = ""
			inq = not inq
		elif inq:
			cur += ch
		elif ch == "#":
			break
	if inq and cur != "":
		out.append(cur)  # 여러 줄 문자열 (.tres)
	return out


func _files(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") or f.ends_with(".tres"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_files(dir.path_join(d), out)


func _offences() -> Array[String]:
	var r := _rules()
	var found: Array[String] = []
	var files: Array[String] = []
	for d in r["scan_dirs"]:
		_files("res://" + String(d), files)
	for path in files:
		if (r["skip_files"] as Array).has(path.trim_prefix("res://")):
			continue
		var in_multiline := false
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var parts: Array[String] = []
			if in_multiline:
				parts.append(line.get_slice("\"", 0))
				in_multiline = line.count("\"") % 2 == 0
				parts.append_array(strings_in("\"" + line.substr(line.find("\"") + 1)) if line.find("\"") >= 0 else [])
			else:
				parts = strings_in(line)
				in_multiline = line.count("\"") % 2 == 1 and path.ends_with(".tres")
			for t in parts:
				for w in r["banned"]:
					if t.contains(w) and not _allowed(r, path, t):
						found.append("%s: %s ← \"%s\"" % [path, w, t])
	return found


func _allowed(r: Dictionary, path: String, text: String) -> bool:
	for a in r["allow"]:
		if path.ends_with(String(a["file"])) and text.contains(String(a["text"])):
			return true
	return false


func test_no_loanwords_in_screen_text() -> void:
	assert_array(_offences()).is_empty()


func test_strings_in_ignores_comments_and_exports() -> void:
	assert_array(strings_in("var a := \"좋다\"  # 카드 \"대시\"")).is_equal(["좋다"])
	assert_array(strings_in("# \"보스\"")).is_empty()
	assert_array(strings_in("@export_group(\"스킬\")")).is_empty()


func test_banned_list_has_the_agreed_words() -> void:
	var b: Array = _rules()["banned"]
	for w in ["레벨", "스킬", "대시", "보스", "카드", "콤보", "스테이지"]:
		assert_bool(b.has(w)).is_true()


func test_proper_names_are_not_banned() -> void:
	# 사무라이는 고유한 이름이라 그대로 쓴다 (금지어 아님)
	for w in _rules()["banned"]:
		assert_bool("왜군 망령 사무라이 대장".contains(w)).is_false()
	assert_bool(_rules()["banned"].has("게임")).is_true()
