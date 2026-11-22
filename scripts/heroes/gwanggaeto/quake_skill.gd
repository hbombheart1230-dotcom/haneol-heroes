class_name QuakeSkill
extends SkillDef
## 광개토대왕 · 뇌진격(가칭): 대검으로 땅을 내리찍어 주변에 충격파 + 기절.

@export var radius: float = 180.0
@export var damage: int = 30
@export var stun_time: float = 0.5
@export var knockback: float = 160.0
## 0보다 크면 넉백 대신 이만큼(px) 바깥으로 크게 날린다 (큰 기술 = 크게 날림, EnemyLaunch).
@export var launch_px: float = 0.0
@export_group("큰 변형 · 여진")
## 0보다 크면 이 시간(초) 뒤 같은 자리에 한 번 더 충격파 (피해 aftershock_ratio배).
@export var aftershock_delay: float = 0.0
@export var aftershock_ratio: float = 0.7


func cast(ctx: SkillContext, _charge: float) -> SkillRun:
	var center := ctx.player.global_position
	var hits := strike(ctx, center, damage)
	if aftershock_delay > 0.0:
		var run := AftershockRun.new(self, ctx, center)
		run.hits = hits
		return run
	return SkillRun.instant(hits)


## 충격파 한 번. 맞은 적 수.
func strike(ctx: SkillContext, center: Vector2, dmg: int) -> int:
	var hits := 0
	for en in ctx.enemies_in_radius(center, radius):
		if not en.health.is_alive():
			continue  # 죽어서 지워지기 전인 적은 밀지도 세지도 않는다
		ComboSteps.push_out(en, center, launch_px, knockback)
		if ctx.hit(en, dmg):
			en.stun(stun_time)
		hits += 1
	ctx.impact(center, Vector2.ZERO, radius)
	if ctx.fx:
		ctx.fx.add_ring(center, radius, 0.4, fx_color)
		ctx.fx.add_ring(center, radius * 0.5, 0.25, Color(1, 1, 1))
	ctx.shake(0.35)
	return hits


class AftershockRun extends SkillRun:
	var skill: QuakeSkill
	var ctx: SkillContext
	var center: Vector2
	var left: float

	func _init(p_skill: QuakeSkill, p_ctx: SkillContext, p_center: Vector2) -> void:
		skill = p_skill
		ctx = p_ctx
		center = p_center
		left = p_skill.aftershock_delay

	func tick(delta: float) -> bool:
		left -= delta
		if left <= 0.0 and not finished:
			hits += skill.strike(ctx, center, roundi(skill.damage * skill.aftershock_ratio))
			finished = true
		return finished
