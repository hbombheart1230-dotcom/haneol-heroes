class_name InkBleedSkill
extends SkillDef
## 사임당 · 발묵(가칭): 방금 대시한 길에 먹이 번져 적을 느리게 하고 계속 피해.

@export var duration: float = 3.0
@export var width: float = 120.0
@export var damage: int = 5
@export var interval: float = 0.4
@export var slow_factor: float = 0.5
@export var min_length: float = 200.0
@export_group("큰 변형 · 먹구름")
## 0보다 크면 번진 먹이 끝날 때 한 번 터진다 (피해).
@export var burst_damage: int = 0


func cast(ctx: SkillContext, _charge: float) -> SkillRun:
	var b := ctx.player.global_position
	var a := ctx.player.dash_start_position()
	if a.distance_to(b) < min_length:
		a = b - ctx.player.facing * min_length
	var steps := maxi(roundi(a.distance_to(b) / width), 1)
	for i in steps + 1:  # 길을 따라 먹 웅덩이 여러 개
		var z := DamageZone.new()
		z.ctx = ctx
		z.radius = width * 0.6
		z.duration = duration
		z.interval = interval
		z.damage = damage
		z.slow_factor = slow_factor
		z.color = fx_color
		ctx.add_to_world(z, a.lerp(b, float(i) / steps))
	if burst_damage > 0:
		return BurstRun.new(self, ctx, a, b)
	return SkillRun.instant(0)


class BurstRun extends SkillRun:
	var skill: InkBleedSkill
	var ctx: SkillContext
	var a: Vector2
	var b: Vector2
	var left: float

	func _init(p_skill: InkBleedSkill, p_ctx: SkillContext, p_a: Vector2, p_b: Vector2) -> void:
		skill = p_skill
		ctx = p_ctx
		a = p_a
		b = p_b
		left = p_skill.duration

	func tick(delta: float) -> bool:
		left -= delta
		if left <= 0.0 and not finished:
			for en in ctx.enemies_near_segment(a, b, skill.width * 0.6):
				if ctx.hit(en, skill.burst_damage):
					hits += 1
			ctx.impact(b, b - a)
			if ctx.fx:
				ctx.fx.add_slash(a, b, skill.width * 0.5, 0.35, skill.fx_color)
			finished = true
		return finished
