extends GdUnitTestSuite
## 무대 노래 구간 넘나들기: 구간 데이터, 넘나드는 스트림, 무대 신호 → 구간.

const SONG := preload("res://data/songs/manchuria_395.tres")


func after_test() -> void:
	GameSettings.want_stage_list = false


func test_every_stage_has_a_complete_song() -> void:
	for id in ["manchuria_395", "gyeongbokgung_1433", "chochungdo", "hansan_1592"]:
		var st := load("res://data/stages/%s.tres" % id) as StageTheme
		assert_object(st.song).is_not_null()
		for sec in StageSong.SECTIONS:
			assert_object(st.song.section_stream(sec)).is_not_null()
		assert_float(st.song.bpm).is_greater(40.0)


func test_interactive_stream_has_named_clips_and_bar_transitions() -> void:
	var s := SONG.interactive()
	assert_int(s.clip_count).is_equal(5)
	for i in 5:
		assert_str(String(s.get_clip_name(i))).is_equal(String(StageSong.SECTIONS[i]))
	assert_object(SONG.interactive()).is_same(s)  # 한 번 만들어 재사용
	assert_bool(s.has_transition(AudioStreamInteractive.CLIP_ANY, 2)).is_true()  # → 후렴
	assert_int(s.get_transition_from_time(AudioStreamInteractive.CLIP_ANY, 2)).is_equal(
		AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BAR)
	assert_bool(s.has_transition(AudioStreamInteractive.CLIP_ANY, 0)).is_true()  # → 전주 (바로)
	var verse := s.get_clip_stream(1) as AudioStreamOggVorbis
	var outro := s.get_clip_stream(3) as AudioStreamOggVorbis
	assert_bool(verse.loop).is_true()
	assert_bool(outro.loop).is_false()
	assert_float(verse.bpm).is_equal(SONG.bpm)
	assert_int(verse.bar_beats).is_equal(SONG.bar_beats)
	assert_bool((SONG.verse as AudioStreamOggVorbis).loop).is_false()  # 원본 파일 리소스는 그대로


func test_play_starts_at_section_then_switches_same_song() -> void:
	var fb: Feedback = auto_free(Feedback.new())
	add_child(fb)
	await get_tree().process_frame
	await get_tree().process_frame
	var p0 := MusicDirector.player()
	if p0:  # 앞선 테스트(메인 장면)가 같은 노래를 틀어 둔 상태일 수 있다: 처음부터 시작하는 경로를 시험
		p0.stop()
		p0.stream = null
	assert_bool(MusicDirector.play(SONG, &"intro", 0.0)).is_true()
	await get_tree().process_frame
	var p := MusicDirector.player()
	assert_object(p.stream).is_same(SONG.interactive())
	assert_int(SONG.interactive().initial_clip).is_equal(0)
	assert_bool(MusicDirector.play(SONG, &"chorus")).is_true()  # 같은 노래: 구간만 바꾼다
	assert_object(p.stream).is_same(SONG.interactive())
	assert_bool(MusicDirector.play(SONG, &"nope")).is_false()
	assert_bool(MusicDirector.play(null, &"verse")).is_false()


func test_main_cues_map_to_sections() -> void:
	var main_script := preload("res://scripts/game/main.gd")
	assert_str(String(main_script.SONG_SECTION[&"stage"])).is_equal("verse")
	assert_str(String(main_script.SONG_SECTION[&"boss"])).is_equal("chorus")
	assert_str(String(main_script.SONG_SECTION[&"victory"])).is_equal("outro")
	assert_str(String(main_script.SONG_SECTION[&"defeat"])).is_equal("intro")


