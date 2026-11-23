class_name SkillAim
extends RefCounted
## 원거리 영웅(세종)의 기술 좌표: 영웅 자리가 아니라 겨눈 적 자리에 떨어진다 (SkillKit.skills_at_target).
## 겨눌 적 = 찾는 거리(target_search) 안 가장 가까운 산 적. 반격은 막 공격한 적(공격 중·회복 중)을 먼저.
## 사거리 상한(target_range)보다 멀면 그 거리에서 자르고, 적이 없으면 바라보는 방향으로 기본 거리(target_default).


static func kit_of(ctx: SkillContext) -> SkillKit:
	return ctx.player.hero.kit if ctx and ctx.player and ctx.player.hero else null


## 이 영웅의 기술이 적 기준 좌표를 쓰는지 (다른 영웅은 예전처럼 영웅 자리).
static func enabled(ctx: SkillContext) -> bool:
	var k := kit_of(ctx)
	return k != null and k.skills_at_target


## 겨눌 적 (없으면 null). prefer_attacker: 지금 공격 중인 적을 먼저 (반격 = 공격한 적).
static func target(ctx: SkillContext, prefer_attacker: bool = false) -> Enemy:
	var k := kit_of(ctx)
	var from := ctx.player.global_position
	var search := k.target_search if k else 760.0
	var best: Enemy = null
	var best_d2 := search * search
	var busy: Enemy = null
	var busy_d2 := search * search
	for n in ctx.enemies():
		var en := n as Enemy
		if en == null or not is_instance_valid(en) or en.is_queued_for_deletion():
			continue
		if en.health and not en.health.is_alive():
			continue
		var d2 := from.distance_squared_to(en.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = en
		if prefer_attacker and en.attack and en.attack.is_busy() and d2 < busy_d2:
			busy_d2 = d2
			busy = en
	return busy if busy else best


## 떨어질 자리: 겨눈 적 자리 (사거리 상한에서 자름), 적이 없으면 바라보는 방향 기본 거리.
static func point(ctx: SkillContext, prefer_attacker: bool = false) -> Vector2:
	return point_for(ctx, target(ctx, prefer_attacker))


static func point_for(ctx: SkillContext, en: Enemy) -> Vector2:
	var k := kit_of(ctx)
	var from := ctx.player.global_position
	if en:
		return from + (en.global_position - from).limit_length(k.target_range if k else 520.0)
	var f := ctx.player.facing if ctx.player.facing.length_squared() > 0.0001 else Vector2.UP
	return from + f.normalized() * (k.target_default if k else 240.0)
