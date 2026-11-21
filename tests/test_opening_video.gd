extends GdUnitTestSuite
## 오프닝 영상: 앱을 켜면 입장 화면 앞에 한 번, 누르면 건너뜀, 끝나면 입장 화면.

const VIDEO := preload("res://assets/video/opening.ogv")


func test_opening_skips_on_tap_and_emits_once() -> void:
	var ov: OpeningVideo = auto_free(OpeningVideo.new())
	ov.size = Vector2(720, 1280)
	ov.stream = VIDEO
	add_child(ov)
	var n := [0]
	ov.finished.connect(func() -> void: n[0] += 1)
	ov.open()
	assert_bool(ov.is_open()).is_true()
	assert_bool(ov.handle_touch(0, true)).is_false()  # 열리자마자는 무시
	ov._process(0.5)
	ov.handle_touch(0, true)
	ov.handle_touch(0, false)
	assert_bool(ov.is_open()).is_false()
	assert_int(n[0]).is_equal(1)
	assert_object(ov.player).is_null()


func test_video_rect_fits_portrait_screen() -> void:
	var ov: OpeningVideo = auto_free(OpeningVideo.new())
	ov.size = Vector2(720, 1560)
	add_child(ov)
	var r := ov.video_rect()
	assert_bool(Rect2(Vector2.ZERO, ov.size).encloses(r.grow(-0.5))).is_true()
	assert_float(r.size.x).is_equal_approx(720.0, 0.5)


func test_app_start_plays_opening_then_title() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.opening_seen = false
	GameSettings.title_seen = false
	GameSettings.save_settings()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	assert_bool(main.opening_video.is_open()).is_true()
	assert_bool(main.title_screen.is_open()).is_false()
	main.opening_video.finish()
	assert_bool(GameSettings.opening_seen).is_true()
	assert_bool(main.title_screen.is_open()).is_true()
	get_tree().paused = false
	main.queue_free()
	GameSettings.title_seen = true
	GameSettings.hero_picked = true
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.save_settings()


func test_title_music_starts_with_opening_and_continues() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.opening_seen = false
	GameSettings.title_seen = false
	GameSettings.save_settings()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(1.2).timeout
	var p := MusicDirector.player()
	assert_object(p.stream).is_same(main.menu_track)  # 영상과 함께 입장 곡
	var pos := p.get_playback_position()
	main.opening_video.finish()
	await get_tree().process_frame
	assert_object(p.stream).is_same(main.menu_track)
	assert_float(p.get_playback_position()).is_greater_equal(pos)  # 처음부터 다시가 아니라 이어서
	get_tree().paused = false
	main.queue_free()
	GameSettings.title_seen = true
	GameSettings.hero_picked = true
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.save_settings()
