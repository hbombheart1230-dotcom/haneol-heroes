extends GdUnitTestSuite
## 나머지 세 무대 보스전 균형 (tests/boss_sim.gd, 한산 test_boss_sim과 같은 방식): 무대 주인 영웅으로
## 가만히 있으면 진다. 피하며 이기는 것·시간·막힘·서툰 사람은 16조합 시험(test_boss_balance_sim)이 본다.
## 같은 씨앗이면 실행·순서와 상관없이 같은 결과. 결과는 로그([boss-sim])에 남긴다.

const SEEDS := [11, 23, 37]
## 보스, 무대 주인 영웅, 붙는 거리, 탭 거리 (원거리 세종은 멀리 서서 쏜다).
const CASES := {
	"manchuria": ["res://data/enemies/boss_general.tres", "res://data/heroes/gwanggaeto.tres", 110.0, 200.0],
	"gyeongbok": ["res://data/enemies/jurchen_chieftain.tres", "res://data/heroes/sejong.tres", 280.0, 520.0],
	"chochung": ["res://data/enemies/cc_frog.tres", "res://data/heroes/shin_saimdang.tres", 150.0, 240.0],
}
func after_test() -> void:
	BossSim.reset_globals()


func _trials(stage: String, label: String, bot: BossSim.Bot, miss: float = 0.0) -> Array:
	var c: Array = CASES[stage]
	var out: Array = []
	for s in SEEDS:
		var sim := BossSim.new(self)
		sim.use_hero(c[1], c[2], c[3])
		var hero := ResourceLoader.load(c[1], "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as HeroData
		var boss := ResourceLoader.load(c[0], "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EnemyData
		await sim.setup(BossHpScale.for_hero(boss, hero), s)  # 게임처럼 영웅 화력만큼 보스 체력
		sim.miss_rate = miss
		var r := sim.run(bot)
		print(BossSim.line("%s %s seed %d" % [stage, label, s], r))
		sim.free_all()
		out.append(r)
	return out


func _count(rs: Array, key: String) -> int:
	return rs.filter(func(r: Dictionary) -> bool: return r[key]).size()


func _check_idle_loses(stage: String) -> void:
	var rs: Array = await _trials(stage, "idle", BossSim.Bot.IDLE)
	assert_int(_count(rs, "lost")).override_failure_message("%s idle should lose" % stage).is_equal(SEEDS.size())


func test_manchuria_idle_loses() -> void:
	await _check_idle_loses("manchuria")


func test_gyeongbok_idle_loses() -> void:
	await _check_idle_loses("gyeongbok")


func test_chochung_idle_loses() -> void:
	await _check_idle_loses("chochung")

