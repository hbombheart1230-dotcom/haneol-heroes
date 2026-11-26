extends GdUnitTestSuite
## 주인 영웅 부르기 = 같이 싸우기 (AllyHero, 사용자 2026-11-26): 원정 열두 조합 우두머리전에서 찰 때마다 부르는 봇과
## 안 부르는 봇의 우두머리 시간·서툰 사람(예고 30% 놓침) 승률 ([ally-sim]). 영웅은 자기 무대 물결을 거쳐 온 성장 사본,
## 우두머리는 그 영웅 배율·난이도 0단계 (test_boss_balance_sim과 같은 판). 보고용 (기준은 우두머리 세션이 정한다).
## HH_SLOW=1이면 씨앗 셋 + 서툰 사람, 아니면 씨앗 하나 피하기만. HH_ONLY_HERO로 한 영웅만.

const HEROES := {
	"yi_sun_sin": [90.0, 170.0],
	"gwanggaeto": [110.0, 200.0],
	"sejong": [280.0, 520.0],
	"shin_saimdang": [150.0, 240.0],
}
const HOME := {"yi_sun_sin": "hansan", "gwanggaeto": "manchuria", "sejong": "gyeongbok", "shin_saimdang": "chochung"}
const STAGE := {"hansan": "hansan_1592", "manchuria": "manchuria_395", "gyeongbok": "gyeongbokgung_1433", "chochung": "chochungdo"}
const BOSSES := {
	"hansan": "res://data/enemies/waegun_commander.tres",
	"manchuria": "res://data/enemies/boss_general.tres",
	"gyeongbok": "res://data/enemies/jurchen_chieftain.tres",
	"chochung": "res://data/enemies/cc_frog.tres",
}
static var SEEDS: Array = [11, 23, 37] if OS.get_environment("HH_SLOW") == "1" else [11]
static var SLOPPY: bool = OS.get_environment("HH_SLOW") == "1"
static var ONLY: String = OS.get_environment("HH_ONLY_HERO")


func after_test() -> void:
	BossSim.reset_globals()


func _heroes() -> Array:
	var out: Array = []
	for id: String in HEROES:
		out.append(load("res://data/heroes/%s.tres" % id))
	return out


func _run(boss: String, hero: String, s: int, miss: float, summon: bool) -> Dictionary:
	var c: Array = HEROES[hero]
	var grown: Array = await GrownHeroes.take(self, hero, s, GrownHeroes.At.BOSS)
	var h: HeroData = grown[0]
	var sim := AllyBossSim.new(self)
	sim.use_hero("res://data/heroes/%s.tres" % hero, c[0], c[1])
	sim.hero_override = h
	var curve := ResourceLoader.load("res://data/difficulty/curve.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as DifficultyCurve
	var d := ResourceLoader.load(BOSSES[boss], "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EnemyData
	await sim.setup(curve.scaled(BossHpScale.for_hero(SummonOverride.apply(d), h), 0), s)
	sim.miss_rate = miss
	if summon:
		sim.rules = HomeSummonRules.new()
		var heroes := _heroes()
		var me_base: HeroData = heroes[HEROES.keys().find(hero)]
		assert_bool(sim.rules.begin(heroes, me_base, StringName(STAGE[boss]))).is_true()
	var r := sim.run(BossSim.Bot.DODGE, 200.0)
	r["summons"] = sim.summons
	sim.free_all()
	return r


func test_ally_summon_effect() -> void:
	var rows: Array[String] = []
	AllyPresets.apply(HomeSummonData.get_default(), OS.get_environment("HH_ALLY_PRESET"))  # 느낌 안·배율 바꿔 재기
	print("[ally-sim] ally %s" % AllyPresets.describe(HomeSummonData.get_default()))
	var skip_base := OS.get_environment("HH_SKIP_BASE") == "1"  # 안 부름 쪽은 이미 쟀으면 건너뜀 (시간 절반)
	for hero: String in HEROES:
		if ONLY != "" and hero != ONLY:
			continue
		for boss: String in BOSSES:
			if HOME[hero] == boss:
				continue  # 자기 전장: 주인이 자기라 부르기 없음
			var t := [0.0, 0.0]
			var n := 0
			var sw := [0, 0]
			var calls := 0
			for s in SEEDS:
				for k in 2:
					if skip_base and k == 0:
						continue
					var r: Dictionary = await _run(boss, hero, s, 0.0, k == 1)
					t[k] += float(r["time"]) if r["won"] else 200.0
					if k == 1:
						calls += int(r["summons"])
					if SLOPPY:
						var sl: Dictionary = await _run(boss, hero, s, 0.3, k == 1)
						sw[k] += int(sl["won"])
				n += 1
			var line := "%-10s %-14s 우두머리 평균 안 부름 %.1fs / 부름 %.1fs (%+.0f%%, 부른 횟수 %.1f)" % [boss, hero, t[0] / n, t[1] / n,
				(t[1] / t[0] - 1.0) * 100.0, float(calls) / n]
			if SLOPPY:
				line += "  서툰 사람 이김 %d/%d → %d/%d" % [sw[0], n, sw[1], n]
			print("[ally-sim] " + line)
			rows.append(line)
	assert_bool(rows.is_empty()).is_false()
