extends GdUnitTestSuite
## 순신 연타 (사용자: "순신 연타 시 전진이 더 필요하고 검기도 키워야 됨, 광개토·사임당이 더 좋다"): 세 근접 영웅 비교표를 남기고,
## 순신 사거리·전진을 올린 값이 연타를 끊지 않는지 (맞고 밀린 적이 다음 타 사거리 안) 본다. 연타 간격은 그대로.

const HEROES := ["yi_sun_sin", "gwanggaeto", "shin_saimdang"]
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
## 적 넉백 감쇠 (Enemy.knockback_damping): 넉백 속도 v로 밀리는 거리 ≈ v ÷ 감쇠.
const DAMPING := 8.0


func _row(id: String) -> Dictionary:
	var h: HeroData = load("res://data/heroes/%s.tres" % id)
	var d := h.attack
	var sheet := h.sprite_sheet
	var out := {"id": id, "range": [], "step_in": [], "lunge": [], "push": [], "contact": [], "stop": [], "gap": []}
	for s in [1, 2, 3]:
		var heavy: bool = s == d.chain_len
		out["range"].append(roundi(d.melee_range * ComboSteps.at(d.step_range_mults, s, 1.0)))
		out["step_in"].append(roundi(minf(ComboSteps.at(d.step_in_px, s, 0.0), d.step_in_max)))
		out["lunge"].append(roundi(ComboSteps.at(d.lunge_px, s, 0.0)))
		var kb := d.melee_knockback * (d.heavy_knockback_mult if heavy else 1.0) * ComboSteps.at(d.step_knockback_mults, s, 1.0)
		var push := d.heavy_launch_px if heavy and d.heavy_launch_px > 0.0 else kb * SOLDIER.knockback_scale / DAMPING
		out["push"].append(roundi(push))
		var anim := "attack" if s == 1 else "attack%d" % s
		var ct := -1.0
		if h.blade_bite and h.blade_bite.clip_contact.has(StringName(anim)):
			ct = h.blade_bite.clip_contact[StringName(anim)]
		elif sheet and sheet.has_anim(anim):
			ct = sheet.strike_frame(anim) / sheet.fps[sheet.anim_names.find(anim)]
		out["contact"].append(snappedf(ct, 0.001))
		out["stop"].append(h.blade_bite.stop_for(s) if h.blade_bite else Feedback.feel_data().impact_data().hero_hitstop(1, heavy))
		out["gap"].append(snappedf(d.melee_interval * ComboSteps.at(d.step_gap_mults, s % d.chain_len + 1, 1.0), 0.01))
	return out


func test_print_hero_table() -> void:
	for id in HEROES:
		print("[melee-table] ", _row(id))


## 순신 사거리는 두 영웅 쪽으로 (120 → 155) 그대로. 전진·내딛기는 붙기를 뺄 때 (사용자 2026-11-24) 광개토 수준으로 (더 크지 않게).
func test_yi_reach_and_step_in_raised() -> void:
	var yi := _row("yi_sun_sin")
	var gw := _row("gwanggaeto")
	assert_int(yi["range"][0]).is_greater_equal(150)
	for i in 3:
		assert_int(yi["step_in"][i]).is_less_equal(gw["step_in"][i])
		assert_int(yi["lunge"][i]).is_less_equal(gw["lunge"][i])


## 연타가 이어진다: n타 사거리 끝에서 맞은 적이 밀린 뒤 (n+1)타 전진을 빼면 (n+1)타 사거리 안 (3타 뒤는 마무리가 받는다).
func test_yi_chain_stays_in_range() -> void:
	var yi := _row("yi_sun_sin")
	for s in [0, 1]:
		var after: int = int(yi["range"][s]) + int(yi["push"][s]) - int(yi["step_in"][s + 1])
		assert_int(after).is_less_equal(yi["range"][s + 1])
