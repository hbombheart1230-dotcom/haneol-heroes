class_name PlumBlossomSkill
extends SkillDef
## 사임당 · 매화 만개(가칭): 회피 직후 매화 꽃잎이 사방으로 터지며 피해, 체력을 조금 회복.
## 꽃잎은 흩날리듯 가볍게 여러 번 (beats번, BeatHits): 바깥 적일수록 조금 늦게 닿고, 총 피해는 그대로 나눔.

@export var radius: float = 260.0
@export var damage: int = 45
@export var heal: int = 10
## 매화 고리 그림(vfx_impact) 끝 = 닿는 끝: 반경 + 적 몸 (왜군 병사 몸 20px, SkillContext.edge_of) — 해룡참·반격과 같음.
@export var ring_edge_px: float = 20.0
@export_group("박자 (BeatHits, 꽃잎)")
## 적마다 타수 (1이면 예전처럼 한 번에), 타 사이(초), 마지막 타 비중, 가장자리 적까지 꽃잎이 닿는 시간(초).
@export var beats: int = 5
@export var beat_interval: float = 0.05
@export var beat_last_weight: float = 1.5
@export var petal_travel: float = 0.12
@export var beat_sfx: StringName = &"mat_brush"
@export_group("큰 변형 · 꽃비")
## 0보다 크면 이 시간(초) 동안 꽃잎이 남아 계속 피해.
@export var petal_time: float = 0.0


func cast(ctx: SkillContext, _charge: float) -> SkillRun:
	var center := ctx.player.global_position
	var hits := 0
	if beats <= 1:
		for en in ctx.enemies_in_radius(center, radius):
			if ctx.hit(en, damage):
				hits += 1
	else:
		var targets := BeatHits.alive(ctx.enemies_in_radius(center, radius))
		var r := maxf(radius, 1.0)
		var travel := petal_travel
		BeatHits.start(ctx, center, targets, damage, beats, beat_interval, beat_last_weight, false, beat_sfx,
			Callable(), func(en: Enemy) -> float: return travel * clampf(en.global_position.distance_to(center) / r, 0.0, 1.0))
		hits = targets.size()
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
	ctx.impact(center, Vector2.ZERO, radius, radius + ring_edge_px)
	if ctx.fx and range_rings:
		ctx.fx.add_ring(center, radius, 0.5, fx_color)
		for i in 10:
			var d := Vector2.from_angle(TAU * i / 10.0)
			ctx.fx.add_slash(center + d * 30.0, center + d * radius, 10.0, 0.35, fx_color)
	return SkillRun.instant(hits)  # 멈춤은 꽃잎이 다 닿은 뒤 한 번 (SkillMultiHit.finale)
