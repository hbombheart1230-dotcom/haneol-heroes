class_name JeongeumSkill
extends SkillDef
## 세종 · 정음진(가칭): 몸 주위에 자모 글자 고리가 돌며 닿는 적에게 계속 피해.

@export var glyphs: String = "ㄱㄴㄷㅁㅅㅇ"
@export var radius: float = 110.0
@export var duration: float = 4.0
@export var damage: int = 10
@export var hit_interval: float = 0.5
## 0보다 크면 펼쳐지는 순간 고리 안 적을 이만큼(px) 바깥으로 날린다 (큰 기술 = 크게 날림, EnemyLaunch).
@export var launch_px: float = 0.0
## 고리 밑에 깔리는 정음 자모 그림 (함께 돈다).
@export var ring_art: Texture2D
@export_group("큰 변형 · 두 겹 고리")
## 0보다 크면 이 반경으로 바깥 고리가 하나 더 (반대로 돈다).
@export var outer_radius: float = 0.0


func cast(ctx: SkillContext, _charge: float) -> SkillRun:
	# 세종 (SkillAim): 고리가 겨눈 적에게 씌워져 그 적을 따라다닌다 (적이 없으면 앞쪽 기본 거리에 선다).
	var aimed := SkillAim.enabled(ctx)
	var foe := SkillAim.target(ctx) if aimed else null
	var center := SkillAim.point_for(ctx, foe) if aimed else ctx.player.global_position
	var follow: Node2D = foe if aimed and foe and center.distance_to(foe.global_position) < 1.0 else null
	if not aimed:
		follow = ctx.player
	if launch_px > 0.0:  # 글자 고리가 퍼지며 밀어낸다
		for en in ctx.enemies_in_radius(center, radius):
			if en != foe:
				ComboSteps.push_out(en, center, launch_px, 0.0)
	_ring(ctx, radius, 3.2, center, follow)
	if outer_radius > 0.0:
		_ring(ctx, outer_radius, -2.4, center, follow)
	if ctx.fx:
		ctx.fx.add_ring(center, radius, 0.3, fx_color)
	return SkillRun.instant(0)


func _ring(ctx: SkillContext, r: float, spin: float, at: Vector2, follow: Node2D) -> OrbitGlyphs:
	var o := OrbitGlyphs.new()
	o.ctx = ctx
	o.follow = follow
	o.glyphs = glyphs
	o.radius = r
	o.duration = duration
	o.damage = damage
	o.hit_interval = hit_interval
	o.spin_speed = spin
	o.art = ring_art
	ctx.add_to_world(o, at)
	return o
