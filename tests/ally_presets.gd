class_name AllyPresets
extends RefCounted
## 같이 싸우기 느낌 안 (사용자에게 보여 고르기, tools/shots/home_summon_gif.gd·tests/test_ally_summon_sim.gd가 HH_ALLY_PRESET으로 쓴다).
## A 우두머리 집중 7초·먹 번짐 (보관분 그대로), B 곁 지키기 10초·내달려 물러감, C 짧고 굵게 4초 (올 때·갈 때 기술).
## 고르면 그 값을 data/summon/home_summon.tres에 옮긴다. 피해 배율(skill_scale)은 균형 측정으로 맞춘다.


static func apply(d: HomeSummonData, id: String) -> void:
	match id:
		"A":
			d.ally_time = 7.0
			d.ally_focus = &"boss"
			d.ally_exit = &"ink"
			d.ally_skill_times = PackedFloat32Array([0.0, 3.5])
		"B":
			d.ally_time = 10.0
			d.ally_focus = &"guard"
			d.ally_exit = &"dash"
			d.ally_skill_times = PackedFloat32Array([0.0])
		"C":
			d.ally_time = 4.0
			d.ally_focus = &"boss"
			d.ally_exit = &"ink"
			d.ally_skill_times = PackedFloat32Array([0.0, 3.6])
	var k := OS.get_environment("HH_ALLY_SKILL_SCALE")
	if k != "":
		d.ally_skill_scale = float(k)
	var hs := OS.get_environment("HH_ALLY_HIT_SCALE")
	if hs != "":
		d.ally_hit_scale = float(hs)
	var t := OS.get_environment("HH_ALLY_TIME")
	if t != "":
		d.ally_time = float(t)


static func describe(d: HomeSummonData) -> String:
	return "%.1fs %s %s skills %s x%.2f hits x%.2f" % [d.ally_time, d.ally_focus, d.ally_exit, d.ally_skill_times, d.ally_skill_scale,
		d.ally_hit_scale]
