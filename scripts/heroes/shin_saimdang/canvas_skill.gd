class_name CanvasSkill
extends SkillDef
## 사임당 · 화폭 펼치기(가칭): 충전한 만큼 큰 화폭을 펼쳐 안의 적을 그림 속에 가두고(기절), 잠시 뒤 피해.

@export var min_radius: float = 160.0
@export var max_radius: float = 320.0
@export var min_hold: float = 1.0
@export var max_hold: float = 2.5
@export var damage: int = 35
@export var delay: float = 0.6
@export_group("조이는 박자 (WaveRake, 해일검기와 같은 다단 타격)")
## 가둔 적을 squeeze_start초부터 squeeze_hits번 조인다: 간격이 타마다 squeeze_accel배로 짧아져 마지막 타가 delay초에 크게.
## 피해는 그대로 나눔. squeeze_hits 1이면 예전처럼 delay초에 한 번.
@export var squeeze_hits: int = 5
@export var squeeze_start: float = 0.12
@export var squeeze_accel: float = 0.75
@export_group("모으며 조준 (끌면)")
## 모으는 동안 끌면 화폭 가운데를 그 방향으로 이만큼(px) 옮긴다 (끌지 않으면 영웅 자리).
@export var steer_offset: float = 200.0
## 조준 원에 더하는 적 몸(px): 화폭은 반경 + 적 몸 안의 적을 가둔다 (SkillContext.enemies_in_radius).
@export var aim_edge_px: float = 20.0
@export_group("큰 변형 · 병풍")
## 피해 배율 (큰 변형으로 커진다).
@export var damage_mult: float = 1.0


## 모은 만큼 화폭 반경·가두는 시간 (charge_scaling이 있으면 그 마디대로 계단, 다 모으면 max).
func radius_for(charge: float) -> float:
	return _between(min_radius, max_radius, charge)


func hold_for(charge: float) -> float:
	return _between(min_hold, max_hold, charge)


func _between(lo: float, hi: float, charge: float) -> float:
	return charge_scaling.between(lo, hi, charge) if charge_scaling else lerpf(lo, hi, clampf(charge, 0.0, 1.0))


func cast(ctx: SkillContext, charge: float) -> SkillRun:
	var c := clampf(charge, 0.0, 1.0)
	var center := ctx.player.global_position
	if charge_aim and ctx.aim_steered:  # 끌어서 잡은 자리가 가운데
		center += aim(ctx) * steer_offset
	var r := radius_for(c)
	ChargeRelease.play(ctx, self, c, center, ctx.player.facing)  # 모은 만큼 흔들림, 다 모았으면 번쩍임
	ctx.foretell(center)  # 펼쳐질 화폭으로 먹 기운이 모인다
	var trapped: Array[Enemy] = []
	for en in ctx.enemies_in_radius(center, r):
		if en.health.is_alive():
			en.stun(hold_for(c))
			trapped.append(en)
	ctx.impact(center, Vector2.ZERO, r)  # 두루마리가 가두는 동안 가운데부터 양옆으로 펼쳐진다 (판정 크기)
	if ctx.fx and range_rings:
		ctx.fx.add_ring(center, r, delay + 0.3, fx_color)
		ctx.fx.add_ring(center, r * 0.97, delay + 0.3, Color(Ink.INK, 0.6))
	var squeezed := squeeze_hits > 1 and not trapped.is_empty()
	if squeezed:
		_squeeze(ctx, trapped, center)
	var run := TrapRun.new(self, ctx, trapped, center, r)
	run.squeezed = squeezed
	return run


## 첫 간격: squeeze_start부터 delay까지 n-1칸이 squeeze_accel배씩 줄어들게.
func squeeze_gap() -> float:
	var n := maxi(squeeze_hits, 2)
	var a := clampf(squeeze_accel, 0.1, 1.0)
	var span := maxf(delay - squeeze_start, 0.05)
	return span / float(n - 1) if is_equal_approx(a, 1.0) else span * (1.0 - a) / (1.0 - pow(a, n - 1))


func _squeeze(ctx: SkillContext, trapped: Array[Enemy], center: Vector2) -> void:
	var rake := WaveRake.standalone(ctx, center, squeeze_gap())
	rake.accel = squeeze_accel
	rake.sfx = &"mat_ink"
	var dmg := roundi(damage * damage_mult)
	for en in trapped:
		var pl := WaveRake.plan(dmg, squeeze_hits, 2.5, 0.0, 0.0)
		rake.schedule(en, squeeze_start, pl[0], pl[1], (center - en.global_position).normalized())


class TrapRun extends SkillRun:
	var skill: CanvasSkill
	var ctx: SkillContext
	var trapped: Array[Enemy]
	var center: Vector2
	var r: float
	var left: float
	## 조이는 타가 피해를 넣었다 (끝에는 연출만).
	var squeezed: bool = false

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
				if squeezed:
					hits += 1
				elif is_instance_valid(en) and ctx.hit(en, roundi(skill.damage * skill.damage_mult)):
					hits += 1
			Feedback.impact_haptic()  # 그림은 펼칠 때 이미 나왔다 (다시 펼치지 않음)
			if ctx.fx and skill.range_rings:
				ctx.fx.add_ring(center, r, 0.3, Color(1, 1, 1))
			ctx.shake(0.25)
			finished = true
		return finished


## 조준 표시: 끈 방향 steer_offset 자리에 지금 충전의 화폭 반경 원.
func draw_aim(canvas: CanvasItem, c: float, dir: Vector2, d: ChargeMarkerData) -> bool:
	ChargeAim.draw_circle_aim(canvas, dir * steer_offset, radius_for(c) + aim_edge_px, c, d)
	return true
