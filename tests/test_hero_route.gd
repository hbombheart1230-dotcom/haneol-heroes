extends GdUnitTestSuite
## 영웅별 무대 순서: 자기 무대에서 시작, 이기면 "다음 전장" (끝이면 처음으로), 진행은 영웅마다 저장.

const IDS := ["manchuria_395", "gyeongbokgung_1433", "chochungdo", "hansan_1592"]
const HEROES := {"gwanggaeto": "manchuria_395", "sejong": "gyeongbokgung_1433",
	"shin_saimdang": "chochungdo", "yi_sun_sin": "hansan_1592"}


func after_test() -> void:
	GameSettings.want_stage_list = false


func _stages() -> Array[StageTheme]:
	var out: Array[StageTheme] = []
	for id in IDS:
		out.append(load("res://data/stages/%s.tres" % id))
	return out


func test_each_hero_has_its_own_home_stage() -> void:
	for h in HEROES:
		var hero := load("res://data/heroes/%s.tres" % h) as HeroData
		assert_str(String(hero.home_stage)).is_equal(HEROES[h])
		assert_str(String(HeroRoute.current(_stages(), hero, {}))).is_equal(HEROES[h])


func test_next_follows_order_and_wraps() -> void:
	var st := _stages()
	assert_str(String(HeroRoute.next(st, &"manchuria_395"))).is_equal("gyeongbokgung_1433")
	assert_str(String(HeroRoute.next(st, &"hansan_1592"))).is_equal("manchuria_395")
	var yi := load("res://data/heroes/yi_sun_sin.tres") as HeroData
	assert_str(String(HeroRoute.current(st, yi, {"yi_sun_sin": "chochungdo"}))).is_equal("chochungdo")
	assert_str(String(HeroRoute.current(st, yi, {"yi_sun_sin": "nowhere"}))).is_equal("hansan_1592")


func test_victory_tap_goes_to_next_stage_for_that_hero() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.intro_seen = true
	GameSettings.tutorial_done = true
	GameSettings.hero_clears = {}
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.hero_picked = true
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.stage_picked = false
	GameSettings.hero_stages = {"gwanggaeto": "chochungdo"}
	GameSettings.hero_cleared = {}  # 앞 시험이 남긴 다른 영웅 기록이 아래 "다른 영웅 기록은 그대로" 확인을 흐리지 않게
	GameSettings.save_settings()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	assert_str(String(main.run_config.stage.id)).is_equal("hansan_1592")
	var other_before := str(GameSettings.hero_cleared.get("gwanggaeto", PackedStringArray()))  # 메인이 설정을 다시 읽은 뒤의 값
	main.state.result = GameState.Result.VICTORY
	main._on_ended(GameState.Result.VICTORY)
	assert_bool(PackedStringArray(GameSettings.hero_cleared.get("yi_sun_sin", PackedStringArray())).has("hansan_1592")).is_true()
	assert_array(Array(GameSettings.cleared_stages)).contains(["hansan_1592"])
	assert_str(str(GameSettings.hero_cleared.get("gwanggaeto", PackedStringArray()))).is_equal(other_before)  # 다른 영웅 기록은 그대로
	get_tree().paused = false
	main.queue_free()
	GameSettings.hero_stages = {}
	GameSettings.hero_clears = {}
	GameSettings.hero_cleared = {}
	GameSettings.cleared_stages = PackedStringArray()
	GameSettings.stage_picked = true
	GameSettings.stage_id = &"manchuria_395"
	GameSettings.save_settings()


func test_picking_a_hero_starts_at_home_stage() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.intro_seen = true
	GameSettings.tutorial_done = true
	GameSettings.story_enabled = false
	GameSettings.stage_picked = false
	GameSettings.hero_picked = false
	GameSettings.save_settings()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	GameSettings.hero_stages = {"yi_sun_sin": "manchuria_395"}  # 이전에 다음 전장으로 갔어도
	var sel: HeroSelect = main.hero_select
	var yi := -1
	for i in sel.heroes.size():
		if sel.heroes[i].id == &"yi_sun_sin":
			yi = i
	var c := sel.slot_rect(yi).get_center()
	sel.handle_touch(0, c, true)
	sel.handle_touch(0, c, false)
	assert_bool(main.stage_select.is_open()).is_true()  # 고르면 그 영웅의 전장 목록
	main.stage_select.press(0)
	assert_str(String(main.run_config.stage.id)).is_equal("hansan_1592")  # 첫 전장 = 자기 무대
	get_tree().paused = false
	main.queue_free()
	GameSettings.story_enabled = true
	GameSettings.hero_picked = true
	GameSettings.hero_stages = {}
	GameSettings.stage_picked = true
	GameSettings.stage_id = &"manchuria_395"
	GameSettings.save_settings()
