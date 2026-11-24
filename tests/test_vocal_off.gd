extends GdUnitTestSuite
## 노랫소리 끔: 판 중(무대·우두머리) 음악만 반주 반복으로, 첫 화면·이야기·승리·패배는 그대로. 설정 저장, 판 중 바꾸면 끊기지 않고 넘어감.

const SONGS := ["hansan_1592", "manchuria_395", "gyeongbokgung_1433", "chochungdo"]


func before_test() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.vocals_enabled = true


func after_test() -> void:
	GameSettings.vocals_enabled = true
	GameSettings.save_settings()


func _song(id: String) -> StageSong:
	return load("res://data/songs/%s.tres" % id) as StageSong


func test_every_stage_song_has_both_instrumental_loops() -> void:
	for id in SONGS:
		var s := _song(id)
		for boss_part in [false, true]:
			var st := s.vocal_off_stream(boss_part)
			assert_object(st).override_failure_message("%s boss=%s" % [id, boss_part]).is_not_null()
			assert_bool((st as AudioStreamOggVorbis).loop).is_true()
			assert_float(st.get_length()).is_greater(20.0)
		assert_object(s.vocal_off_stream(true)).is_not_same(s.vocal_off_stream(false))
		assert_object(s.vocal_off_stream(false)).is_same(s.vocal_off_stream(false))  # 사본은 한 번만 만든다


func test_original_resources_are_not_looped_by_the_copy() -> void:
	var s := _song("hansan_1592")
	s.vocal_off_stream(false)
	assert_bool((s.instrumental_stage as AudioStreamOggVorbis).loop).is_false()


func test_vocal_off_applies_only_to_stage_and_boss() -> void:
	var s := _song("manchuria_395")
	for k in [&"stage", &"boss", &"victory", &"defeat"]:
		assert_object(RunMusic.vocal_off_stream(k, s)).is_null()  # 켬이면 어느 것도 아님
	GameSettings.vocals_enabled = false
	assert_object(RunMusic.vocal_off_stream(&"stage", s)).is_same(s.vocal_off_stream(false))
	assert_object(RunMusic.vocal_off_stream(&"boss", s)).is_same(s.vocal_off_stream(true))
	assert_object(RunMusic.vocal_off_stream(&"victory", s)).is_null()
	assert_object(RunMusic.vocal_off_stream(&"defeat", s)).is_null()
	assert_object(RunMusic.vocal_off_stream(&"stage", null)).is_null()
	var bare := StageSong.new()  # 반주 파일이 없는 노래는 끔이어도 원곡
	assert_object(RunMusic.vocal_off_stream(&"stage", bare)).is_null()


func test_setting_defaults_on_saves_and_reloads() -> void:
	assert_bool(GameSettings.vocals_enabled).is_true()
	GameSettings.vocals_enabled = false
	GameSettings.save_settings()
	GameSettings.vocals_enabled = true
	GameSettings.load_settings()
	assert_bool(GameSettings.vocals_enabled).is_false()


func test_settings_screen_row_toggles_it() -> void:
	var screen: SettingsScreen = auto_free(SettingsScreen.new())
	screen.size = Vector2(720, 1280)
	add_child(screen)
	screen.open()
	assert_bool(SettingsScreen.ROWS.has(&"vocals")).is_true()
	assert_str(SettingsScreen.LABELS[&"vocals"]).is_equal("노랫소리")
	assert_bool(Rect2(Vector2.ZERO, screen.size).encloses(screen.panel_rect())).is_true()
	assert_bool(bool(screen.value_of(&"vocals"))).is_true()
	screen.set_value(&"vocals", false)
	assert_bool(GameSettings.vocals_enabled).is_false()
	get_tree().paused = false


func test_switching_mid_run_changes_music_without_restarting_the_run() -> void:
	var fb: Feedback = auto_free(Feedback.new())
	add_child(fb)
	var stage: StageTheme = load("res://data/stages/manchuria_395.tres")
	var m: Node2D = auto_free(preload("res://scripts/game/main.gd").new())
	var cfg := RunConfig.new()
	cfg.stage = stage
	m.run_config = cfg
	await get_tree().process_frame
	m.music.cue(&"stage")  # 켬: 원곡 구간
	await get_tree().process_frame
	await get_tree().process_frame
	assert_object(Feedback.current_music()).is_same(stage.song.interactive())
	GameSettings.vocals_enabled = false
	m.music.refresh()
	await get_tree().create_timer(1.3).timeout
	assert_object(Feedback.current_music()).is_same(stage.song.vocal_off_stream(false))
	m.music.cue(&"boss")  # 끔: 우두머리 반복으로
	await get_tree().create_timer(1.3).timeout
	assert_object(Feedback.current_music()).is_same(stage.song.vocal_off_stream(true))
	GameSettings.vocals_enabled = true
	m.music.refresh()
	await get_tree().create_timer(1.3).timeout
	assert_object(Feedback.current_music()).is_same(stage.song.interactive())
