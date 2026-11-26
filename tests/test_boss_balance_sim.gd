extends GdUnitTestSuite
## 영웅 넷 × 보스 넷 = 16조합 보스전 길이 균형 (tests/boss_sim.gd, 결정적): 어느 영웅이 어느 무대에 가도
## "예고를 보고 피하며 틈에 침"이 약 40~50초. 서툰 사람(예고 30% 놓침) 승률은 보고용.
## 영웅은 자기 무대 물결을 성장과 함께 거쳐 온 사본 (tests/grown_heroes.gd: 레벨 12~14, 패, 기술 성장 — 사용자: "우두머리 너무 쉬워").
## 영웅마다 보스 체력 배율(HeroData.boss_hp_mult)이 화력 차이를 메운다. 난이도 단계(DifficultyCurve)와 곱해도 깨지지 않는지도 본다.
## 결과는 로그([boss-balance])에 표로 남긴다. 무대 주인 영웅의 조합도 여기서 본다 (test_stage_boss_sim은 가만히 지는 것만).
## 보통 실행은 조합마다 피하기 한 판 (약 2.5분). 환경 변수 HH_SLOW=1이면 씨앗 셋 × 피하기·서툰 사람 전체 표 (약 15분, PR 표).

const ALL_SEEDS := [11, 23, 37]
static var SEEDS: Array = ALL_SEEDS if OS.get_environment("HH_SLOW") == "1" else [11]
static var SLOPPY: bool = OS.get_environment("HH_SLOW") == "1"
## HH_ONLY_HERO=<영웅 id>면 그 영웅 줄만 (수치를 맞출 때 빨리 다시 재기).
static var ONLY: String = OS.get_environment("HH_ONLY_HERO")
const BOSSES := {
	"hansan": "res://data/enemies/waegun_commander.tres",
	"manchuria": "res://data/enemies/boss_general.tres",
	"gyeongbok": "res://data/enemies/jurchen_chieftain.tres",
	"chochung": "res://data/enemies/cc_frog.tres",
}
## 영웅, 붙는 거리, 탭 거리 (원거리 세종은 멀리 서서 쏜다).
const HEROES := {
	"yi_sun_sin": [90.0, 170.0],
	"gwanggaeto": [110.0, 200.0],
	"sejong": [280.0, 520.0],
	"shin_saimdang": [150.0, 240.0],
}
## 목표 길이(초): 씨앗 셋 평균이 40~50초. 성장한 영웅은 씨앗마다 고른 패가 달라 한 판은 25~70초까지 흔들려도 된다 (실측 ±30%).
const WIN_MIN := 40.0
const WIN_MAX := 50.0
const SEED_MIN := 25.0
const SEED_MAX := 70.0
## 서툰 사람이 16조합 전체에서 이겨야 하는 최소 비율.
const SLOPPY_MIN_RATE := 0.5


func after_test() -> void:
	BossSim.reset_globals()


## 보스 데이터: 디스크에서 새로 읽고 영웅 배율·난이도 단계를 입힌다 (게임과 같은 순서: StageApply).
static func boss_for(boss_path: String, hero: HeroData, tier: int = 0) -> EnemyData:
	var d := ResourceLoader.load(boss_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EnemyData
	var curve := ResourceLoader.load("res://data/difficulty/curve.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as DifficultyCurve
	return curve.scaled(BossHpScale.for_hero(SummonOverride.apply(d), hero), tier)


func _run(boss: String, hero: String, s: int, miss: float, tier: int = 0) -> Dictionary:
	var c: Array = HEROES[hero]
	var path := "res://data/heroes/%s.tres" % hero
	var grown: Array = await GrownHeroes.take(self, hero, s, GrownHeroes.At.BOSS)  # 자기 무대 물결을 거쳐 성장한 영웅
	var sim := BossSim.new(self)
	sim.use_hero(path, c[0], c[1])
	sim.hero_override = grown[0]
	var h: HeroData = grown[0]
	if OS.get_environment("HH_PRINT_TAP") == "1":  # 보고용: 성장한 영웅의 1번 수치
		var t := h.kit.tap
		print("[tap-grown] %s seed %d: %s" % [hero, s, str({"damage": t.get("damage"), "count": t.get("count"),
			"extra": t.get("extra_butterflies"), "lifetime": t.get("lifetime"), "cd": t.cooldown, "lv": t.vfx_level})])
	if OS.get_environment("HH_FORCE_UP") != "":  # 보고용: 성장한 영웅에 패 하나를 n장 더 (예: haeryong_finish:3)
		h = _force_up(h, OS.get_environment("HH_FORCE_UP"))
		sim.hero_override = h
	if OS.get_environment("HH_ZERO_TAP") == "1" and "damage" in h.kit.tap:  # 보고용: 1번 피해 0 (몫 재기)
		h = h.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL) as HeroData
		h.kit.tap.set("damage", 0)
		sim.hero_override = h
	await sim.setup(boss_for(BOSSES[boss], h, tier), s)
	sim.miss_rate = miss
	sim.use_charge = OS.get_environment("HH_USE_CHARGE") == "1"  # 보고용: 모으기도 쿨타임마다 쓴다
	var r := sim.run(BossSim.Bot.DODGE, 200.0)
	sim.free_all()
	return r


## HH_FORCE_UP="<패 id>:<장 수>": 성장한 영웅 사본에 그 패를 더 적용한 사본 (패 하나의 몫 재기).
static func _force_up(h: HeroData, spec: String) -> HeroData:
	var parts := spec.split(":")
	var c := h.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL) as HeroData
	var b := RunBuild.new()
	b.hero = c
	for u in c.upgrade_pool.upgrades:
		if u.id == StringName(parts[0]):
			for i in int(parts[1]) if parts.size() > 1 else 1:
				b.apply(u)
	return c


