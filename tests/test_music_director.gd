extends GdUnitTestSuite
## 무대 노래 구간 넘나들기: 구간 데이터, 넘나드는 스트림, 무대 신호 → 구간.

const SONG := preload("res://data/songs/manchuria_395.tres")


func test_every_stage_has_a_complete_song() -> void:
	for id in ["manchuria_395", "gyeongbokgung_1433", "chochungdo", "hansan_1592"]:
		var st := load("res://data/stages/%s.tres" % id) as StageTheme
		assert_object(st.song).is_not_null()
		for sec in StageSong.SECTIONS:
			assert_object(st.song.section_stream(sec)).is_not_null()
		assert_float(st.song.bpm).is_greater(40.0)


func test_interactive_stream_has_named_clips_and_bar_transitions() -> void:
	var s := SONG.interactive()
	assert_int(s.clip_count).is_equal(4)
	for i in 4:
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
	GameSettings.intro_seen = true
	GameSettings.tutorial_done = true
	GameSettings.hero_picked = false
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
	await get_tree().create_timer(1.0).timeout
	assert_object(MusicDirector.player().stream).is_same(st.song.interactive())  # 판이 시작돼도 같은 곡
	get_tree().paused = false
	main.queue_free()
	GameSettings.hero_picked = true
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.stage_picked = true
	GameSettings.stage_id = &"manchuria_395"
	GameSettings.save_settings()
