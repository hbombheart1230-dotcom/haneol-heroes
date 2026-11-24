class_name SynergyState
extends RefCounted
## 이번 판에 켜진 짝 (SynergyDef). RunBuild가 패를 적용할 때마다 다시 센다. 판이 시작되면 비운다.

static var active: Array[SynergyDef] = []


static func reset() -> void:
	active.clear()


## pool의 짝 중 stacks(고른 패)로 맞은 것을 켠다. 새로 켜진 짝을 돌려준다.
static func refresh(pool: UpgradePool, stacks: Dictionary) -> Array[SynergyDef]:
	var fresh: Array[SynergyDef] = []
	if pool == null:
		return fresh
	for s in pool.synergies:
		if s and not active.has(s) and s.met(stacks):
			active.append(s)
			fresh.append(s)
	return fresh


static func is_active(id: StringName) -> bool:
	for s in active:
		if s.id == id:
			return true
	return false


static func adjust(ctx: SkillContext, en: Enemy, dmg: int) -> int:
	for s in active:
		dmg = s.effect.adjust(ctx, en, dmg)
	return dmg


static func on_projectile_hit(ctx: SkillContext, p: Projectile, en: Enemy) -> void:
	for s in active:
		s.effect.on_projectile_hit(ctx, p, en)
