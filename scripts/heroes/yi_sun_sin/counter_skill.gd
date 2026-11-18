class_name CounterSlashSkill
extends SkillDef
## 이순신 · 강화 반격: 회피 성공 직후 주변을 크게 베는 물결 참격.
## 넓은 범위, 큰 피해, 강한 넉백, 짧은 히트스톱.

@export var radius: float = 230.0
@export var damage: int = 60
@export var knockback: float = 520.0
## 히트스톱 길이(실시간 초).
@export var hit_stop: float = 0.08


func cast(ctx: SkillContext, _charge: float) -> SkillRun:
	var center := ctx.player.global_position
	var hits := 0
	for en in ctx.enemies_in_radius(center, radius):
		var off := en.global_position - center
		var dir := off.normalized() if off.length_squared() > 0.01 else Vector2.RIGHT
		en.apply_knockback(dir * knockback)
		ctx.hit(en, damage)
		hits += 1
	if ctx.fx:
		ctx.fx.add_ring(center, radius, 0.45, fx_color)
		ctx.fx.add_ring(center, radius * 0.6, 0.3, Color(1, 1, 1))
		for i in 4:
			var d := Vector2.from_angle(TAU * i / 4.0 + PI / 4.0) * radius * 0.9
			ctx.fx.add_slash(center - d, center + d, 16.0, 0.25, fx_color)
	if hits > 0:
		ctx.hit_stop(hit_stop)
	return SkillRun.instant(hits)