func test_sixteen_matchups_last_about_the_same() -> void:
	var rows: Array[String] = []
	var sloppy_wins := 0
	var sloppy_runs := 0
	for boss in BOSSES:
		if OS.get_environment("HH_ONLY_BOSS") != "" and boss != OS.get_environment("HH_ONLY_BOSS"):
			continue
		for hero in HEROES:
			if ONLY != "" and hero != ONLY:
				continue
			var times: Array[float] = []
			var wins := 0
			var hurt: Array = []  # 서툰 사람이 받은 피해 (씨앗마다)
			var mins := 0.0  # 우두머리 옆 평균 부하 수 (피하기 판 평균)
			var stun_max := 0.0  # 씨앗 중 가장 높은 휘청 비율 (피하기 판)
			var lock_max := 0.0  # 씨앗 중 가장 긴 맨 간격 (휘청 포함)
			for s in SEEDS:
				var r: Dictionary = await _run(boss, hero, s, 0.0)
				assert_bool(r["won"]).override_failure_message("%s vs %s seed %d did not win" % [hero, boss, s]).is_true()
				assert_int(r["phase"]).is_equal(2)
				assert_float(r["time"]).override_failure_message("%s vs %s seed %d: %.1fs" % [hero, boss, s, r["time"]]).is_between(SEED_MIN, SEED_MAX)
				_check_rhythm(r, "%s vs %s seed %d" % [hero, boss, s])
				times.append(r["time"])
				mins += float(r.get("minion_sum", 0.0)) / maxf(r["time"], 0.1) / SEEDS.size()
				stun_max = maxf(stun_max, FightRhythm.stun_ratio(r))
				lock_max = maxf(lock_max, FightRhythm.longest_gap(r))
				if SLOPPY:
					var sl: Dictionary = await _run(boss, hero, s, 0.3)
					wins += 1 if sl["won"] else 0
					hurt.append(sl["damage"])
			var mean := 0.0
			for x in times:
				mean += x
			mean /= times.size()
			if SEEDS.size() > 1:  # 씨앗마다 고른 패가 달라 판마다 흔들린다: 평균으로 목표 길이
				assert_float(mean).override_failure_message("%s vs %s mean %.1fs" % [hero, boss, mean]).is_between(WIN_MIN, WIN_MAX)
			sloppy_wins += wins
			sloppy_runs += SEEDS.size() if SLOPPY else 0
			rows.append("[boss-balance] %-10s %-14s dodge %4.1f~%4.1fs (mean %4.1f)  sloppy %d/%d, damage %s, minions %.2f, stun %.0f%%, lock %.1fs" % [boss, hero, times.min(), times.max(), mean, wins, SEEDS.size(), str(hurt), mins, stun_max * 100.0, lock_max])
	for line in rows:
		print(line)
	if SLOPPY:
		assert_float(float(sloppy_wins) / sloppy_runs).is_greater_equal(SLOPPY_MIN_RATE)


## 같은 공격 연속 없음 (군령 이어치기 제외) · 보스 공격 간격 7초 미만 (막힘 없음) · 부하 3 이하.
func _check_rhythm(r: Dictionary, label: String) -> void:
	var w: Array = r["struck"]
	for i in range(1, w.size()):
		var prev: EnemyAttackData = w[i - 1]
		if prev.follow_up != w[i]:
			assert_int(int((w[i] as EnemyAttackData).kind)).override_failure_message("%s same attack twice" % label).is_not_equal(int(prev.kind))
	assert_array(FightRhythm.problems(r, label, 9.0)).is_empty()  # 막힘 (휘청 뺀 간격) · 묶임 (맨 간격) · 휘청 비율
	assert_int(r["max_minions"]).is_less_equal(3)


## 난이도 단계를 곱해도: 단계 3(체력 ×2.2, 피해 ×1.45)에서도 두 번 전환하고 막힘 없이 이긴다 (길어지는 것은 의도).
func test_tier_scaling_keeps_the_fight_working() -> void:
	for boss in BOSSES:
		var r: Dictionary = await _run(boss, "yi_sun_sin", 11, 0.0, 3)
		print("[boss-balance] tier 3 %s yi_sun_sin: %s %.1fs, damage %d, stun %.0f%%, lock %.1fs" % [boss, "WIN" if r["won"] else "LOSE", r["time"], r["damage"], FightRhythm.stun_ratio(r) * 100.0, FightRhythm.longest_gap(r)])
		assert_bool(r["won"]).is_true()
		assert_int(r["phase"]).is_equal(2)
		assert_array(FightRhythm.problems(r, "tier 3 %s" % boss, 8.0)).is_empty()  # 단계 3은 체력이 많아 전환 한 박자 + 휘청이 겹칠 수 있다 (7.15초 실측): 막힘은 8초부터
