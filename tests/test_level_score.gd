extends GdUnitTestSuite
## 판 안 레벨: 점수 곡선·카드 계획 (LevelRules), 행동 점수 상한 (ScoreFeed), 레벨업 보상 (RunLevels).

const RULES := preload("res://data/runs/level_rules.tres")
const TABLE := preload("res://data/runs/score_table.tres")
const HEROES := ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]


func _progress() -> RunProgress:
	var cfg := RunConfig.new()
	cfg.levels = RULES
	cfg.score = TABLE
	return RunProgress.new(cfg)


func test_curve_is_front_loaded_and_continues_past_the_table() -> void:
	assert_int(RULES.need(1)).is_less(RULES.need(2))
	assert_int(RULES.need(1)).is_less_equal(14)  # 첫 경지 오름은 졸병 아홉 마리 안팎
	var last := RULES.needs[RULES.needs.size() - 1]
	assert_int(RULES.need(RULES.needs.size() + 1)).is_equal(last + RULES.tail_growth)
	var p := _progress()
	assert_int(p.add_xp(RULES.need(1) + RULES.need(2))).is_equal(2)
	assert_int(p.level).is_equal(3)
	assert_int(p.pending).is_equal(2)  # 레벨업마다 카드 한 장 적립


func test_plan_limits_picks_and_merges_extra_cards() -> void:
	assert_array(RULES.plan(1, false)).is_equal([1])
	assert_array(RULES.plan(2, false)).is_equal([1, 1])
	assert_array(RULES.plan(4, false)).is_equal([1, 2])  # 셋을 쓰고 하나는 합침, 넷째는 다음으로
	assert_int(LevelRules.used(RULES.plan(4, false))).is_equal(3)
	assert_array(RULES.plan(0, false)).is_equal([1])  # 최소 보장
	assert_array(RULES.plan(5, true)).is_equal([2, 2, 1])  # 보스 직전엔 전부
	assert_int(LevelRules.used(RULES.plan(8, true))).is_equal(8)


func test_vfx_and_stats_rise_every_other_level() -> void:
	assert_int(RULES.vfx_bonus(1)).is_equal(0)
	assert_int(RULES.vfx_bonus(2)).is_equal(1)  # 첫 경지 오름에 바로 한 단계 (기본 모습에 오래 머물지 않게)
	assert_int(RULES.vfx_bonus(3)).is_equal(1)
	assert_int(RULES.vfx_bonus(9)).is_equal(4)
	assert_bool(RULES.grants_stats(2)).is_false()
	assert_bool(RULES.grants_stats(3)).is_true()


func test_action_score_has_gap_and_wave_cap() -> void:
	var p := _progress()
	var feed := ScoreFeed.new(p, TABLE)
	var t := [0.0]
	feed.clock = func() -> float: return t[0]
	var got := []
	p.scored.connect(func(kind: StringName, amount: int) -> void: got.append([kind, amount]))
	assert_int(feed.award(&"combo")).is_equal(TABLE.combo_finish)
	assert_int(feed.award(&"combo")).is_equal(0)  # 간격 안에 또
	t[0] += TABLE.combo_gap
	assert_int(feed.award(&"combo")).is_equal(TABLE.combo_finish)
	assert_int(feed.award(&"evade")).is_equal(TABLE.evade)  # 다른 행동은 따로 센다
	for i in TABLE.per_wave_cap + 3:
		t[0] += 10.0
		feed.award(&"counter")
	assert_int(got.filter(func(g: Array) -> bool: return g[0] == &"counter").size()).is_equal(TABLE.per_wave_cap)
	feed.new_wave()
	t[0] += 10.0
	assert_int(feed.award(&"counter")).is_equal(TABLE.counter_hit)  # 숨 고르기 뒤 다시
	feed.active = func() -> bool: return false
	t[0] += 10.0
	assert_int(feed.award(&"evade")).is_equal(0)  # 판이 끝나면 점수 없음


func test_every_hero_has_level_up_stats() -> void:
	for id: String in HEROES:
		var h: HeroData = load("res://data/heroes/%s.tres" % id)
		assert_object(h.level_up).override_failure_message(id).is_not_null()
		assert_int(h.level_up.vfx_level_gain).is_equal(0)  # 기술 모습은 LevelRules.vfx_every로만
		assert_bool(h.level_up.mods.is_empty()).is_false()
		assert_object(h.portrait).override_failure_message(id + " 초상").is_not_null()  # 지금 모델 얼굴 (옛 카드 그림 아님)
		assert_str(h.portrait.resource_path).contains("assets/ui/portraits/")


func test_level_up_in_a_run_raises_stats_and_skill_look_without_pausing() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.hero_picked = true
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.tutorial_done = true
	GameSettings.stage_picked = false
	GameSettings.hero_stages = {}
	GameSettings.hero_clears = {}
	GameSettings.save_settings()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(auto_free(main))
	await get_tree().process_frame
	var hero: HeroData = main.build.hero
	var hp0: int = hero.max_hp
	var vfx0: int = hero.kit.tap.vfx_level
	var p: RunProgress = main.progress
	p.add_xp(p.xp_to_next())  # 2레벨: 모습 한 단계, 능력치는 아직
	assert_int(hero.max_hp).is_equal(hp0)
	assert_int(hero.kit.tap.vfx_level).is_equal(vfx0 + 1)
	assert_bool(main.is_choosing()).is_false()  # 싸움을 멈추지 않는다
	assert_bool(get_tree().paused).is_false()
	p.add_xp(p.xp_to_next())  # 3레벨: 능력치 (모습은 4레벨에 다음 단계)
	assert_int(hero.max_hp).is_greater(hp0)
	assert_int(hero.kit.tap.vfx_level).is_equal(vfx0 + 1)
	assert_int(main.build.level_vfx).is_equal(1)
	assert_int(p.pending).is_equal(2)
	assert_float(main.hud.badge.level_t).is_greater(0.0)  # 레벨업 연출
	GameSettings.hero_stages = {}
	GameSettings.hero_clears = {}


## 초상 원 꼭짓점은 처음 한 번만 만들고 매 프레임 다시 만들지 않는다 (자리만 옮겨 그린다).
func test_badge_portrait_circle_is_built_once() -> void:
	var b := HeroBadge.new()
	b._build_circle()
	var first := b._circle_pts
	b._build_circle()
	assert_int(b._circle_pts.size()).is_equal(40)
	assert_int(b._circle_uvs.size()).is_equal(40)
	assert_bool(b._circle_pts == first).is_true()
	assert_float(b._circle_pts[0].length()).is_equal_approx(HeroBadge.R, 0.01)  # 가운데 0 기준
