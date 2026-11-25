class_name LightningSkill
extends SkillDef
## 광개토대왕 · 낙뢰(가칭): 충전할수록 많은 벼락이 주변 적에게 떨어진다 (가까운 적부터, 겹치지 않게).

@export var min_bolts: int = 1
@export var max_bolts: int = 6
@export var search_radius: float = 460.0
@export var damage: int = 40
## 벼락 하나의 피해 반경 (맞은 적 주변도 함께).
@export var splash_radius: float = 60.0
## 불똥 그림(vfx_impact) 끝 = 벼락이 닿는 끝: splash_radius + 적 몸 (예전엔 그림 크기 그대로라 판정의 1.4~1.6배).
@export var splash_edge_px: float = 20.0
@export_group("모으며 조준 (끌면)")
## 모으는 동안 끌면 그 방향 steer_reach px 자리를 가운데로 반경 steer_radius 안 적부터 벼락 (끌지 않으면 영웅 주변 자동).
@export var steer_reach: float = 240.0
@export var steer_radius: float = 220.0
## 조준 원에 더하는 적 몸(px): 벼락은 원 + 적 몸 안의 적에게 떨어진다 (SkillContext.enemies_in_radius).
@export var aim_edge_px: float = 20.0
@export_group("큰 변형 · 연쇄")
## 벼락마다 가까운 적에게 이만큼 더 튄다 (피해 chain_ratio배).
@export var chain_count: int = 0
@export var chain_ratio: float = 0.5
@export var chain_range: float = 180.0
@export_group("박자 (WaveRake, 해일검기와 같은 다단 타격)")
## 벼락이 차례로 떨어지는 간격(초), 사슬이 한 칸 건너뛰는 간격(초). 맞은 적은 crackle_hits번 지지직 (간격 crackle_interval),
## 피해는 그대로 나눠 마지막 타가 크게. crackle_hits 1이면 예전처럼 한 번에.
@export var bolt_beat: float = 0.07
@export var chain_beat: float = 0.09
@export var crackle_hits: int = 3
@export var crackle_interval: float = 0.045


## 모은 만큼 벼락 수 (charge_scaling이 있으면 그 마디대로 계단, 다 모으면 max_bolts).
func bolt_count(charge: float) -> int:
	if charge_scaling:
		return roundi(charge_scaling.between(min_bolts, max_bolts, charge))
	return roundi(lerpf(min_bolts, max_bolts, clampf(charge, 0.0, 1.0)))


func cast(ctx: SkillContext, charge: float) -> SkillRun:
	var center := ctx.player.global_position
	ChargeRelease.play(ctx, self, charge, center, ctx.player.facing)  # 모은 만큼 흔들림, 다 모았으면 번쩍임
	var r := search_radius
	if charge_aim and ctx.aim_steered:  # 끌어서 잡은 자리가 가운데
		center += aim(ctx) * steer_reach
		r = steer_radius
	# 죽어서 지워지기 전인 적은 빼고 고른다 (벼락이 헛되이 쓰이지 않게, Codex f7fa7cd).
	var targets: Array[Enemy] = []
	for en in ctx.enemies_in_radius(center, r):
		if en.health.is_alive():
			targets.append(en)
	targets.sort_custom(func(x: Enemy, y: Enemy) -> bool:
		return x.global_position.distance_squared_to(center) < y.global_position.distance_squared_to(center))
	var hits := 0
	var struck := {}
	var rake := WaveRake.standalone(ctx, center, crackle_interval)
	rake.sfx = &"mat_lightning"
	var t := 0.0
	for i in mini(bolt_count(charge), targets.size()):
		var tg := targets[i]
		hits += _bolt(ctx, rake, tg.global_position, damage, t)
		struck[tg.get_instance_id()] = true
		var from := tg.global_position
		var ct := t
		for c in chain_count:
			var next := _nearest_unstruck(ctx, from, struck)
			if next == null:
				break
			struck[next.get_instance_id()] = true
			ct += chain_beat
			var a := from
			var b := next.global_position
			rake.schedule(next, ct, _crackle(roundi(damage * chain_ratio)), _no_push(), (b - a).normalized(),
				func() -> void: ctx.bolt(a, b, 6.0, 0.2, fx_color))  # 사슬이 건너뛰는 박자
			hits += 1
			from = b
		t += bolt_beat
	if hits > 0:
		ctx.shake(0.3)
	return SkillRun.instant(hits)


## 벼락 하나 (delay초 뒤): 줄기·불똥은 떨어질 때, 반경 안 적은 지지직 여러 번. 반환: 맞을 적 수.
func _bolt(ctx: SkillContext, rake: WaveRake, at: Vector2, dmg: int, delay: float) -> int:
	var n := 0
	var draw := func() -> void:
		if vfx_impact == null and ctx.fx:
			ctx.fx.add_slash(at + Vector2(0, -420), at, 10.0, 0.22, fx_color)  # 하늘에서 내리꽂힘
		ctx.impact(at, Vector2.ZERO, splash_radius, splash_radius + splash_edge_px)  # 번개 줄기 + 불똥 (판정 끝에 맞춤)
		if ctx.fx and range_rings:
			ctx.fx.add_ring(at, splash_radius, 0.3, Color(1, 1, 1))
	for en in ctx.enemies_in_radius(at, splash_radius):
		rake.schedule(en, delay, _crackle(dmg), _no_push(), Vector2.DOWN, draw if n == 0 else Callable())
		n += 1
	if n == 0:  # 맞을 적이 없어도 벼락은 떨어진다
		rake.schedule_fx(delay, draw)
	return n


func _crackle(dmg: int) -> PackedInt32Array:
	return WaveRake.plan(dmg, maxi(crackle_hits, 1), 2.0, 0.0, 0.0)[0]


func _no_push() -> PackedFloat32Array:
	var p := PackedFloat32Array()
	p.resize(maxi(crackle_hits, 1))
	return p


func _nearest_unstruck(ctx: SkillContext, from: Vector2, struck: Dictionary) -> Enemy:
	var best: Enemy = null
	var best_d := chain_range
	for en in ctx.enemies_in_radius(from, chain_range):
		if struck.has(en.get_instance_id()) or not en.health.is_alive():
			continue
		var d := en.global_position.distance_to(from)
		if d <= best_d:
			best_d = d
			best = en
	return best


## 조준 표시: 끈 방향 steer_reach 자리에 반경 steer_radius 원 (벼락이 떨어질 곳).
func draw_aim(canvas: CanvasItem, c: float, dir: Vector2, d: ChargeMarkerData) -> bool:
	ChargeAim.draw_circle_aim(canvas, dir * steer_reach, steer_radius + aim_edge_px, c, d)
	return true
