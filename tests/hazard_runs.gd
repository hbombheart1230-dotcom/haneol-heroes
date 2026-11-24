class_name HazardRuns
extends RefCounted
## 무대 장치 시뮬 도우미 (tests/test_*_sim.gd): StageSim 한 판을 장치 켜고/끄고, 영웅을 바꿔 (원정) 돌린다.
## tweak(st)로 장치 수치를 판마다 바꿔 비교할 수 있다 (무대는 판마다 새로 읽어 다른 판에 남지 않는다).

const HINTS := {"yi_sun_sin": "순신", "gwanggaeto": "광개토", "sejong": "세종", "shin_saimdang": "사임당"}


static func run(suite: Node, stage_id: String, hero_id: String, s: int, hz: bool, dodge: bool = true,
		tweak: Callable = Callable(), tag: String = "") -> Dictionary:
	var st := ResourceLoader.load("res://data/stages/%s.tres" % stage_id, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageTheme
	st.hero_hint = HINTS[hero_id]
	var copies: Array[StageHazardData] = []
	for h in st.hazards:
		copies.append(h.duplicate() as StageHazardData)
	st.hazards = copies
	if tweak.is_valid():
		tweak.call(st)
	var sim := StageSim.new(suite)
	sim.contact = false
	sim.use_hazards = hz
	sim.dodge_hazards = dodge
	await sim.setup_stage(st, s)
	var r := sim.run_waves()
	sim.free_all()
	var hp := float((load("res://data/heroes/%s.tres" % hero_id) as HeroData).max_hp)
	r["share"] = r["damage"] / hp
	var extra := PackedStringArray()
	for k in r:
		if String(k).begins_with("cover_") or String(k).begins_with("fire_") or String(k).begins_with("grass_"):
			extra.append("%s %s" % [k, str(r[k])])
	print("[hazard-sim] %s %s seed %d %s%s: %s at %.1fs, damage %d (%.2f of hp) %s" % [stage_id, hero_id, s,
		"hazard" if hz else "no hazard", (" " + tag) if tag != "" else "",
		"BOSS" if r["boss"] else ("LOSE" if r["lost"] else "TIMEOUT"), r["time"], r["damage"], r["share"], ", ".join(extra)])
	return r


static func mean(rs: Array, key: String) -> float:
	var t := 0.0
	for r: Dictionary in rs:
		t += float(r.get(key, 0.0))
	return t / maxf(rs.size(), 1)
