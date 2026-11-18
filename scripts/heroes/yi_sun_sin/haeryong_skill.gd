class_name HaeryongSkill
extends SkillDef
## 이순신 · 해룡참: 주변 광역 베기 + 넉백 (푸른 물결 고리).

@export var radius: float = 170.0
@export var damage: int = 25
@export var knockback: float = 420.0


func cast(ctx: SkillContext, _charge: float) -> SkillRun:
	var center := ctx.player.global_position
	var hits := 0
	for en in ctx.enemies_in_radius(center, radius):
		var off := en.global_position - center
		var dir := off.normalized() if off.length_squared() > 0.01 else Vector2.RIGHT
		en.apply_knockback(dir * knockback)
		ctx.hit(en, damage)
		hits += 1  # 범위 안 대상 수 (리팩터링 전과 동일한 집계)
	if ctx.fx:
		ctx.fx.add_ring(center, radius, 0.35, fx_color)
	return SkillRun.instant(hits)
