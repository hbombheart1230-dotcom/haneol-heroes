class_name HomeSummonCast
extends RefCounted
## 주인 영웅 기술 한 번 (HomeSummonButton이 부른다): 원정 온 영웅 자리에서, 가장 가까운 우두머리(없으면 적)를 향해
## 주인 영웅의 기술을 다 모은 세기로 쓴다. 영웅 쿨타임·연타·시전 동작은 건드리지 않는다 (SkillCaster.cast를 거치지 않음).
## 컷인은 주인 영웅 카드로 (누가 왔는지), 기술 소리 층도 함께.


## 쓴 진행 상태 (끝나지 않았으면 부른 쪽이 tick). 쓸 수 없으면 null.
static func cast(caster: SkillCaster, home: HeroData, d: SkillDef, charge: float, damage_scale: float) -> SkillRun:
	if caster == null or caster.player == null or caster.player.is_dead() or d == null:
		return null
	var sd := TapCombo.scaled_def(d, damage_scale)
	var ctx := caster._context()
	ctx.skill = sd
	var dir := aim_dir(ctx)
	if dir != Vector2.ZERO:
		ctx.aim_dir = dir
		ctx.aim_steered = true
		caster.player.facing = dir  # 영웅 앞쪽으로 펼치는 기술(낙뢰·화폭)도 적 쪽으로
	if sd.vfx_cast:
		Feedback.vfx_burst(sd.vfx_cast, sd.cast_point(ctx), caster.player.facing, sd.vfx_level)
	var tree := caster.get_tree() if caster.is_inside_tree() else null
	SkillCutin.play(tree, sd, home, true)
	SkillStageFx.play_all(sd.sfx_layers)
	return sd.cast(ctx, charge)


## 겨눌 쪽: 가장 가까운 우두머리, 없으면 가장 가까운 적. 적이 없으면 ZERO (영웅이 보던 쪽).
static func aim_dir(ctx: SkillContext) -> Vector2:
	var from := ctx.player.global_position
	var best: Enemy = null
	var best_d := INF
	var best_boss := false
	for e in ctx.enemies():
		if not is_instance_valid(e):
			continue
		var en := e as Enemy
		if en == null or en.health == null or en.health.is_dead():
			continue
		var boss := en.data != null and en.data.is_boss
		var dist := from.distance_to(en.global_position)
		if (boss and not best_boss) or (boss == best_boss and dist < best_d):
			best = en
			best_d = dist
			best_boss = boss
	if best == null or best_d < 1.0:
		return Vector2.ZERO
	return (best.global_position - from).normalized()
