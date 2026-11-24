class_name WaveBreath
extends RefCounted
## 중간 우두머리 물결을 깬 뒤 숨 고르기 회복 (WaveSetData.elite_clear_heal, 기본 꺼짐).


## 회복한 양 (꺼져 있거나 정예 물결이 아니면 0).
static func on_cleared(runner: WaveRunner, health: Health) -> int:
	if runner == null or health == null or health.is_dead() or runner.data.elite_clear_heal <= 0.0 or not runner.is_elite_wave():
		return 0
	var before := health.current
	health.heal(roundi(health.max * runner.data.elite_clear_heal))
	return health.current - before
