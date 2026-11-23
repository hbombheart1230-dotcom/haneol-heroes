extends GdUnitTestSuite
## 나머지 세 무대 보스전 균형 (tests/boss_sim.gd, 한산 test_boss_sim과 같은 방식): 무대 주인 영웅으로
## 가만히 있으면 지고, 예고를 보고 피하며 틈에 치면 두 번의 단계 전환을 거쳐 목표 시간 안에 이긴다.
## 같은 씨앗이면 실행·순서와 상관없이 같은 결과. 결과는 로그([boss-sim])에 남긴다.

const SEEDS := [11, 23, 37]
## 보스, 무대 주인 영웅, 붙는 거리, 탭 거리 (원거리 세종은 멀리 서서 쏜다).
const CASES := {
	"manchuria": ["res://data/enemies/boss_general.tres", "res://data/heroes/gwanggaeto.tres", 110.0, 200.0],
	"gyeongbok": ["res://data/enemies/jurchen_chieftain.tres", "res://data/heroes/sejong.tres", 280.0, 520.0],
	"chochung": ["res://data/enemies/cc_frog.tres", "res://data/heroes/shin_saimdang.tres", 150.0, 240.0],
}
## 피하는 사람이 이기는 시간 범위(초) (한산 35~65, 목표 약 50초).
const WIN_MIN := 35.0
const WIN_MAX := 65.0
## 보스가 이 시간(초)보다 오래 공격하지 않으면 막힌 것 (단계 전환·소환 한 박자 포함).
const MAX_GAP := 7.0


func after_test() -> void:
	BossSim.reset_globals()


func _trials(stage: String, label: String, bot: BossSim.Bot, miss: float = 0.0) -> Array:
	var c: Array = CASES[stage]
	var out: Array = []
	for s in SEEDS:
		var sim := BossSim.new(self)
		sim.use_hero(c[1], c[2], c[3])
		await sim.setup(ResourceLoader.load(c[0], "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EnemyData, s)
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


## 이김 · 두 번 전환 · 목표 시간 · 같은 공격 연속 없음 (이어치기 제외) · 막힘 없음.
func _check_dodge_wins(stage: String) -> void:
	var rs: Array = await _trials(stage, "dodge", BossSim.Bot.DODGE)
	assert_int(_count(rs, "won")).override_failure_message("%s dodge should win" % stage).is_equal(SEEDS.size())
	for r: Dictionary in rs:
		assert_int(r["phase"]).is_equal(2)
		assert_float(r["time"]).override_failure_message("%s time %.1f" % [stage, r["time"]]).is_between(WIN_MIN, WIN_MAX)
		var w: Array = r["struck"]
		for i in range(1, w.size()):
			var prev: EnemyAttackData = w[i - 1]
			if prev.follow_up == w[i]:
				continue  # 군령 이어치기 (돌진 → 되돌아 돌진 등)
			assert_int(int((w[i] as EnemyAttackData).kind)).override_failure_message(
				"%s same attack twice at %d" % [stage, i]).is_not_equal(int(prev.kind))
		for g in r["gaps"]:
			assert_float(g).override_failure_message("%s boss stalled %.2fs" % [stage, g]).is_less(MAX_GAP)
		assert_int(r["max_minions"]).is_less_equal(3)


func test_manchuria_idle_loses() -> void:
	await _check_idle_loses("manchuria")


func test_manchuria_dodge_wins() -> void:
	await _check_dodge_wins("manchuria")


func test_gyeongbok_idle_loses() -> void:
	await _check_idle_loses("gyeongbok")


func test_gyeongbok_dodge_wins() -> void:
	await _check_dodge_wins("gyeongbok")


func test_chochung_idle_loses() -> void:
	await _check_idle_loses("chochung")


func test_chochung_dodge_wins() -> void:
	await _check_dodge_wins("chochung")


## 서툰 사람 (예고 셋에 하나는 못 피함): 보고용.
func test_sloppy_report() -> void:
	for stage in CASES:
		var rs: Array = await _trials(stage, "sloppy", BossSim.Bot.DODGE, 0.3)
		assert_int(rs.size()).is_equal(SEEDS.size())
