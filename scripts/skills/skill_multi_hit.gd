class_name SkillMultiHit
extends RefCounted
## 기술의 연속 타격 연출 (SkillHitFeelData): 틱마다 가벼운 타격(접점 섬광·작은 퍽·살짝 밀림, 멈춤 없음),
## 마지막 타는 큰 멈춤 한 번 + 3타급 퍽·진동. 기술 탄(Projectile)은 맞을 때마다 한 번에 끊어 치는 명중처럼.
## Feedback이 없으면 아무것도 안 함 (테스트 안전). SkillContext.tick_hit · watch_projectile이 부른다.

static var _last_finale_ms: int = -1000000


static func data() -> SkillHitFeelData:
	return SkillHitFeelData.get_default()


## 틱 한 번 (피해는 이미 들어갔다).
static func tick(ctx: SkillContext, en: Enemy) -> void:
	if en == null or not is_instance_valid(en) or ctx.player == null:
		return
	var d := data()
	HitImpact.on_enemy(en, ctx.player.global_position, d.tick_step, ctx.spark_color())
	var fb := Feedback.instance
	if fb == null:
		return
	if d.tick_thud:
		fb.play(HitImpact.data().thud_sfx, d.tick_gap, d.tick_pitch)
	if d.tick_kick > 0.0:
		fb.kick(en.global_position - ctx.player.global_position, d.tick_kick)


## 마지막 타: 큰 멈춤 한 번 (finale_gap 안에 다시 부르면 생략 → 여러 적이 동시에 마지막 타를 맞아도 한 번), 3타급 퍽·진동.
## 반환: 이번에 멈췄으면 true.
static func finale(ctx: SkillContext) -> bool:
	var d := data()
	var now := Time.get_ticks_msec()
	if now - _last_finale_ms < int(d.finale_gap * 1000.0):
		return false
	_last_finale_ms = now
	HitImpact.on_swing(3)
	if ctx == null or not ctx.hit_stop_enabled or ctx.player == null or not ctx.player.is_inside_tree():
		return true
	var t := d.finale_seconds(Feedback.feel_data())
	if t > 0.0:
		GameTime.stop(ctx.player.get_tree(), t, d.finale_scale)
	return true


static func reset() -> void:
	_last_finale_ms = -1000000
