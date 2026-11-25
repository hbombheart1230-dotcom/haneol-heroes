class_name QuakeSkill
extends SkillDef
## 광개토대왕 · 뇌진격(가칭): 대검으로 땅을 내리찍어 주변에 충격파 + 기절.
## 충격파는 적마다 쿵-쾅 (beats번, BeatHits): 적은 타수에 무게, 총 피해는 그대로 나눠 마지막 타가 크게, 밀기·날리기는 마지막 타에.

@export var radius: float = 180.0
@export var damage: int = 30
@export var stun_time: float = 0.5
@export var knockback: float = 160.0
## 0보다 크면 넉백 대신 이만큼(px) 바깥으로 크게 날린다 (큰 기술 = 크게 날림, EnemyLaunch).
@export var launch_px: float = 0.0
## 고리 그림(vfx_impact) 끝 = 닿는 끝: 반경 + 적 몸 (왜군 병사 몸 20px, SkillContext.edge_of) — 해룡참·반격과 같음.
@export var ring_edge_px: float = 20.0
@export_group("박자 (BeatHits, 쿵-쾅)")
## 적마다 타수 (1이면 예전처럼 한 번에), 타 사이(초), 마지막 타 비중.
@export var beats: int = 2
@export var beat_interval: float = 0.12
@export var beat_last_weight: float = 2.0
@export var beat_sfx: StringName = &"thud"
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


## 충격파 한 번 (적마다 beats타). 맞을 적 수.
func strike(ctx: SkillContext, center: Vector2, dmg: int) -> int:
	var targets := BeatHits.alive(ctx.enemies_in_radius(center, radius))
	if beats <= 1:
		for en in targets:
			ComboSteps.push_out(en, center, launch_px, knockback)
			if ctx.hit(en, dmg):
				en.stun(stun_time)
	else:
		var rake := BeatHits.start(ctx, center, targets, dmg, beats, beat_interval, beat_last_weight, true, beat_sfx,
			func(en: Enemy) -> void: ComboSteps.push_out(en, center, launch_px, knockback))
		for en in targets:  # 맡긴 뒤 묶는다 (기절이 공격을 끊어 처벌 배율이 사라지기 전에 판정을 잡는다)
			en.stun(stun_time)
		for b in range(1, beats):
			var last := b == beats - 1
			rake.schedule_fx(beat_interval * b, func() -> void: _ring(ctx, center, 1.15 if last else 0.8, 0.35 if last else 0.2))
	ctx.impact(center, Vector2.ZERO, radius, radius + ring_edge_px)
	_ring(ctx, center, 1.0, 0.35 if beats <= 1 else 0.22)
	return targets.size()


## 충격파 고리 + 흔들림 (박자마다, 마지막이 크다).
func _ring(ctx: SkillContext, center: Vector2, scale: float, shake: float) -> void:
	if ctx.fx and range_rings:
		ctx.fx.add_ring(center, radius * scale, 0.4, fx_color)
		ctx.fx.add_ring(center, radius * 0.5 * scale, 0.25, Color(1, 1, 1))
	ctx.shake(shake)


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
