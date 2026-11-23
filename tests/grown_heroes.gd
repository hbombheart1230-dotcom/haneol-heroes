class_name GrownHeroes
extends RefCounted
## 판 안에서 성장한 영웅 사본 (보스·중간 보스 균형 시험이 쓴다): 영웅이 자기 무대를 성장과 함께 (tests/run_growth.gd,
## 피하며 침) 돌다가 중간 보스가 나오는 순간(MID) 또는 보스가 나오는 순간(BOSS)의 RunBuild 영웅 사본.
## 레벨·능력치·고른 패·기술 모습 단계(#95 판정 크기)가 다 들어 있다. 같은 씨앗 = 같은 사본 (한 실행 안에서 기억).

enum At { MID, BOSS }

const STAGE_OF := {"yi_sun_sin": "hansan_1592", "gwanggaeto": "manchuria_395", "sejong": "gyeongbokgung_1433",
	"shin_saimdang": "chochungdo"}
static var _cache := {}


## 성장한 영웅 사본과 그때 레벨: [HeroData, level]. await 필요.
static func take(suite: Node, hero_id: String, s: int, at: At) -> Array:
	var key := "%s/%d/%d" % [hero_id, s, at]
	if _cache.has(key):
		return _cache[key]
	var st := ResourceLoader.load("res://data/stages/%s.tres" % STAGE_OF[hero_id], "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageTheme
	var sim := RunSim.new(suite)
	await sim.setup_run(st, s, [], true)
	if at == At.MID:
		sim.spawner.elite_spawned.connect(func(_e: Enemy) -> void: sim.stop_now = true)
	sim.run_waves()
	var h := sim.growth.build.hero.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL) as HeroData
	var out := [h, sim.growth.progress.level]
	sim.free_all()
	BossSim.reset_globals()
	_cache[key] = out
	return out
