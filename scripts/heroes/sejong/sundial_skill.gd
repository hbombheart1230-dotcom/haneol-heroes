class_name SundialSkill
extends SkillDef
## 세종 · 해시계 멈춤(가칭, 앙부일구): 회피 직후 주변 적의 시간을 크게 느리게 하고 피해.

@export var radius: float = 300.0
@export var damage: int = 30
@export var slow_factor: float = 0.3
@export var slow_time: float = 2.0
@export var hit_stop: float = 0.06
@export_group("큰 변형 · 멈춘 시간")
## 0보다 크면 느려진 적이 이 초 동안 완전히 멈춘다 (기절).
@export var freeze_time: float = 0.0


func cast(ctx: SkillContext, _charge: float) -> SkillRun:
	var center := ctx.player.global_position
	var hits := 0
	for en in ctx.enemies_in_radius(center, radius):
		if not en.health.is_alive():
			continue
		en.slow(slow_factor, slow_time)
		if freeze_time > 0.0:
			en.stun(freeze_time)
		if ctx.hit(en, damage):
			hits += 1
	if ctx.fx:
		ctx.fx.add_ring(center, radius, 0.6, fx_color)
		for i in 12:  # 해시계 눈금
			var d := Vector2.from_angle(TAU * i / 12.0)
			ctx.fx.add_slash(center + d * radius * 0.8, center + d * radius, 4.0, 0.6, fx_color)
	if hits > 0:
		ctx.hit_stop(hit_stop)
	return SkillRun.instant(hits)
