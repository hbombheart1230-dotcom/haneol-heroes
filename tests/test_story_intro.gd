extends GdUnitTestSuite
## 이야기 인트로: 시간 계산, 누르면 다음 장면, 건너뛰기, 입장 → 인트로(처음 한 번) → 영웅 고르기.

const INTRO := preload("res://data/intro/story_intro.tres")


func test_timeline_slides_fades_and_lines() -> void:
	var tl := IntroTimeline.new(PackedFloat32Array([5.0, 4.0]), 0.8)
	assert_float(tl.total()).is_equal(9.0)
	assert_int(tl.slide_at(0.0)).is_equal(0)
	assert_int(tl.slide_at(5.1)).is_equal(1)
	assert_int(tl.slide_at(9.0)).is_equal(2)
	assert_float(tl.black(0, 0.0)).is_equal(1.0)
	assert_float(tl.black(0, 2.5)).is_equal(0.0)
	assert_float(tl.black(0, 4.7)).is_greater(0.5)
	assert_float(tl.line_alpha(0, 0, 3, 0.5)).is_equal(0.0)
	assert_float(tl.line_alpha(0, 0, 3, 0.8 + IntroTimeline.LINE_IN)).is_equal(1.0)
	assert_float(tl.line_time(0, 2, 3)).is_greater(tl.line_time(0, 1, 3))
	assert_float(tl.line_time(0, 2, 3)).is_less(5.0 * 0.75)
	assert_float(tl.skip_target(1.0)).is_equal_approx(4.2, 0.001)


func test_intro_data_is_complete() -> void:
	assert_int(INTRO.slides.size()).is_greater_equal(4)
	for s in INTRO.slides:
		assert_object(s.image).is_not_null()
		assert_bool(s.lines.size() > 0 or s.caption != "").is_true()
		assert_float(s.duration).is_greater(INTRO.fade * 2.0 + IntroTimeline.LINE_IN)


func test_tap_goes_to_next_slide_and_skip_finishes() -> void:
	var intro: StoryIntro = auto_free(StoryIntro.new())
	intro.size = Vector2(720, 1280)
	add_child(intro)
	var done := [0]
	intro.finished.connect(func() -> void: done[0] += 1)
	intro.open(INTRO)
	intro.t = 1.0
	intro.handle_touch(0, Vector2(360, 640), true)
	intro.handle_touch(0, Vector2(360, 640), false)
	intro._process(INTRO.fade + 0.01)
	assert_int(intro.timeline.slide_at(intro.t)).is_equal(1)
	var c := intro.skip_rect().get_center()
	intro.handle_touch(0, c, true)
	intro.handle_touch(0, c, false)
	assert_int(done[0]).is_equal(1)
	assert_bool(intro.is_open()).is_false()


func test_intro_finishes_by_itself() -> void:
	var intro: StoryIntro = auto_free(StoryIntro.new())
	add_child(intro)
	var done := [0]
	intro.finished.connect(func() -> void: done[0] += 1)
	intro.open(INTRO)
	intro._process(intro.timeline.total() + 0.1)
	assert_int(done[0]).is_equal(1)


func test_enter_prologue_hero_hero_story_then_run() -> void:
	GameSettings.settings_path = "user://test_settings.cfg"
	GameSettings.unlock_all_override = 0  # 정식판 흐름 (전장 고르기 없음)
	GameSettings.title_seen = false
	GameSettings.intro_seen = false
	GameSettings.seen_stories = PackedStringArray()
	GameSettings.hero_picked = false
	GameSettings.stage_picked = false
	GameSettings.hero_stages = {}
	GameSettings.save_settings()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var title: TitleScreen = main.title_screen
	title._process(0.5)
	var b := title.button_rect().get_center()
	title.handle_touch(0, b, true)
	title.handle_touch(0, b, false)
	var intro: StoryIntro = main.story_intro
	assert_bool(intro.is_open()).is_true()  # 입장 → 공통 이야기 먼저
	assert_object(intro.data).is_same(INTRO)
	intro.finish()
	assert_bool(GameSettings.intro_seen).is_true()
	var sel: HeroSelect = main.hero_select
	assert_bool(sel.is_open()).is_true()
	var c := sel.slot_rect(0).get_center()
	sel.handle_touch(0, c, true)
	sel.handle_touch(0, c, false)
	var hero: HeroData = main.get_node("Player").hero
	assert_bool(intro.is_open()).is_true()  # 영웅 고른 뒤 그 영웅 이야기
	assert_object(intro.data).is_same(hero.story)
	intro.finish()
	assert_bool(GameSettings.seen_stories.has(String(hero.id))).is_true()
	assert_bool(main.waiting_pick).is_false()
	assert_str(String(main.run_config.stage.id)).is_equal(String(hero.home_stage))  # 그 영웅의 무대로
	get_tree().paused = false
	main.queue_free()
	GameSettings.unlock_all_override = -1
	GameSettings.title_seen = true
	GameSettings.hero_picked = true
	GameSettings.stage_picked = true
	GameSettings.stage_id = &"manchuria_395"
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.save_settings()


func test_every_hero_has_a_complete_story() -> void:
	for h in ["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"]:
		var hero := load("res://data/heroes/%s.tres" % h) as HeroData
		assert_object(hero.story).is_not_null()
		assert_int(hero.story.slides.size()).is_equal(5)
		for s in hero.story.slides:
			assert_object(s.image).is_not_null()
			assert_int(s.lines.size()).is_greater(0)


func test_intro_skipped_when_already_seen() -> void:
	GameSettings.settings_path = "user://test_settings.cfg"
	GameSettings.title_seen = false
	GameSettings.intro_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.hero_picked = false
	GameSettings.save_settings()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var title: TitleScreen = main.title_screen
	title._process(0.5)
	var b := title.button_rect().get_center()
	title.handle_touch(0, b, true)
	title.handle_touch(0, b, false)
	assert_bool(main.story_intro.is_open()).is_false()
	assert_bool(main.hero_select.is_open()).is_true()
	get_tree().paused = false
	main.queue_free()
	GameSettings.title_seen = true
	GameSettings.hero_picked = true
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.save_settings()
