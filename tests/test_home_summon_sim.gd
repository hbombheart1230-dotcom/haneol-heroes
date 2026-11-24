extends GdUnitTestSuite
## 주인 영웅 부르기 한 번이 우두머리 체력의 얼마를 깎는지 (보스 시뮬 한 줄, [summon-sim]): 원정 열두 조합 모두
## (고른 영웅 넷 × 남의 전장 셋), 우두머리 체력은 그 영웅 배율(BossHpScale)을 곱한 실제 판 값. 우두머리는 영웅 앞 BOSS_AT에
## 서 있고 (붙어 싸우다 누르는 때), 부른 기술이 끝날 때까지 실제 물리 틀로 굴린다 (BossSim의 손 굴림은 판정 영역·큰 몸
## 우두머리 피격 원을 다 따라가지 못해 실제 게임보다 적게 나온다). HomeSummonData.boss_share_min~max 안이어야 한다.

const HEROES := ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]
const STAGES := {"yi_sun_sin": "hansan_1592", "gwanggaeto": "manchuria_395", "sejong": "gyeongbokgung_1433",
	"shin_saimdang": "chochungdo"}
const BOSS_AT := Vector2(0, -150)
const LIMIT := 5.0


func after_test() -> void:
	BossSim.reset_globals()


func _hero(id: String) -> HeroData:
	return ResourceLoader.load("res://data/heroes/%s.tres" % id, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as HeroData


## [우두머리 체력 중 깎은 비율, 주인 영웅 id]
func _share(player_id: String, stage_id: String) -> Array:
	var heroes: Array = []
	for id in HEROES:
		heroes.append(_hero(id))
	var me: HeroData = heroes[HEROES.find(player_id)]
	var stage := ResourceLoader.load("res://data/stages/%s.tres" % stage_id, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageTheme
	var boss_data := BossHpScale.for_hero(stage.boss, me)
	var sim := BossSim.new(self)
	sim.hero_override = me
	await sim.setup(boss_data, 7, BOSS_AT)
	sim.player.grant_invulnerability(1000.0)
	var rules := HomeSummonRules.new()
	assert_bool(rules.begin(heroes, me, StringName(stage_id))).is_true()
	var k := rules.damage_scale(boss_data, stage.boss)
	var run := HomeSummonCast.cast(sim.caster, rules.home, rules.skill(), rules.data.charge, k)
	assert_object(run).is_not_null()
	var t := 0.0
	while t < LIMIT and is_instance_valid(sim.boss) and not sim.boss.health.is_dead():
		await get_tree().physics_frame  # 기술이 남긴 노드(탄·판정 영역·박자 타격)는 실제 물리 틀로 (게임과 같게)
		t += BossSim.DT
		sim._t += BossSim.DT
		Engine.time_scale = 1.0
		var done := run.finished or run.tick(BossSim.DT)
		if done and t > 3.0:
			break
	var hp := sim.boss.health
	var share := float(hp.max - hp.current) / float(hp.max)
	var home := String(rules.home.id)
	sim.free_all()
	return [share, home]


func test_one_summon_takes_a_tenth_of_the_boss() -> void:
	var d := HomeSummonData.get_default()
	var by_home := {}
	for me in HEROES:
		for home in HEROES:
			if home == me:
				continue
			var r: Array = await _share(me, STAGES[home])
			print("[summon-sim] %s at %s (home %s): %.1f%% of boss hp" % [me, STAGES[home], r[1], r[0] * 100.0])
			assert_str(r[1]).is_equal(home)
			by_home.get_or_add(home, []).append(r[0])
			assert_float(r[0]).is_between(d.boss_share_min, d.boss_share_max)
	for home in by_home:
		var xs: Array = by_home[home]
		print("[summon-sim] home %s mean %.1f%%" % [home, xs.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / xs.size() * 100.0])
