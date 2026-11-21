class_name MeteorSkill
extends SkillDef
## 세종 · 유성(가칭): 대시가 끝난 자리에 별이 떨어져 범위 피해 + 짧은 기절.

@export var delay: float = 0.25
@export var radius: float = 130.0
@export var damage: int = 40
@export var stun_time: float = 0.3
## 떨어지는 유성 그림, 크기(px), 떨어지기 시작하는 자리(목표 기준), 그림이 원래 날아가는 방향(도).
@export var fall_art: Texture2D
@export var fall_size: float = 220.0
@export var fall_from: Vector2 = Vector2(320, -620)
@export var fall_angle_deg: float = 135.0
@export_group("큰 변형 · 유성우")
## 첫 별 뒤에 주변으로 더 떨어지는 작은 별 수.
@export var extra_stars: int = 0


func cast(ctx: SkillContext, _charge: float) -> SkillRun:
	var at := ctx.player.global_position
	if ctx.fx:
		ctx.fx.add_ring(at, radius, delay, Color(fx_color, 0.4))  # 떨어질 자리 예고
		ctx.fx.add_fall(fall_art, at + fall_from, at, delay, fall_size, fall_angle_deg)  # 하늘에서 내려오는 유성
	return StarRun.new(self, ctx, at)


## 별 하나: 맞은 적 수.
func strike(ctx: SkillContext, at: Vector2, dmg: int, r: float) -> int:
	var n := 0
	for en in ctx.enemies_in_radius(at, r):
		if ctx.hit(en, dmg):
			en.stun(stun_time)
			n += 1
	ctx.impact(at)
	if ctx.fx:
		if fall_art == null:
			ctx.fx.add_slash(at + Vector2(-120, -420), at, 12.0, 0.25, fx_color)
		ctx.fx.add_ring(at, r, 0.35, Color(1, 1, 1))
	ctx.shake(0.2)
	return n


class StarRun extends SkillRun:
	var skill: MeteorSkill
	var ctx: SkillContext
	var at: Vector2
	var left: float
	var extra: int

	func _init(p_skill: MeteorSkill, p_ctx: SkillContext, p_at: Vector2) -> void:
		skill = p_skill
		ctx = p_ctx
		at = p_at
		left = p_skill.delay
		extra = p_skill.extra_stars

	func tick(delta: float) -> bool:
		left -= delta
		if left > 0.0 or finished:
			return finished
		hits += skill.strike(ctx, at, skill.damage, skill.radius)
		for i in extra:
			var off := Vector2.from_angle(TAU * i / maxf(extra, 1)) * skill.radius * 1.3
			hits += skill.strike(ctx, at + off, roundi(skill.damage * 0.5), skill.radius * 0.6)
		finished = true
		return finished
