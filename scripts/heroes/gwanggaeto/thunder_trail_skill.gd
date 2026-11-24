class_name ThunderTrailSkill
extends SkillDef
## 광개토대왕 · 벽력돌파(가칭): 방금 돌격한 경로를 한 박자 뒤 천둥이 따라 내리친다.
## 천둥은 우르릉-쾅 (beats번, BeatHits): 가는 번개가 먼저 긁고 굵은 벼락이 크게. 총 피해는 그대로 나눔.

@export var delay: float = 0.3
@export var width: float = 110.0
@export var damage: int = 35
## 대시 경로가 이보다 짧으면 바라보는 방향으로 이 길이를 쓴다.
@export var min_length: float = 200.0
@export_group("박자 (BeatHits, 우르릉-쾅)")
## 적마다 타수 (1이면 예전처럼 한 번에), 타 사이(초), 마지막 타 비중.
@export var beats: int = 2
@export var beat_interval: float = 0.12
@export var beat_last_weight: float = 2.0
@export var beat_sfx: StringName = &"mat_lightning"
@export_group("큰 변형 · 감전 지대")
## 0보다 크면 내리친 경로 가운데에 이 시간(초) 감전 지대가 남는다.
@export var field_time: float = 0.0
@export var field_damage: int = 6


func cast(ctx: SkillContext, _charge: float) -> SkillRun:
	var b := ctx.player.global_position
	var a := ctx.player.dash_start_position()
	if a.distance_to(b) < min_length:
		a = b - ctx.player.facing * min_length
	ctx.foretell((a + b) * 0.5)  # 예고: 길 가운데로 번개 기운이 모인다
	if ctx.fx:
		ctx.fx.add_slash(a, b, width * 0.15, delay, Color(fx_color, 0.5))  # 예고: 옅은 번개 길
	return TrailRun.new(self, ctx, a, b)


## 굵은 벼락 (마지막 쾅, 또는 한 번에 칠 때).
func thunder(ctx: SkillContext, a: Vector2, b: Vector2) -> void:
	ctx.strip(a, b)  # 길을 따라 번개 줄기
	ctx.bolt(a, b, width * 0.5, 0.3, fx_color)
	ctx.impact(b, b - a)
	ctx.shake(0.25)


class TrailRun extends SkillRun:
	var skill: ThunderTrailSkill
	var ctx: SkillContext
	var a: Vector2
	var b: Vector2
	var left: float

	func _init(p_skill: ThunderTrailSkill, p_ctx: SkillContext, p_a: Vector2, p_b: Vector2) -> void:
		skill = p_skill
		ctx = p_ctx
		a = p_a
		b = p_b
		left = p_skill.delay

	func tick(delta: float) -> bool:
		left -= delta
		if left > 0.0 or finished:
			return finished
		var targets := BeatHits.alive(ctx.enemies_near_segment(a, b, skill.width * 0.5))
		if skill.beats <= 1:
			for en in targets:
				if ctx.hit(en, skill.damage):  # 실제로 맞은 적만 센다 (죽어서 지워지기 전인 적 제외)
					hits += 1
			skill.thunder(ctx, a, b)
		else:
			var rake := BeatHits.start(ctx, (a + b) * 0.5, targets, skill.damage, skill.beats, skill.beat_interval,
				skill.beat_last_weight, true, skill.beat_sfx)
			hits = targets.size()
			ctx.bolt(a, b, skill.width * 0.25, 0.18, Color(skill.fx_color, 0.8))  # 우르릉: 가는 번개
			ctx.shake(0.12)
			var s := skill
			var c := ctx
			var pa := a
			var pb := b
			rake.schedule_fx(skill.beat_interval * (skill.beats - 1), func() -> void: s.thunder(c, pa, pb))  # 쾅
		if skill.field_time > 0.0:
			var z := DamageZone.new()
			z.ctx = ctx
			z.radius = maxf(a.distance_to(b) * 0.5, skill.width)
			z.duration = skill.field_time
			z.interval = 0.35
			z.damage = skill.field_damage
			z.color = skill.fx_color
			ctx.add_to_world(z, (a + b) * 0.5)
		finished = true
		return finished
