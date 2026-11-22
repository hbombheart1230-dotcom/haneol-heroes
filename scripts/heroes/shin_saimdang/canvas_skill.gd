class_name CanvasSkill
extends SkillDef
## 사임당 · 화폭 펼치기(가칭): 충전한 만큼 큰 화폭을 펼쳐 안의 적을 그림 속에 가두고(기절), 잠시 뒤 피해.

@export var min_radius: float = 160.0
@export var max_radius: float = 320.0
@export var min_hold: float = 1.0
@export var max_hold: float = 2.5
@export var damage: int = 35
@export var delay: float = 0.6
@export_group("큰 변형 · 병풍")
## 피해 배율 (큰 변형으로 커진다).
@export var damage_mult: float = 1.0


func radius_for(charge: float) -> float:
	return lerpf(min_radius, max_radius, clampf(charge, 0.0, 1.0))


func cast(ctx: SkillContext, charge: float) -> SkillRun:
	var c := clampf(charge, 0.0, 1.0)
	var center := ctx.player.global_position
	var r := radius_for(c)
	ctx.foretell(center)  # 펼쳐질 화폭으로 먹 기운이 모인다
	var trapped: Array[Enemy] = []
	for en in ctx.enemies_in_radius(center, r):
		if en.health.is_alive():
			en.stun(lerpf(min_hold, max_hold, c))
			trapped.append(en)
	ctx.impact(center, Vector2.ZERO, r)  # 두루마리가 가두는 동안 가운데부터 양옆으로 펼쳐진다 (판정 크기)
	if ctx.fx:
		ctx.fx.add_ring(center, r, delay + 0.3, fx_color)
		ctx.fx.add_ring(center, r * 0.97, delay + 0.3, Color(Ink.INK, 0.6))
	return TrapRun.new(self, ctx, trapped, center, r)


class TrapRun extends SkillRun:
	var skill: CanvasSkill
	var ctx: SkillContext
	var trapped: Array[Enemy]
	var center: Vector2
	var r: float
	var left: float

	func _init(p_skill: CanvasSkill, p_ctx: SkillContext, p_trapped: Array[Enemy], p_center: Vector2, p_r: float) -> void:
		skill = p_skill
		ctx = p_ctx
		trapped = p_trapped
		center = p_center
		r = p_r
		left = p_skill.delay

	func tick(delta: float) -> bool:
		left -= delta
		if left <= 0.0 and not finished:
			for en in trapped:
				if is_instance_valid(en) and ctx.hit(en, roundi(skill.damage * skill.damage_mult)):
					hits += 1
			Feedback.impact_haptic()  # 그림은 펼칠 때 이미 나왔다 (다시 펼치지 않음)
			if ctx.fx:
				ctx.fx.add_ring(center, r, 0.3, Color(1, 1, 1))
			ctx.shake(0.25)
			finished = true
		return finished
