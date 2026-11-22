class_name ConquerorSkill
extends SkillDef
## 광개토대왕 · 정복자의 일격(가칭): 회피 직후 뛰어올라 내리찍는다. 아주 넓은 범위 + 긴 기절.

@export var radius: float = 280.0
@export var damage: int = 70
@export var stun_time: float = 1.2
@export var knockback: float = 380.0
@export_group("큰 변형 · 천둥 군림")
## 0보다 크면 내리찍은 자리에 이 시간(초) 천둥 지대가 남는다.
@export var field_time: float = 0.0
@export var field_damage: int = 10


func cast(ctx: SkillContext, _charge: float) -> SkillRun:
	var center := ctx.player.global_position
	var hits := 0
	for en in ctx.enemies_in_radius(center, radius):
		if not en.health.is_alive():
			continue  # 죽어서 지워지기 전인 적은 밀지도 세지도 않는다
		var off := en.global_position - center
		en.apply_knockback((off.normalized() if off.length_squared() > 0.01 else Vector2.RIGHT) * knockback)
		if ctx.hit(en, damage):
			en.stun(stun_time)
		hits += 1
	ctx.impact(center, Vector2.ZERO, radius)
	if ctx.fx:
		ctx.fx.add_ring(center, radius, 0.5, fx_color)
		ctx.fx.add_ring(center, radius * 0.7, 0.35, Color(1, 1, 1))
		for i in 6:
			var d := Vector2.from_angle(TAU * i / 6.0) * radius
			ctx.fx.add_slash(center, center + d, 8.0, 0.3, fx_color)
	if field_time > 0.0:
		var z := DamageZone.new()
		z.ctx = ctx
		z.radius = radius * 0.8
		z.duration = field_time
		z.interval = 0.4
		z.damage = field_damage
		z.color = fx_color
		ctx.add_to_world(z, center)
	ctx.shake(0.5)
	return SkillRun.instant(hits)  # 명중 멈춤은 SkillHitStop 공통 규칙 (피해 비례, D3)
