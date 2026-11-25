class_name SummonOverride
extends RefCounted
## 시뮬 비교용: 환경 변수 HH_SUMMON_EVERY·HH_SUMMON_FIRST가 있으면 우두머리·중간 우두머리의 주기 소환 값을 덮어쓴 사본.


static func apply(d: EnemyData) -> EnemyData:
	if d == null or d.boss_feel == null or OS.get_environment("HH_SUMMON_EVERY") == "":
		return d
	var c := d.duplicate() as EnemyData
	c.boss_feel = d.boss_feel.duplicate() as BossFeelData
	c.boss_feel.summon_every = float(OS.get_environment("HH_SUMMON_EVERY"))
	if OS.get_environment("HH_SUMMON_FIRST") != "":
		c.boss_feel.summon_first = float(OS.get_environment("HH_SUMMON_FIRST"))
	return c
