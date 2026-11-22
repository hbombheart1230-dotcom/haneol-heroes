class_name ConstellationSkill
extends SkillDef
## 세종 · 성좌진(가칭): 충전할수록 많은 별(3~7)로 앞쪽에 별자리를 그리고, 별을 잇는 선에 닿은 적에게 피해.

@export var min_stars: int = 3
@export var max_stars: int = 7
@export var reach: float = 420.0
@export var spread_degrees: float = 70.0
@export var line_width: float = 50.0
@export var damage: int = 30
## 별 하나가 박히는 간격(초, 연출: 별이 차례로 이어진다).
@export var star_step: float = 0.06
@export_group("큰 변형 · 북두칠성")
## 0보다 크면 별마다 이 반경으로 터진다.
@export var star_burst_radius: float = 0.0


func star_count(charge: float) -> int:
	return roundi(lerpf(min_stars, max_stars, clampf(charge, 0.0, 1.0)))


## 별 위치: 플레이어 앞 부채꼴에 지그재그로 (같은 충전이면 같은 모양).
func star_points(origin: Vector2, facing: Vector2, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var t := float(i + 1) / float(n)
		var side := (1.0 if i % 2 == 0 else -1.0) * deg_to_rad(spread_degrees) * 0.5 * (0.4 + 0.6 * t)
		pts.append(origin + facing.rotated(side) * reach * (0.25 + 0.75 * t))
	return pts


func cast(ctx: SkillContext, charge: float) -> SkillRun:
	var run := StarChainRun.new(self, ctx, star_points(ctx.player.global_position, aim(ctx), star_count(charge)))
	run.tick(0.0)  # 첫 별은 누르는 순간
	return run


## 별 하나를 찍고 앞 별과 잇는다: 그 선에 닿은 적 (별마다 처음 맞는 적만) + 별 터짐. 맞은 수.
func link(ctx: SkillContext, prev: Vector2, p: Vector2, struck: Dictionary) -> int:
	var hits := 0
	for en in ctx.enemies_near_segment(prev, p, line_width * 0.5):
		if not struck.has(en.get_instance_id()) and ctx.hit(en, damage):
			struck[en.get_instance_id()] = true
			hits += 1
	if star_burst_radius > 0.0:
		for en in ctx.enemies_in_radius(p, star_burst_radius):
			if ctx.hit(en, roundi(damage * 0.5)):
				hits += 1
	ctx.impact(p, p - prev)
	if ctx.fx:
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

	func _init(p_skill: ConstellationSkill, p_ctx: SkillContext, p_pts: PackedVector2Array) -> void:
		skill = p_skill
		ctx = p_ctx
		pts = p_pts
		prev = p_ctx.player.global_position

	func tick(delta: float) -> bool:
		wait -= delta
		while not finished and wait <= 0.0:
			if next >= pts.size():
				finished = true
				break
			hits += skill.link(ctx, prev, pts[next], struck)
			prev = pts[next]
			next += 1
			wait += skill.star_step
		return finished
