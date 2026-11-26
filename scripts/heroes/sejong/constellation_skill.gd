class_name ConstellationSkill
extends SkillDef
## 세종 · 성좌진(가칭): 충전할수록 많은 별(3~7)로 앞쪽에 별자리를 그리고, 별을 잇는 선에 닿은 적에게 피해.

@export var min_stars: int = 3
@export var max_stars: int = 7
@export var reach: float = 420.0
@export var spread_degrees: float = 70.0
@export var line_width: float = 50.0
@export var damage: int = 30
## 별 사이 맞는 띠 그림: 선 판정 폭 그대로 (line_width + 적 몸 둘) 옅게 깔고, 그 위에 가는 별빛 선.
## 예전엔 가는 선(약 14px)만 그려 맞는 폭(약 78px)이 안 보였다. band_alpha 0이면 띠 없음.
@export var line_edge_px: float = 20.0
@export var band_alpha: float = 0.35
## 별 하나가 박히는 간격(초, 연출: 별이 차례로 이어진다).
@export var star_step: float = 0.06
@export_group("박자 (BeatHits, 별빛)")
## 선에 닿은 적마다 타수 (1이면 예전처럼 한 번에): 선이 긋고 별빛이 한 번 더 반짝이며 친다. 타 사이(초), 마지막 타 비중.
@export var twinkle_hits: int = 2
@export var twinkle_interval: float = 0.08
@export var twinkle_last_weight: float = 1.0
@export var twinkle_sfx: StringName = &"mat_glyph"
@export_group("큰 변형 · 북두칠성")
## 0보다 크면 별마다 이 반경으로 터진다.
@export var star_burst_radius: float = 0.0
## 별 터짐 그림 (별마다 star_burst_radius + 적 몸에 맞춤; 비면 그림 없음). 강화 패 점검 #229 "북두칠성 터짐 그림 없음".
@export var star_burst_vfx: SkillVfxData
@export var star_burst_edge_px: float = 20.0


## 모은 만큼 별 수 (charge_scaling이 있으면 그 마디대로 계단, 다 모으면 max_stars).
func star_count(charge: float) -> int:
	if charge_scaling:
		return roundi(charge_scaling.between(min_stars, max_stars, charge))
	return roundi(lerpf(min_stars, max_stars, clampf(charge, 0.0, 1.0)))


