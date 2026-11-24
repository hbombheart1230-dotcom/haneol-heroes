extends GdUnitTestSuite
## 판 밖 영웅 성장 ('나' 안, 2026-11-24): 처음 깬 전장마다 체력·피해 +8%, 3전장마다 기술 시작 단계 +1 (2단계까지),
## 시작 1단계부터 기술 맨 위(5) 단계가 열림. 적은 단계마다 그보다 조금 더 (DifficultyCurve). 점수는 깬 전장 목록 크기.

const CURVE := preload("res://data/difficulty/curve.tres")


func after_test() -> void:
	GrowthApply.reset()


func test_points_multipliers_and_skill_start() -> void:
	var g := HeroGrowth.load_default()
	assert_int(HeroGrowth.points({"yi_sun_sin": PackedStringArray(["hansan_1592", "manchuria_395"])}, &"yi_sun_sin")).is_equal(2)
	assert_int(HeroGrowth.points({}, &"yi_sun_sin")).is_equal(0)
	assert_float(g.hp_mult(0)).is_equal(1.0)
	assert_float(g.hp_mult(4)).is_equal_approx(1.32, 0.0001)
	assert_float(g.damage_mult(12)).is_equal_approx(1.96, 0.0001)
	var starts := []
	for n in [0, 2, 3, 5, 6, 12]:
		starts.append(g.skill_start(n))
	assert_array(starts).is_equal([0, 0, 1, 1, 2, 2])
	assert_bool(g.top_stage_open(2)).is_false()
	assert_bool(g.top_stage_open(3)).is_true()
	assert_str(g.line(0)).is_equal("깬 전장 0")
	assert_str(g.line(4)).is_equal("깬 전장 4 · 영웅 성장 +32% · 기술 1단계 시작")


## 적이 영웅보다 조금 더 오른다: 처치 시간 비(적 체력 ÷ 영웅 피해)·맞는 피해 비(적 공격 ÷ 영웅 체력)가 1.0~1.25.
func test_enemies_rise_a_little_more_than_the_hero() -> void:
	var g := HeroGrowth.load_default()
	for n in range(1, 13):
		var kill := CURVE.hp(n) / g.damage_mult(n)
		var hurt := CURVE.damage(n) / g.hp_mult(n)
		assert_float(kill).override_failure_message("n=%d kill %.3f" % [n, kill]).is_between(1.0, 1.25)
		assert_float(hurt).override_failure_message("n=%d hurt %.3f" % [n, hurt]).is_between(1.0, 1.25)
	assert_float(CURVE.speed(30)).is_equal(1.15)
	assert_float(CURVE.hp(99)).is_equal(CURVE.max_hp_mult)  # 상한은 데이터 값
	assert_int(CURVE.alive_add(99)).is_equal(CURVE.max_alive_cap)


func test_apply_raises_hp_skill_start_and_damage() -> void:
	var yi: HeroData = load("res://data/heroes/yi_sun_sin.tres")
	var p: Player = auto_free(Player.new())
	p.hero = yi
	var b := RunBuild.new()
	b.begin(p, null, null)
	var vfx0 := b.hero.kit.tap.vfx_level
	GrowthApply.apply(b, 6)
	assert_int(b.hero.max_hp).is_equal(roundi(yi.max_hp * 1.48))
	assert_int(b.hero.kit.tap.vfx_level).is_equal(vfx0 + SkillGrowthData.get_default().stage_from[2])
	assert_float(HeroGrowth.run_damage_mult).is_equal_approx(1.48, 0.0001)
	assert_bool(SkillGrowthData.top_open).is_true()
	assert_int(yi.kit.tap.vfx_level).is_equal(vfx0)  # 원본 그대로
	GrowthApply.apply(null, 0)  # 다음 판 (점수 0): 다시 1·닫힘
	assert_float(HeroGrowth.run_damage_mult).is_equal(1.0)
	assert_bool(SkillGrowthData.top_open).is_false()


## 맨 위 단계는 열린 판에서만: 닫혀 있으면 성장 0 판의 단계(0~3)·크기(최대 1.3)가 예전 그대로.
func test_top_skill_stage_only_when_open() -> void:
	var s := SkillGrowthData.get_default()
	SkillGrowthData.top_open = false
	assert_int(s.stage_of(20)).is_equal(3)
	assert_float(s.size_at(20)).is_equal_approx(1.3, 0.0001)
	SkillGrowthData.top_open = true
	assert_int(s.stage_of(8)).is_equal(3)
	assert_int(s.stage_of(9)).is_equal(4)
	assert_float(s.size_at(9)).is_equal_approx(1.45, 0.0001)
	assert_float(s.cap_at(9)).is_equal_approx(0.75, 0.0001)  # 화면 폭 상한 그대로


## 전장 고르기 위 한 줄: 12전장을 다 깨도 폭 안 (720 폭, 22px, x 188부터 오른쪽 16px 여백).
func test_stage_select_line_fits() -> void:
	var g := HeroGrowth.load_default()
	for n in [0, 4, 12, 99]:
		var w := UiStyle.BODY_FONT.get_string_size(g.line(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		assert_float(188.0 + w).override_failure_message(g.line(n)).is_less_equal(704.0)


## 4전장을 깬 영웅 (성장 4) × 단계 4 한 판이 단계 0·성장 0 한 판과 길이가 ±25% 안 (판 안 성장 포함, 한산 씨앗 11).
func test_veteran_run_length_stays_close() -> void:
	var base: Dictionary = await _run(0)
	var vet: Dictionary = await _run(4)
	print("[growth-sim] base total %.1f boss %.1f won %s | vet total %.1f boss %.1f won %s" % [
		base["total"], base["boss_time"], base["won"], vet["total"], vet["boss_time"], vet["won"]])
	assert_bool(vet["won"]).is_true()
	assert_float(float(vet["total"]) / float(base["total"])).is_between(0.75, 1.25)
	assert_float(float(vet["boss_time"]) / maxf(float(base["boss_time"]), 0.1)).is_between(0.75, 1.25)


func _run(n: int) -> Dictionary:
	var st := ResourceLoader.load("res://data/stages/hansan_1592.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageTheme
	var sim := RunSim.new(self)
	await sim.setup_run(st, 11, [], true)
	if n > 0:
		sim.veteran(n, n)
	var r := sim.run_full(0.0)
	sim.free_all()
	BossSim.reset_globals()
	return r
