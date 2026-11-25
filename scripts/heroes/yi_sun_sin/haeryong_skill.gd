class_name HaeryongSkill
extends SkillDef
## 이순신 · 해룡참: 주변 광역 베기 + 넉백 (푸른 물결 고리).
## 해룡 그림이 바라보는 방향부터 한 바퀴 휘감기며 펼쳐지고, 그 붓이 지나는 순서대로 적이 베인다 (SweepRun).

@export var radius: float = 170.0
@export var damage: int = 25
@export var knockback: float = 420.0
## 0보다 크면 넉백 대신 이만큼(px) 바깥으로 크게 날린다 (큰 기술 = 크게 날림, EnemyLaunch).
@export var launch_px: float = 0.0
## 물결 고리 그림(vfx_impact)의 바깥 끝 = 칼이 닿는 끝: 반경 + 적 몸 (왜군 병사 몸 20px, SkillContext.edge_of).
## 예전엔 반경에만 맞춰 몸이 고리 밖에 있어도 베였다 (사용자 07f0d8f "원 둘레 크기를 칼질에 맞게").
@export var ring_edge_px: float = 20.0
@export_group("큰 변형 · 소용돌이")
## 0보다 크면 베기 뒤 그 자리에 소용돌이가 이 시간(초) 남는다 (정예 보상으로 켜진다).
@export var whirl_time: float = 0.0
@export var whirl_damage: int = 7
@export var whirl_interval: float = 0.3
@export var whirl_pull: float = 90.0


func cast(ctx: SkillContext, _charge: float) -> SkillRun:
	var center := ctx.player.global_position
	var targets := ctx.enemies_in_radius(center, radius)  # 대상은 누르는 순간 정해진다
	ctx.impact(center, Vector2.ZERO, radius, radius + ring_edge_px)
	if ctx.fx and range_rings:
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
	return ctx.sweep(center, targets, func(en: Enemy) -> bool:
		ComboSteps.push_out(en, center, launch_px, knockback)  # 휘감는 순서대로 한 마리씩 날아간다
		return ctx.hit(en, damage))