func test_hero_story_plays_that_heros_stage_song() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.intro_seen = true
	GameSettings.tutorial_done = true
	GameSettings.hero_picked = false
	GameSettings.hero_id = &""  # 마지막 영웅 없음 → 영웅 고르기
	GameSettings.story_enabled = true
	GameSettings.hero_stages = {}
	GameSettings.hero_clears = {}
	GameSettings.stage_picked = false
	GameSettings.save_settings()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var sel: HeroSelect = main.hero_select
	var c := sel.slot_rect(0).get_center()
	sel.handle_touch(0, c, true)
	sel.handle_touch(0, c, false)
	await get_tree().process_frame
	var hero: HeroData = main.get_node("Player").hero
	var st: StageTheme = main.stage_by_id(hero.home_stage)
	assert_bool(main.story_intro.is_open()).is_true()
	await get_tree().create_timer(2.0).timeout  # 앞 곡을 줄였다가 바꾼다 (0.8초씩)
	assert_object(MusicDirector.player().stream).is_same(st.song.interactive())
	main.story_intro.finish()
	assert_bool(main.stage_select.is_open()).is_true()  # 이야기 뒤 전장 목록 (같은 곡)
	main.stage_select.press(0)
	await get_tree().create_timer(1.0).timeout
	assert_object(MusicDirector.player().stream).is_same(st.song.interactive())  # 판이 시작돼도 같은 곡
	get_tree().paused = false
	main.queue_free()
	GameSettings.hero_picked = true
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.stage_picked = true
	GameSettings.stage_id = &"manchuria_395"
	GameSettings.save_settings()


func test_scene_has_menu_and_result_tracks() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	assert_object(main.menu_track).is_not_null()
	assert_bool((main.menu_track as AudioStreamOggVorbis).loop).is_true()  # 입장 곡은 반복
	assert_object(main.victory_track).is_not_null()
	assert_object(main.defeat_track).is_not_null()
	assert_bool((main.victory_track as AudioStreamOggVorbis).loop).is_false()
	assert_float(main.victory_track.get_length()).is_less(30.0)
	assert_float(main.defeat_track.get_length()).is_less(30.0)
	main.free()


func test_stage_plays_its_own_song() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.intro_seen = true
	GameSettings.tutorial_done = true
	GameSettings.hero_picked = true
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.stage_picked = true
	GameSettings.stage_id = &"manchuria_395"  # 원정으로 만주를 골랐다
	GameSettings.hero_clears = {}
	GameSettings.save_settings()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	assert_str(String(main.run_config.stage.id)).is_equal("manchuria_395")
	await get_tree().create_timer(1.5).timeout
	var mine: StageSong = main.stage_by_id(&"manchuria_395").song
	assert_object(MusicDirector.player().stream).is_same(mine.interactive())  # 만주에서는 광개토 노래
	get_tree().paused = false
	main.queue_free()
	GameSettings.stage_picked = true
	GameSettings.stage_id = &"manchuria_395"
	GameSettings.save_settings()


func test_every_stage_has_a_boss_version_with_its_own_tempo() -> void:
	for id in ["manchuria_395", "gyeongbokgung_1433", "chochungdo", "hansan_1592"]:
		var song := (load("res://data/stages/%s.tres" % id) as StageTheme).song
		assert_object(song.boss).is_not_null()
		assert_float(song.boss_bpm).is_greater(song.bpm)  # 보스 판이 더 빠르다
		var s := song.interactive()
		assert_int(s.get_transition_from_time(AudioStreamInteractive.CLIP_ANY, 4)).is_equal(
			AudioStreamInteractive.TRANSITION_FROM_TIME_IMMEDIATE)  # 마디를 기다리지 않고 바로
		var boss := s.get_clip_stream(4) as AudioStreamOggVorbis
		assert_bool(boss.loop).is_true()
		assert_float(boss.bpm).is_equal(song.boss_bpm)
		assert_str(String(RunMusic.section_for(&"boss", song))).is_equal("boss")


func test_boss_falls_back_to_chorus_without_a_boss_version() -> void:
	var song := StageSong.new()
	assert_str(String(RunMusic.section_for(&"boss", song))).is_equal("chorus")
	assert_str(String(RunMusic.section_for(&"stage", song))).is_equal("verse")
