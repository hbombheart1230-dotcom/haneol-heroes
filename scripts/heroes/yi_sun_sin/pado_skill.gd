class_name PadoSkill
extends SkillDef
## 이순신 · 파도격: 대시 방향 관통 연격 (경로 위 적을 hit_count번 타격).

@export var length: float = 320.0
@export var width: float = 90.0
@export var hit_count: int = 3
@export var damage_per_hit: int = 10
@export var hit_interval: float = 0.07
@export_group("큰 변형 · 물보라")
## 0보다 크면 마지막 타격 때 물길 끝에서 이 반경으로 터진다.
@export var end_burst_radius: float = 0.0
@export var end_burst_damage: int = 30


func cast(ctx: SkillContext, _charge: float) -> SkillRun:
	var dir := ctx.player.get_dash_direction()
	if dir.length_squared() < 0.0001:
		dir = ctx.player.facing
	var a := ctx.player.global_position - dir * 30.0
	var b := ctx.player.global_position + dir * length
	ctx.strip(a, b)  # 앞으로 밀려가는 물결 띠
	if ctx.fx and (vfx_impact == null or vfx_impact.strip == null):
		ctx.fx.add_slash(a, b, width * 0.5, 0.3, fx_color)
	var run := PadoRun.new(self, ctx, a, b)
	run.strike()
	return run


## 연타 진행 상태.
class PadoRun extends SkillRun:
	var skill: PadoSkill
	var ctx: SkillContext
	var a: Vector2
	var b: Vector2
	var left: int
	var timer: float = 0.0

	func _init(p_skill: PadoSkill, p_ctx: SkillContext, p_a: Vector2, p_b: Vector2) -> void:
		skill = p_skill
		ctx = p_ctx
		a = p_a
		b = p_b
		left = p_skill.hit_count

	func strike() -> void:
		var last := left <= 1  # 마지막 연타는 크게 한 번 멈춤
		var struck := false
		for en in ctx.enemies_near_segment(a, b, skill.width * 0.5):
			if ctx.hit(en, skill.damage_per_hit):
				struck = true
			hits += 1  # 타격마다 경로 위 대상 수 (리팩터링 전과 동일한 집계)
		if last and struck:
			SkillMultiHit.finale(ctx)
		left -= 1
		timer += skill.hit_interval
		if ctx.fx and left >= 0:
			var side := (b - a).orthogonal().normalized() * (12.0 * (left - 1))
			ctx.fx.add_slash(a + side, b + side, 10.0, 0.18, Color(0.7, 0.95, 1.0))
		if left <= 0:
			finished = true
			ctx.impact(b, b - a)  # 물보라
			if skill.end_burst_radius > 0.0:
				for en in ctx.enemies_in_radius(b, skill.end_burst_radius):
					ctx.hit(en, skill.end_burst_damage)
					hits += 1
				if ctx.fx:
					ctx.fx.add_ring(b, skill.end_burst_radius, 0.4, skill.fx_color)

	func tick(delta: float) -> bool:
		timer -= delta
		while not finished and timer <= 0.0:
			strike()
		return finished
