extends GdUnitTestSuite
## 무대 장치가 판을 얼마나 바꾸나 (tests/stage_sim.gd에 장치를 켜고): 한산 포격선을 켜고 끈 판을 같은 씨앗으로 비교.
## 판 길이(보스 등장까지)·받은 피해(영웅 체력 비율)·포격에 맞은 적 수. 결과는 로그 [hazard-sim].
## 봇 둘: 줄을 보고 비키는 봇 / 줄을 무시하는 봇 (가장 많이 맞는 쪽). 성장 단계는 지금 데이터 그대로 (강화 없음 = 기본 단계).
## 원정: 다른 세 영웅도 한산에서 씨앗 하나씩.

const SEEDS := [11, 23, 37]
const HINTS := {"yi_sun_sin": "순신", "gwanggaeto": "광개토", "sejong": "세종", "shin_saimdang": "사임당"}


func after_test() -> void:
	BossSim.reset_globals()


func _run(hero_id: String, s: int, hz: bool, dodge: bool = true) -> Dictionary:
	var st := ResourceLoader.load("res://data/stages/hansan_1592.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageTheme
	st.hero_hint = HINTS[hero_id]
	var sim := StageSim.new(self)
	sim.contact = false
	sim.use_hazards = hz
	sim.dodge_hazards = dodge
	await sim.setup_stage(st, s)
	var r := sim.run_waves()
	sim.free_all()
	var hp := float((load("res://data/heroes/%s.tres" % hero_id) as HeroData).max_hp)
	r["share"] = r["damage"] / hp
	print("[hazard-sim] %s seed %d %s: %s at %.1fs, damage %d (%.2f of hp), strikes %d, enemies hit %d, hero hit %d" % [
		hero_id, s, ("hazard dodge" if dodge else "hazard ignore") if hz else "no hazard",
		"BOSS" if r["boss"] else ("LOSE" if r["lost"] else "TIMEOUT"), r["time"], r["damage"], r["share"],
		r["hz_strikes"], r["hz_enemy_hits"], r["hz_hero_hits"]])
	return r


func _mean(rs: Array, key: String) -> float:
	var t := 0.0
	for r: Dictionary in rs:
		t += float(r[key])
	return t / rs.size()


func test_cannon_line_keeps_hansan_winnable_and_not_slower() -> void:
	var off := []
	var on := []
	var raw := []
	for s in SEEDS:
		off.append(await _run("yi_sun_sin", s, false))
		on.append(await _run("yi_sun_sin", s, true))
		raw.append(await _run("yi_sun_sin", s, true, false))
	print("[hazard-sim] 순신 한산 평균: 장치 없음 %.1fs %.2f / 비킴 %.1fs %.2f (적 %.1f마리 맞음) / 무시 %.1fs %.2f (영웅 %.1f번 맞음)" % [
		_mean(off, "time"), _mean(off, "share"), _mean(on, "time"), _mean(on, "share"), _mean(on, "hz_enemy_hits"),
		_mean(raw, "time"), _mean(raw, "share"), _mean(raw, "hz_hero_hits")])
	for r: Dictionary in on + raw:
		assert_bool(r["boss"]).is_true()  # 장치가 있어도 물결을 다 깬다
		assert_int(r["hz_strikes"]).is_greater(0)
	assert_float(_mean(on, "time")).is_less_equal(_mean(off, "time") * 1.1)  # 포격이 적을 지우니 길어지지 않는다
	assert_float(_mean(on, "share")).is_less(0.6)
	assert_float(_mean(raw, "share")).is_less(0.8)  # 줄을 무시해도 포격만으로 죽지 않는다 (한 번 10)


func test_other_heroes_on_hansan_with_the_cannon_line() -> void:
	for hero_id in ["gwanggaeto", "sejong", "shin_saimdang"]:
		var a: Dictionary = await _run(hero_id, SEEDS[0], false)
		var b: Dictionary = await _run(hero_id, SEEDS[0], true)
		assert_bool(b["boss"]).override_failure_message(hero_id).is_true()
		assert_float(b["share"]).override_failure_message(hero_id).is_less(0.6)
		assert_float(b["time"]).override_failure_message(hero_id).is_less_equal(a["time"] * 1.15)
