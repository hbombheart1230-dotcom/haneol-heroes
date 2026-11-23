extends GdUnitTestSuite
## 우두머리 패턴 보고 (HH_PATTERN=1일 때만, 보고서용 — 수치를 바꾸지 않는다): 성장한 영웅(tests/grown_heroes.gd)으로
## 네 보스 × 네 영웅, 네 중간 우두머리 × 무대 주인 영웅. 피하기·서툰 사람 각 씨앗 셋.
## 한 줄: 보스가 휘청(멈춤)/예고/회복/쉼에 쓴 시간 비율, 공격 종류별 예고 수·맞은 수, 영웅과의 평균 거리.

const BOSSES := {
	"hansan": "res://data/enemies/waegun_commander.tres",
	"manchuria": "res://data/enemies/boss_general.tres",
	"gyeongbok": "res://data/enemies/jurchen_chieftain.tres",
	"chochung": "res://data/enemies/cc_frog.tres",
}
const MIDS := {
	"waegun_elite": "yi_sun_sin", "elite_warrior": "gwanggaeto", "jurchen_elite": "sejong", "cc_mantis": "shin_saimdang",
}
const HEROES := {"yi_sun_sin": [90.0, 170.0], "gwanggaeto": [110.0, 200.0], "sejong": [280.0, 520.0], "shin_saimdang": [150.0, 240.0]}
const KIND := ["SLAM", "SHOOT", "SHOCKWAVE", "CONE", "CHARGE", "PULL", "THRUST"]


func after_test() -> void:
	BossSim.reset_globals()


func _fight(path: String, hero: String, s: int, miss: float, at: GrownHeroes.At) -> Dictionary:
	var grown: Array = await GrownHeroes.take(self, hero, s, at)
	var c: Array = HEROES[hero]
	var sim := BossSim.new(self)
	sim.use_hero("res://data/heroes/%s.tres" % hero, c[0], c[1])
	sim.hero_override = grown[0]
	var d := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EnemyData
	await sim.setup(BossHpScale.for_hero(d, grown[0]), s)
	sim.miss_rate = miss
	var r := sim.run(BossSim.Bot.DODGE, 200.0)
	sim.free_all()
	return r


func _line(label: String, r: Dictionary) -> String:
	var t: float = maxf(r["time"], 0.01)
	var starts := {}
	for w in r["windups"]:
		var k: String = KIND[int(w[1])]
		starts[k] = int(starts.get(k, 0)) + 1
	var hits := {}
	for key in r["hits"]:
		if String(key).begins_with("boss_"):
			hits[KIND[int(String(key).substr(5))]] = r["hits"][key]
	return "[pattern] %s: %s %.1fs, damage %d | stun %.0f%% windup %.0f%% recover %.0f%% idle %.0f%% | dist %.0f | starts %s hits %s" % [
		label, "WIN" if r["won"] else "LOSE", r["time"], r["damage"], r["boss_stun"] / t * 100.0, r["boss_windup"] / t * 100.0,
		r["boss_recover"] / t * 100.0, r["boss_idle"] / t * 100.0, r["dist"] / t, str(starts), str(hits)]


func test_pattern_report() -> void:
	if OS.get_environment("HH_PATTERN") != "1":
		assert_bool(true).is_true()
		return
	for b in BOSSES:
		for h in HEROES:
			for s in [11, 23, 37]:
				for miss in [0.0, 0.3]:
					print(_line("%s %s seed %d %s" % [b, h, s, "dodge" if miss == 0.0 else "sloppy"],
						await _fight(BOSSES[b], h, s, miss, GrownHeroes.At.BOSS)))
	for m in MIDS:
		for s in [11, 23, 37]:
			for miss in [0.0, 0.3]:
				print(_line("mid %s %s seed %d %s" % [m, MIDS[m], s, "dodge" if miss == 0.0 else "sloppy"],
					await _fight("res://data/enemies/%s.tres" % m, MIDS[m], s, miss, GrownHeroes.At.MID)))
	assert_bool(true).is_true()
