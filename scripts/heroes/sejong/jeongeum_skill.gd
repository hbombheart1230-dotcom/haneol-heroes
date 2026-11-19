class_name JeongeumSkill
extends SkillDef
## 세종 · 정음진(가칭): 몸 주위에 자모 글자 고리가 돌며 닿는 적에게 계속 피해.

@export var glyphs: String = "ㄱㄴㄷㅁㅅㅇ"
@export var radius: float = 110.0
@export var duration: float = 4.0
@export var damage: int = 10
@export var hit_interval: float = 0.5
@export_group("큰 변형 · 두 겹 고리")
## 0보다 크면 이 반경으로 바깥 고리가 하나 더 (반대로 돈다).
@export var outer_radius: float = 0.0


func cast(ctx: SkillContext, _charge: float) -> SkillRun:
	_ring(ctx, radius, 3.2)
	if outer_radius > 0.0:
		_ring(ctx, outer_radius, -2.4)
	if ctx.fx:
		ctx.fx.add_ring(ctx.player.global_position, radius, 0.3, fx_color)
	return SkillRun.instant(0)


func _ring(ctx: SkillContext, r: float, spin: float) -> OrbitGlyphs:
	var o := OrbitGlyphs.new()
	o.ctx = ctx
	o.follow = ctx.player
	o.glyphs = glyphs
	o.radius = r
	o.duration = duration
	o.damage = damage
	o.hit_interval = hit_interval
	o.spin_speed = spin
	ctx.add_to_world(o, ctx.player.global_position)
	return o
