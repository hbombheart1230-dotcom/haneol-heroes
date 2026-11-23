extends GdUnitTestSuite
## 성장 단계 기본 판정 비율 고르기 근거 (tests/stage_sim.gd): 무대 영웅이 강화 없이(vfx_level 0 = 기본 단계) 물결을 깨는
## 시간을 기본 비율(SkillGrowthData.size[0]) 1.0 / 0.75 / 0.7 / 0.6으로 비교한다. 결과는 로그 [growth-sim].
## 정한 값(데이터 size[0])은 첫 물결을 깨는 시간이 1.0보다 FIRST_WAVE_SLACK배 넘게 늘지 않아야 한다.
## 성장 단계를 켠 기술이 있는 영웅만 (SkillVfxData.growth).

const RATIOS := [1.0, 0.75, 0.7, 0.6]
const SEEDS := [11, 23]
const FIRST_WAVE_SLACK := 1.25
const STAGES := {"yi_sun_sin": "hansan_1592", "gwanggaeto": "manchuria_395", "sejong": "gyeongbokgung_1433",
	"shin_saimdang": "chochungdo"}

var _keep: PackedFloat32Array


func before() -> void:
	_keep = SkillGrowthData.get_default().size


func after_test() -> void:
	SkillGrowthData.get_default().size = _keep
	BossSim.reset_globals()


func _grows(hero: HeroData) -> bool:
	for d in [hero.kit.tap, hero.kit.dash, hero.kit.charge, hero.kit.counter]:
		if SkillGrowthData.applies(d):
			return true
	return false


func _run(stage_id: String, ratio: float, s: int) -> Dictionary:
	var g := SkillGrowthData.get_default()
	var sz := _keep.duplicate()
	sz[0] = ratio
	g.size = sz
	var st := ResourceLoader.load("res://data/stages/%s.tres" % stage_id, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageTheme
	var sim := StageSim.new(self)
	sim.contact = false
	await sim.setup_stage(st, s)
	var r := sim.run_waves()
	sim.free_all()
	return r


func test_base_ratio_keeps_early_clear_speed() -> void:
	for hero_id in STAGES:
		var hero: HeroData = load("res://data/heroes/%s.tres" % hero_id)
		if not _grows(hero):
			continue
		var first := {}
		for r in RATIOS:
			var f := 0.0
			var t := 0.0
			for s in SEEDS:
				var res: Dictionary = await _run(STAGES[hero_id], r, s)
				var cl: Array = res["cleared"]
				f += float(cl[0]) if cl.size() > 0 else 300.0
				t += float(res["time"]) if res["boss"] else 300.0
			first[r] = f / SEEDS.size()
			print("[growth-sim] %s base ratio %.2f: first wave %.1fs, boss at %.1fs" % [hero_id, r, first[r], t / SEEDS.size()])
		var chosen := snappedf(_keep[0], 0.01)
		for r in first:
			if is_equal_approx(float(r), chosen):
				assert_float(first[r]).override_failure_message(hero_id).is_less_equal(first[1.0] * FIRST_WAVE_SLACK)
