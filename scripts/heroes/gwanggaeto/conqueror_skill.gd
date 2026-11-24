class_name ConquerorSkill
extends SkillDef
## 광개토대왕 · 정복자의 일격(가칭): 회피 직후 뛰어올라 내리찍는다. 아주 넓은 범위 + 긴 기절.
## 내리찍기는 적마다 쿵-쿵-쾅 (beats번, BeatHits): 총 피해는 그대로 나눠 마지막 타가 크게, 날리기는 마지막 쾅에.

@export var radius: float = 280.0
@export var damage: int = 70
@export var stun_time: float = 1.2
@export var knockback: float = 380.0
## 0보다 크면 넉백 대신 이만큼(px) 바깥으로 크게 날린다 (큰 기술 = 크게 날림, EnemyLaunch).
@export var launch_px: float = 0.0
@export_group("박자 (BeatHits, 쿵-쿵-쾅)")
## 적마다 타수 (1이면 예전처럼 한 번에), 타 사이(초), 마지막 타 비중.
@export var beats: int = 3
@export var beat_interval: float = 0.13
@export var beat_last_weight: float = 2.0
@export var beat_sfx: StringName = &"thud"
@export_group("큰 변형 · 천둥 군림")
## 0보다 크면 내리찍은 자리에 이 시간(초) 천둥 지대가 남는다.
@export var field_time: float = 0.0
@export var field_damage: int = 10


func cast(ctx: SkillContext, _charge: float) -> SkillRun:
	var center := ctx.player.global_position
	var targets := BeatHits.alive(ctx.enemies_in_radius(center, radius))
	if beats <= 1:
		for en in targets:
			ComboSteps.push_out(en, center, launch_px, knockback)
			if ctx.hit(en, damage):
				en.stun(stun_time)
		_burst(ctx, center)
		ctx.shake(0.5)
	else:
		var rake := BeatHits.start(ctx, center, targets, damage, beats, beat_interval, beat_last_weight, true, beat_sfx,
			func(en: Enemy) -> void: ComboSteps.push_out(en, center, launch_px, knockback))
		for en in targets:  # 맡긴 뒤 묶는다 (기절이 공격을 끊어 처벌 배율이 사라지기 전에 판정을 잡는다)
			en.stun(stun_time)
		_quake(ctx, center, 0.6, 0.25)
		for b in range(1, beats):
			if b == beats - 1:
				rake.schedule_fx(beat_interval * b, func() -> void:
					_burst(ctx, center)
					ctx.shake(0.5))
			else:
				rake.schedule_fx(beat_interval * b, func() -> void: _quake(ctx, center, 0.8, 0.3))
	ctx.impact(center, Vector2.ZERO, radius)
	if field_time > 0.0:
		var z := DamageZone.new()
		z.ctx = ctx
		z.radius = radius * 0.8
		z.duration = field_time
		z.interval = 0.4
		z.damage = field_damage
		z.color = fx_color
		ctx.add_to_world(z, center)
	return SkillRun.instant(targets.size())  # 멈춤은 마지막 쾅 뒤 한 번 (SkillMultiHit.finale)


## 앞 쿵: 고리 하나 + 흔들림.
func _quake(ctx: SkillContext, center: Vector2, scale: float, shake: float) -> void:
	if ctx.fx:
		ctx.fx.add_ring(center, radius * scale, 0.35, fx_color)
	ctx.shake(shake)


## 마지막 쾅: 큰 고리 둘 + 사방 획.
func _burst(ctx: SkillContext, center: Vector2) -> void:
	if ctx.fx == null:
		return
	ctx.fx.add_ring(center, radius, 0.5, fx_color)
	ctx.fx.add_ring(center, radius * 0.7, 0.35, Color(1, 1, 1))
	for i in 6:
		var d := Vector2.from_angle(TAU * i / 6.0) * radius
		ctx.fx.add_slash(center, center + d, 8.0, 0.3, fx_color)
