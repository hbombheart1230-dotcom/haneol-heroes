class_name SundialSkill
extends SkillDef
## 세종 · 해시계 멈춤(가칭, 앙부일구): 회피 직후 주변 적의 시간을 크게 느리게 하고 피해.
## 느려짐·멈춤은 누르는 순간 모두에게 (지키는 힘 그대로). 해시계 판이 조각으로 펼쳐지는 동안 그림자 바늘이
## 한 바퀴 돌며 눈금마다 번쩍이고, 바늘이 지나는 적부터 차례로 피해 (SweepRun).

@export var radius: float = 300.0
## 그림(vfx_impact) 끝 = 닿는 끝: 반경 + 적 몸 (왜군 병사 몸 20px, SkillContext.edge_of) — 해룡참·반격과 같음.
@export var ring_edge_px: float = 20.0
@export var damage: int = 30
@export var slow_factor: float = 0.3
@export var slow_time: float = 2.0
@export_group("큰 변형 · 멈춘 시간")
## 0보다 크면 느려진 적이 이 초 동안 완전히 멈춘다 (기절).
@export var freeze_time: float = 0.0


func cast(ctx: SkillContext, _charge: float) -> SkillRun:
	var center := SkillAim.point(ctx, true) if SkillAim.enabled(ctx) else ctx.player.global_position  # 세종: 공격한 적 자리에
	var targets: Array[Enemy] = []
	for en in ctx.enemies_in_radius(center, radius):
		if not en.health.is_alive():
			continue
		en.slow(slow_factor, slow_time)
		if freeze_time > 0.0:
			en.stun(freeze_time)
		targets.append(en)
	ctx.impact(center, Vector2.ZERO, radius, radius + ring_edge_px)
	if ctx.fx and range_rings:
		ctx.fx.add_ring(center, radius, 0.6, fx_color)
	# 명중 멈춤은 SkillHitStop 공통 규칙 (피해 비례, D3)
	return ctx.sweep(center, targets, func(en: Enemy) -> bool: return ctx.hit(en, damage))
