class_name CounterSlashSkill
extends SkillDef
## 이순신 · 강화 반격: 회피 성공 직후 주변을 크게 베는 물결 참격.
## 넓은 범위, 큰 피해, 강한 넉백, 짧은 히트스톱.

@export var radius: float = 230.0
@export var damage: int = 60
@export var knockback: float = 520.0
## 0보다 크면 넉백 대신 이만큼(px) 바깥으로 크게 날린다 (큰 기술 = 크게 날림, EnemyLaunch).
@export var launch_px: float = 0.0
## 고리 그림(vfx_impact)·X자 칼자국의 끝 = 칼이 닿는 끝: 반경 + 적 몸 (왜군 병사 몸 20px, SkillContext.edge_of) — 해룡참과 같음.
@export var ring_edge_px: float = 20.0
## 히트스톱 길이(실시간 초).
@export_group("큰 변형 · 사방 검기")
## 반격과 함께 사방으로 날리는 관통 검기 수 (0이면 없음).
@export var radial_blades: int = 0
@export var blade_damage: int = 25
## 검기 긁기 (WaveRake, 해일검기와 같은 방식): 검기가 닿은 적을 blade_rake_interval초마다 blade_rake_hits번 잘게,
## 총 피해 blade_damage·총 밀기 blade_push는 나눠 마지막 타가 크게. 1이면 예전처럼 한 번에.
@export var blade_rake_hits: int = 3
@export var blade_rake_interval: float = 0.05
@export var blade_push: float = 90.0


func cast(ctx: SkillContext, _charge: float) -> SkillRun:
	var center := ctx.player.global_position
	var hits := 0
	for en in ctx.enemies_in_radius(center, radius):
		ComboSteps.push_out(en, center, launch_px, knockback)
		ctx.hit(en, damage)
		hits += 1
	ctx.impact(center, Vector2.ZERO, radius, radius + ring_edge_px)
	if ctx.fx and range_rings:
		ctx.fx.add_ring(center, radius, 0.45, fx_color)
		ctx.fx.add_ring(center, radius * 0.6, 0.3, Color(1, 1, 1))
	if ctx.fx:
		for i in 4:  # X자 칼자국: 끝이 칼끝 (예전 반경 × 0.9 → 칼끝의 0.83배)
			var d := Vector2.from_angle(TAU * i / 4.0 + PI / 4.0) * (radius + ring_edge_px)
			ctx.fx.add_slash(center - d, center + d, 16.0, 0.25, fx_color)
	for i in radial_blades:
		var dir := Vector2.from_angle(TAU * i / float(radial_blades))
		var p := ctx.spawn_projectile_configured(func(pr: Projectile) -> void:
			pr.direction = dir
			pr.speed = 760.0
			pr.lifetime = 0.6
			pr.pierce = true
			pr.damage = blade_damage
			pr.knockback = blade_push
			pr.size_scale = 1.3)
		if p and blade_rake_hits > 1:  # 사방 검기도 지나가며 잘게 긁는다 (다다닥)
			var rake := WaveRake.attach(ctx, p, WaveRake.plan(blade_damage, blade_rake_hits, 2.0, blade_push, 0.35),
				blade_rake_interval, 24)
			rake.finale = false  # 멈춤은 반격 자신의 한 번만 (검기가 사라질 때 또 멈추지 않는다)
	return SkillRun.instant(hits)  # 명중 멈춤은 SkillHitStop 공통 규칙 (피해 비례, D3)
