class_name LightningSkill
extends SkillDef
## 광개토대왕 · 낙뢰(가칭): 충전할수록 많은 벼락이 주변 적에게 떨어진다 (가까운 적부터, 겹치지 않게).

@export var min_bolts: int = 1
@export var max_bolts: int = 6
@export var search_radius: float = 460.0
@export var damage: int = 40
## 벼락 하나의 피해 반경 (맞은 적 주변도 함께).
@export var splash_radius: float = 60.0
@export_group("큰 변형 · 연쇄")
## 벼락마다 가까운 적에게 이만큼 더 튄다 (피해 chain_ratio배).
@export var chain_count: int = 0
@export var chain_ratio: float = 0.5
@export var chain_range: float = 180.0


func bolt_count(charge: float) -> int:
	return roundi(lerpf(min_bolts, max_bolts, clampf(charge, 0.0, 1.0)))


func cast(ctx: SkillContext, charge: float) -> SkillRun:
	var center := ctx.player.global_position
	var targets := ctx.enemies_in_radius(center, search_radius)
	targets.sort_custom(func(x: Enemy, y: Enemy) -> bool:
		return x.global_position.distance_squared_to(center) < y.global_position.distance_squared_to(center))
	var hits := 0
	var struck := {}
	for i in mini(bolt_count(charge), targets.size()):
		var t := targets[i]
		hits += _bolt(ctx, t.global_position, damage)
		struck[t.get_instance_id()] = true
		var from := t.global_position
		for c in chain_count:
			var next := _nearest_unstruck(ctx, from, struck)
			if next == null:
				break
			struck[next.get_instance_id()] = true
			if ctx.fx:
				ctx.fx.add_slash(from, next.global_position, 6.0, 0.2, fx_color)
			if ctx.hit(next, roundi(damage * chain_ratio)):
				hits += 1
			from = next.global_position
	if hits > 0:
		ctx.shake(0.3)
	return SkillRun.instant(hits)


func _bolt(ctx: SkillContext, at: Vector2, dmg: int) -> int:
	var n := 0
	for en in ctx.enemies_in_radius(at, splash_radius):
		if ctx.hit(en, dmg):
			n += 1
	if ctx.fx:
		ctx.fx.add_slash(at + Vector2(0, -420), at, 10.0, 0.22, fx_color)  # 하늘에서 내리꽂힘
		ctx.fx.add_ring(at, splash_radius, 0.3, Color(1, 1, 1))
	return n


func _nearest_unstruck(ctx: SkillContext, from: Vector2, struck: Dictionary) -> Enemy:
	var best: Enemy = null
	var best_d := chain_range
	for en in ctx.enemies_in_radius(from, chain_range):
		if struck.has(en.get_instance_id()) or not en.health.is_alive():
			continue
		var d := en.global_position.distance_to(from)
		if d <= best_d:
			best_d = d
			best = en
	return best