## 별 위치: 플레이어 앞 부채꼴에 지그재그로 (같은 충전이면 같은 모양).
## 별 위치: 플레이어 앞 부채꼴에 지그재그로 (같은 충전이면 같은 모양). far > 0이면 마지막 별까지의 거리 (기본 reach).
func star_points(origin: Vector2, facing: Vector2, n: int, far: float = -1.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var r := far if far > 0.0 else reach
	for i in n:
		var t := float(i + 1) / float(n)
		var side := (1.0 if i % 2 == 0 else -1.0) * deg_to_rad(spread_degrees) * 0.5 * (0.4 + 0.6 * t)
		if far > 0.0 and i == n - 1:
			side = 0.0  # 마지막 별은 겨눈 자리에 정확히
		pts.append(origin + facing.rotated(side) * r * (0.25 + 0.75 * t))
	return pts


func cast(ctx: SkillContext, charge: float) -> SkillRun:
	var from := ctx.player.global_position
	var dir := aim(ctx)
	ChargeRelease.play(ctx, self, charge, from, dir)  # 모은 만큼 흔들림, 다 모았으면 번쩍임
	var far := -1.0
	if SkillAim.enabled(ctx) and not (charge_aim and ctx.aim_steered):  # 세종 (끌지 않았을 때): 별자리가 겨눈 적까지 뻗어 마지막 별이 그 적에게 박힌다
		var to := SkillAim.point(ctx) - from
		if to.length() > 1.0:
			dir = to.normalized()
			far = maxf(to.length(), reach * 0.45)
	var run := StarChainRun.new(self, ctx, star_points(from, dir, star_count(charge), far))
	run.tick(0.0)  # 첫 별은 누르는 순간
	return run


## 별 하나를 찍고 앞 별과 잇는다: 그 선에 닿은 적 (별마다 처음 맞는 적만) + 별 터짐. 맞은 수.
## rake가 있으면 선에 닿은 적은 twinkle_hits타로 (피해 나눔, 멈춤은 별자리가 다 끝난 뒤 한 번).
func link(ctx: SkillContext, prev: Vector2, p: Vector2, struck: Dictionary, rake: WaveRake = null) -> int:
	var hits := 0
	var pl := WaveRake.plan(damage, twinkle_hits, twinkle_last_weight, 0.0, 0.0) if rake else []
	for en in ctx.enemies_near_segment(prev, p, line_width * 0.5):
		if struck.has(en.get_instance_id()) or not en.health.is_alive():
			continue
		if rake:
			struck[en.get_instance_id()] = true
			rake.schedule(en, 0.0, pl[0], pl[1], (p - prev).normalized())
			hits += 1
		elif ctx.hit(en, damage):
			struck[en.get_instance_id()] = true
			hits += 1
	if star_burst_radius > 0.0:
		for en in ctx.enemies_in_radius(p, star_burst_radius):
			if ctx.hit(en, roundi(damage * 0.5)):
				hits += 1
		if star_burst_vfx:  # 별마다 터짐 (반경 + 몸에 맞춤)
			Feedback.vfx_burst(star_burst_vfx, p, p - prev, vfx_level, star_burst_radius + star_burst_edge_px, star_burst_radius)
	ctx.impact(p, p - prev)
	if ctx.fx:
		if band_alpha > 0.0:  # FxLayer 붓 획은 넣은 폭의 2.4배로 그려진다 (fx_layer.gd "slash")
			ctx.fx.add_slash(prev, p, (line_width + line_edge_px * 2.0) / 2.4, 0.5, Color(fx_color, band_alpha))
		ctx.fx.add_slash(prev, p, 6.0, 0.5, fx_color)
		ctx.fx.add_ring(p, 18.0, 0.5, Color(1, 1, 1))
	return hits


## 별자리를 한 별씩 star_step초 간격으로 이어 그린다 (한꺼번에 뜨지 않고 별이 차례로 박힌다).
## 대상·피해는 그대로, 맞는 순간만 별 순서대로 나뉜다.
class StarChainRun extends SkillRun:
	var skill: ConstellationSkill
	var ctx: SkillContext
	var pts: PackedVector2Array
	var prev: Vector2
	var next: int = 0
	var wait: float = 0.0
	var struck := {}
	var rake: WaveRake = null

	func _init(p_skill: ConstellationSkill, p_ctx: SkillContext, p_pts: PackedVector2Array) -> void:
		skill = p_skill
		ctx = p_ctx
		pts = p_pts
		prev = p_ctx.player.global_position
		if p_skill.twinkle_hits > 1:
			rake = BeatHits.open(p_ctx, prev, p_skill.twinkle_interval, false, p_skill.twinkle_sfx)
			rake.schedule_fx(p_skill.star_step * p_pts.size() + 0.02, Callable())  # 별이 다 박힐 때까지 열어 둔다

	func tick(delta: float) -> bool:
		wait -= delta
		while not finished and wait <= 0.0:
			if next >= pts.size():
				finished = true
				break
			hits += skill.link(ctx, prev, pts[next], struck, rake)
			prev = pts[next]
			next += 1
			wait += skill.star_step
		return finished


## 조준 표시: 끈 방향으로 지금 충전의 별자리 (영웅 → 별들, 선 폭 = 맞는 폭).
func draw_aim(canvas: CanvasItem, c: float, dir: Vector2, d: ChargeMarkerData) -> bool:
	var pts := PackedVector2Array([Vector2.ZERO])
	pts.append_array(star_points(Vector2.ZERO, dir, star_count(c)))
	ChargeAim.draw_polyline_aim(canvas, pts, line_width, c, d)
	return true
