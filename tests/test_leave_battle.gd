extends GdUnitTestSuite
## 실기 결함 (2026-11-24): 판 중 설정 "전장 나가기"를 하면 앱이 꺼진다.
## 실제 누름 경로를 따로 띄운 Godot에서 돌린다 (tests/leave_battle_drive.gd): main.tscn을 현재 장면으로,
## 톱니 → 전장 나가기 → 확인을 판 중·결과 화면·조작 안내 중·우두머리전 중에, 그리고 안드로이드 뒤로 가기.
## 장면을 정말 다시 불러오므로 이 시험 장면 안에서는 못 한다. 스크립트 오류 한 줄도 실패로 본다.

const DRIVE := "res://tests/leave_battle_drive.gd"


func _drive() -> PackedStringArray:
	var out: Array = []
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", DRIVE])
	var code := OS.execute(OS.get_executable_path(), args, out, true)
	var lines := PackedStringArray()
	for chunk in out:
		for l in String(chunk).split("\n"):
			lines.append(l.strip_edges())  # 윈도 줄 끝 \r 없이
	lines.append("EXIT %d" % code)
	return lines


func test_leave_battle_returns_to_stage_list_on_every_screen_and_back_never_quits() -> void:
	var lines := _drive()
	var steps := 0
	var bad: Array[String] = []
	for l in lines:
		if l.begins_with("STEP ok"):
			steps += 1
		elif l.begins_with("FAIL") or l.contains("SCRIPT ERROR"):
			bad.append(l)
	assert_array(bad).override_failure_message("\n".join(lines)).is_empty()
	assert_bool(lines.has("DRIVE DONE fails=0")).override_failure_message("\n".join(lines)).is_true()
	assert_int(steps).is_greater_equal(39)
	assert_bool(lines.has("EXIT 0")).is_true()
