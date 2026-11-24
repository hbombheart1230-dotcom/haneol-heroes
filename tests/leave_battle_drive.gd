extends SceneTree
## "전장 나가기"·뒤로 가기 실제 경로 재현 (test_leave_battle.gd가 따로 띄운 Godot에서 돌린다).
## 진짜 main.tscn을 현재 장면으로 띄우고 Input.parse_input_event로 누른다 (톱니 → 전장 나가기 → 확인).
## 장면을 정말 다시 불러오므로 GdUnit 안에서는 못 돌린다. 줄마다 "STEP"·"FAIL"을 찍고 끝에 "DRIVE DONE".
## godot --headless --path . -s res://tests/leave_battle_drive.gd

var _fails := 0


func _initialize() -> void:
	_run()


func _say(ok: bool, what: String) -> void:
	print(("STEP ok " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1


func _wait(n: int) -> void:
	for i in n:
		await process_frame


## 화면 좌표(720×1280 기준)를 창 좌표로 바꿔 진짜 입력처럼 넣는다 (터치 → 마우스 흉내도 엔진이 만든다).
func _tap(p: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = root.get_final_transform() * p
		e.pressed = pressed
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await _wait(2)


func _back() -> void:
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _wait(2)


func _main() -> Node:
	return current_scene


## 전장 목록에서 첫 전장을 눌러 판을 시작한다.
func _start_run(tutorial: bool) -> Node:
	GameSettings.tutorial_enabled = tutorial
	GameSettings.tutorial_done = not tutorial
	var m := _main()
	await _tap(m.stage_select.card_rect(0).get_center())
	await _wait(30)
	_say(not m.waiting_pick and not paused, "판 시작")
	return m


## 판 중 톱니 → 전장 나가기 → 확인: 앱이 살아 있고 새 장면의 전장 목록이 떠야 한다.
func _leave(where: String) -> void:
	var m := _main()
	var id0 := m.get_instance_id()
	var gear: SettingsButton = m.find_child("SettingsButton", true, false)
	await _tap(gear.center())
	_say(m.settings.is_open(), where + ": 톱니로 설정이 열림")
	_say(m.settings.exit_mode == &"title", where + ": 나가기 방식은 전장 나가기 (끝내기 아님)")
	await _tap(m.settings.exit_rect().get_center())
	_say(m.settings.is_confirming(), where + ": 한 번 더 물음")
	await _tap(m.settings.confirm_yes_rect().get_center())
	await _wait(10)
	var n := _main()
	_say(n != null and n.get_instance_id() != id0, where + ": 장면을 새로 (앱은 그대로)")
	_say(n != null and n.stage_select.is_open() and n.waiting_pick, where + ": 전장 목록으로 돌아옴")


func _run() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.opening_seen = true
	GameSettings.title_seen = true
	GameSettings.hero_picked = true
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.want_stage_list = true
	GameSettings.story_enabled = false
	_say(not bool(ProjectSettings.get_setting("application/config/quit_on_go_back", true)), "뒤로 가기로 앱이 꺼지지 않게 설정")
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(10)
	_say(_main().stage_select.is_open(), "처음엔 전장 목록")
	# 1) 판 중
	await _start_run(false)
	await _leave("판 중")
	# 2) 결과 화면 (짐)
	var m := await _start_run(false)
	m.state.player_died()
	await _wait(30)
	await _leave("결과 화면")
	# 3) 조작 안내 중
	m = await _start_run(true)
	_say(m.tutorial_director != null and m.tutorial_director.running(), "조작 안내가 돌고 있음")
	await _leave("조작 안내 중")
	# 4) 우두머리전 중
	m = await _start_run(false)
	m.spawner.spawn_boss()
	await _wait(60)
	await _leave("우두머리전 중")
	# 5) 안드로이드 뒤로 가기: 판 중이면 설정을 열고(멈춤) 다시 누르면 닫힘, 확인 중이면 확인만 거둠
	m = await _start_run(false)
	await _back()
	_say(m.settings.is_open() and paused, "뒤로 가기(판 중): 설정이 열리고 판이 멈춤")
	await _tap(m.settings.exit_rect().get_center())
	await _back()
	_say(m.settings.is_open() and not m.settings.is_confirming(), "뒤로 가기(확인 중): 확인만 거둠")
	await _back()
	_say(not m.settings.is_open() and not paused, "뒤로 가기(설정): 닫히고 판이 이어짐")
	await _leave("뒤로 가기 뒤")
	# 6) 판 전(전장 목록): 뒤로 가기·톱니 모두 "끝내기"로 묻기만 (확인 전에는 안 꺼짐)
	m = _main()
	await _back()
	_say(m.settings.is_open() and m.settings.exit_mode == &"quit", "뒤로 가기(전장 목록): 설정에 끝내기")
	await _tap(m.settings.exit_rect().get_center())
	_say(m.settings.is_confirming(), "끝내기도 끝낼까요? 로 한 번 더 물음")
	await _tap(m.settings.confirm_no_rect().get_center())
	await _back()
	_say(_main() == m and not m.settings.is_open(), "취소하면 앱 그대로")
	print("DRIVE DONE fails=%d" % _fails)
	quit(1 if _fails > 0 else 0)
