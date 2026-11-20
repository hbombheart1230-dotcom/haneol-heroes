extends GdUnitTestSuite
## 영웅별 무대 순서: 자기 무대에서 시작, 이기면 "다음 전장" (끝이면 처음으로), 진행은 영웅마다 저장.

const IDS := ["manchuria_395", "gyeongbokgung_1433", "chochungdo", "hansan_1592"]
const HEROES := {"gwanggaeto": "manchuria_395", "sejong": "gyeongbokgung_1433",
	"shin_saimdang": "chochungdo", "yi_sun_sin": "hansan_1592"}


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
	GameSettings.intro_seen = true
	GameSettings.tutorial_done = true
	GameSettings.hero_clears = {}
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.hero_picked = true
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.stage_picked = false
	GameSettings.hero_stages = {"gwanggaeto": "chochungdo"}
	GameSettings.save_settings()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	assert_str(String(main.run_config.stage.id)).is_equal("hansan_1592")
	main.state.result = GameState.Result.VICTORY
	main._on_ended(GameState.Result.VICTORY)
	assert_str(String(main.hud.next_stage.id)).is_equal("manchuria_395")  # 결과 화면 "다음 전장"
	main.advance_stage()
	assert_str(String(GameSettings.hero_stages["yi_sun_sin"])).is_equal("manchuria_395")
	assert_str(String(GameSettings.hero_stages["gwanggaeto"])).is_equal("chochungdo")  # 다른 영웅 진행은 그대로
	assert_array(Array(GameSettings.cleared_stages)).contains(["hansan_1592"])
	get_tree().paused = false
	main.queue_free()
	GameSettings.hero_stages = {}
	GameSettings.hero_clears = {}
	GameSettings.cleared_stages = PackedStringArray()
	GameSettings.stage_picked = true
	GameSettings.stage_id = &"manchuria_395"
	GameSettings.save_settings()
