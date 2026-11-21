class_name PlumBlossomSkill
extends SkillDef
## 사임당 · 매화 만개(가칭): 회피 직후 매화 꽃잎이 사방으로 터지며 피해, 체력을 조금 회복.

@export var radius: float = 260.0
@export var damage: int = 45
@export var heal: int = 10
@export_group("큰 변형 · 꽃비")
## 0보다 크면 이 시간(초) 동안 꽃잎이 남아 계속 피해.
@export var petal_time: float = 0.0


func cast(ctx: SkillContext, _charge: float) -> SkillRun:
	var center := ctx.player.global_position
	var hits := 0
	for en in ctx.enemies_in_radius(center, radius):
		if ctx.hit(en, damage):
			hits += 1
	var h := ctx.player.health
	if h and h.is_alive() and heal > 0:
		h.current = mini(h.current + heal, h.max)
	if petal_time > 0.0:
		var z := DamageZone.new()
		z.ctx = ctx
		z.radius = radius * 0.8
		z.duration = petal_time
		z.interval = 0.4
		z.damage = 6
		z.color = fx_color
		ctx.add_to_world(z, center)
	ctx.impact(center)
	if ctx.fx:
		ctx.fx.add_ring(center, radius, 0.5, fx_color)
		for i in 10:
			var d := Vector2.from_angle(TAU * i / 10.0)
			ctx.fx.add_slash(center + d * 30.0, center + d * radius, 10.0, 0.35, fx_color)
	return SkillRun.instant(hits)  # 명중 멈춤은 SkillHitStop 공통 규칙 (피해 비례, D3)
