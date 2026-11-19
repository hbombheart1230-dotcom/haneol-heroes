class_name HaeryongSkill
extends SkillDef
## 이순신 · 해룡참: 주변 광역 베기 + 넉백 (푸른 물결 고리).

@export var radius: float = 170.0
@export var damage: int = 25
@export var knockback: float = 420.0
@export_group("큰 변형 · 소용돌이")
## 0보다 크면 베기 뒤 그 자리에 소용돌이가 이 시간(초) 남는다 (정예 보상으로 켜진다).
@export var whirl_time: float = 0.0
@export var whirl_damage: int = 7
@export var whirl_interval: float = 0.3
@export var whirl_pull: float = 90.0


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
	if whirl_time > 0.0:
		var z := DamageZone.new()
		z.ctx = ctx
		z.radius = radius * 0.8
		z.duration = whirl_time
		z.interval = whirl_interval
		z.damage = whirl_damage
		z.pull = whirl_pull
		z.color = fx_color
		ctx.add_to_world(z, center)
	return SkillRun.instant(hits)
