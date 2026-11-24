extends GdUnitTestSuite
## 이야기 인트로: 시간 계산, 누르면 다음 장면, 건너뛰기, 입장 → 인트로(처음 한 번) → 영웅 고르기.

const INTRO := preload("res://data/intro/story_intro.tres")


func after_test() -> void:
	GameSettings.want_stage_list = false


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
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.title_seen = false
	GameSettings.opening_seen = true
	GameSettings.intro_seen = false
	GameSettings.seen_stories = PackedStringArray()
	GameSettings.hero_picked = false
	GameSettings.hero_id = &""  # 처음 하는 사람 (마지막 영웅 없음 → 영웅 고르기)
	GameSettings.hero_cleared = {}  # 아직 이긴 전장 없음
	GameSettings.cleared_stages = PackedStringArray()
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
	var list: StageSelect = main.stage_select
	assert_bool(list.is_open()).is_true()  # 영웅 이야기 뒤 그 영웅의 전장 목록
	assert_bool(list.highlight(0)).is_true()  # 처음 하는 사람: 첫 전장이 빛난다
	list.press(0)
	assert_bool(main.waiting_pick).is_false()
	assert_str(String(main.run_config.stage.id)).is_equal(String(hero.home_stage))  # 그 영웅의 첫 전장으로
	get_tree().paused = false
	main.queue_free()
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
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


func _enter(main: Node) -> void:
	var title: TitleScreen = main.title_screen
	title._process(0.5)
	var b := title.button_rect().get_center()
	title.handle_touch(0, b, true)
	title.handle_touch(0, b, false)


func test_prologue_plays_every_time_by_default() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.story_once = false
	GameSettings.title_seen = false
	GameSettings.opening_seen = true
	GameSettings.intro_seen = true  # 전에 봤어도
	GameSettings.hero_picked = false
	GameSettings.save_settings()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	_enter(main)
	assert_bool(main.story_intro.is_open()).is_true()  # 매번 나온다
	get_tree().paused = false
	main.queue_free()
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.hero_picked = true
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.save_settings()


func test_story_once_skips_what_was_seen() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.story_once = true  # 나중에 켤 "다시 안 보기"
	GameSettings.title_seen = false
	GameSettings.opening_seen = true
	GameSettings.intro_seen = true
	GameSettings.tutorial_done = true
	GameSettings.hero_clears = {}
	GameSettings.hero_picked = false
	GameSettings.hero_id = &""  # 마지막 영웅이 없어야 영웅 고르기
	GameSettings.save_settings()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	_enter(main)
	assert_bool(main.story_intro.is_open()).is_false()
	assert_bool(main.hero_select.is_open()).is_true()
	get_tree().paused = false
	main.queue_free()
	GameSettings.story_once = false
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.hero_picked = true
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.save_settings()


func test_next_button_advances_and_last_says_start() -> void:
	var intro: StoryIntro = auto_free(StoryIntro.new())
	intro.size = Vector2(720, 1280)
	add_child(intro)
	intro.open(INTRO)
	intro.t = 1.0
	var c := intro.next_rect().get_center()
	intro.handle_touch(0, c, true)
	intro.handle_touch(0, c, false)
	intro._process(INTRO.fade + 0.01)
	assert_int(intro.timeline.slide_at(intro.t)).is_equal(1)
	assert_bool(intro.is_open()).is_true()
	assert_bool(intro.skip_rect().intersects(intro.next_rect())).is_false()


func test_last_scene_fits_width_and_pins_to_top() -> void:
	var data: IntroData = load("res://data/intro/story_intro.tres")
	var last: IntroSlide = data.slides[data.slides.size() - 1]
	assert_bool(last.fit_width).is_true()  # 네 영웅이 가로로 펼쳐져 있어 좌우를 자르면 안 된다
	assert_bool(data.slides[0].fit_width).is_false()
	var tex := last.image.get_size()
	assert_int(int(tex.x)).is_equal(1024)  # 원본 크기 (줄이지 않음)


func test_title_art_is_never_cropped_and_title_clears_button() -> void:
	var title: TitleScreen = auto_free(TitleScreen.new())
	for vp in [Vector2(1080, 2400), Vector2(720, 1280), Vector2(1080, 2640), Vector2(1080, 1920)]:
		title.size = vp
		var r := title.art_rect(vp)
		assert_float(r.position.y).is_equal(0.0)  # 위쪽에 붙는다
		assert_float(r.size.x).is_less_equal(vp.x + 0.01)
		assert_float(r.size.y).is_less_equal(vp.y + 0.01)
		assert_float(r.size.x / r.size.y).is_equal_approx(941.0 / 1672.0, 0.001)  # 원본 비율 그대로
		var sub_bottom := title._title_center_y(vp) + 100.0 * vp.x / 720.0 + 12.0
		assert_float(sub_bottom).is_less(title.button_rect().position.y)  # 작은 글줄이 단추를 가리지 않는다
