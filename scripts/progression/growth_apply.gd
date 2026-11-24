class_name GrowthApply
extends RefCounted
## 판 시작에 영웅 성장(HeroGrowth)을 이번 판 영웅 사본(RunBuild)에 건다: 최대 체력, 모든 피해 배율
## (적이 받는 피해 한 곳: Enemy._update_damage_mult), 기술 시작 단계(vfx_level), 기술 맨 위 단계 열기.
## 판마다 항상 다시 정한다 (점수 0이면 배율 1, 맨 위 단계 닫힘). 시뮬은 부르지 않으므로 성장 0 기준 그대로.

const SLOTS: Array[StringName] = [&"tap", &"dash", &"charge", &"counter"]


static func apply(build: RunBuild, n: int, g: HeroGrowth = null) -> void:
	if g == null:
		g = HeroGrowth.load_default()
	HeroGrowth.run_damage_mult = g.damage_mult(n)
	SkillGrowthData.top_open = g.top_stage_open(n)
	if build == null or build.hero == null:
		return
	var h := build.hero
	var old := h.max_hp
	h.max_hp = maxi(roundi(h.max_hp * g.hp_mult(n)), 1)
	if build.player and h.max_hp != old:
		build.player.refresh_stats(old)
	var start := g.skill_start(n)
	var stages := SkillGrowthData.get_default().stage_from
	var add := stages[mini(start, stages.size() - 1)] if start > 0 and not stages.is_empty() else 0
	if add > 0 and h.kit:
		for slot in SLOTS:
			var sk := h.kit.get(slot) as SkillDef
			if sk:
				sk.vfx_level += add


## 판 밖 성장을 모두 끈다 (시험·시뮬 준비).
static func reset() -> void:
	HeroGrowth.run_damage_mult = 1.0
	SkillGrowthData.top_open = false
