class_name JeongeumSkill
extends SkillDef
## 세종 · 정음진(가칭): 겨눈 적(SkillAim, 다른 영웅은 몸) 주위에 자모 글자 고리가 돌며 닿는 적에게 계속 피해.

@export var glyphs: String = "ㄱㄴㄷㅁㅅㅇ"
@export var radius: float = 110.0
@export var duration: float = 4.0
@export var damage: int = 10
@export var hit_interval: float = 0.5
## 0보다 크면 펼쳐지는 순간 고리 안 적을 이만큼(px) 바깥으로 날린다 (큰 기술 = 크게 날림, EnemyLaunch).
@export var launch_px: float = 0.0
## 고리 밑에 깔리는 정음 자모 그림 (함께 돈다).
@export var ring_art: Texture2D
## 펼치는 순간 고리 안에 적이 있으면 짧은 멈춤(초, 0이면 없음; 세종 0.04 — 사용자 "펼칠 때 한 방" 2026-11-26).
@export var open_stop: float = 0.0
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
	if outer_radius > 0.0:  # 바깥 고리는 가운데 적을 따로 치지 않는다 (두 겹이어도 가운데 적은 한 번씩)
		_ring(ctx, outer_radius, -2.4, center, follow).hit_core = false
	if ctx.fx and range_rings:
		ctx.fx.add_ring(center, radius, 0.3, fx_color)
	# 펼치는 순간 고리 안 적 수를 맞은 수로 알린다 (예전 0 → 4타가 헛친 흔들림 0.12·국악 강조음 없음).
	# 피해는 그대로 고리 긁기가 넣는다 (첫 긁기는 같은 순간, 진동 30ms는 SkillDef.first_tick_buzz).
	var caught := ctx.enemies_in_radius(center, maxf(radius, outer_radius)).size()
	if caught > 0 and open_stop > 0.0:
		ctx.hit_stop(open_stop)
	return SkillRun.instant(caught)


## 시전 연출도 고리가 펼쳐지는 자리(겨눈 적)에서 터진다 (영웅 몸에서 터지면 근거리 기술로 보인다).
func cast_point(ctx: SkillContext) -> Vector2:
	return SkillAim.point(ctx) if SkillAim.enabled(ctx) else ctx.player.global_position


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
