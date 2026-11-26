class_name GrownHeroes
extends RefCounted
## 판 안에서 성장한 영웅 사본 (보스·중간 보스 균형 시험이 쓴다): 영웅이 그 무대(원정이면 원정 무대, 주면 stage_id, 비면 자기 무대)를 성장과 함께 (tests/run_growth.gd,
## 피하며 침) 돌다가 중간 보스가 나오는 순간(MID) 또는 보스가 나오는 순간(BOSS)의 RunBuild 영웅 사본.
## 레벨·능력치·고른 패·기술 모습 단계(#95 판정 크기)가 다 들어 있다. 같은 씨앗 = 같은 사본 (한 실행 안에서 기억).

enum At { MID, BOSS }

## 시뮬이 그 무대에서 영웅을 고르는 이름 (StageTheme.hero_hint → StageSim.HEROES).
const HINT := {"yi_sun_sin": "순신", "gwanggaeto": "광개토", "sejong": "세종", "shin_saimdang": "사임당"}
const STAGE_OF := {"yi_sun_sin": "hansan_1592", "gwanggaeto": "manchuria_395", "sejong": "gyeongbokgung_1433",
	"shin_saimdang": "chochungdo"}
static var _cache := {}


## 성장한 영웅 사본과 그때 레벨: [HeroData, level]. await 필요.
## stage_id: 영웅이 자라는 무대 (원정 조합은 그 무대 물결로 — 실제 원정 판과 같게). 비면 자기 무대.
static func take(suite: Node, hero_id: String, s: int, at: At, stage_id: String = "") -> Array:
	var stage := stage_id if stage_id != "" else String(STAGE_OF[hero_id])
	var key := "%s/%s/%d/%d" % [hero_id, stage, s, at]
	if _cache.has(key):
		return _cache[key]
	var st := ResourceLoader.load("res://data/stages/%s.tres" % stage, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageTheme
	st.hero_hint = HINT[hero_id]  # 원정 무대에서도 이 영웅으로
	var sim := RunSim.new(suite)
	await sim.setup_run(st, s, [], true)
	if at == At.MID:
		sim.spawner.elite_spawned.connect(func(_e: Enemy) -> void: sim.stop_now = true)
	sim.run_waves()
	if OS.get_environment("HH_PRINT_PICKS") == "1":  # 보고용: 성장하며 고른 패
		print("[grown-picks] %s seed %d: %s" % [hero_id, s, str(sim.growth.picks)])
	var h := sim.growth.build.hero.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL) as HeroData
	var out := [h, sim.growth.progress.level]
	sim.free_all()
	BossSim.reset_globals()
	_cache[key] = out
	return out
