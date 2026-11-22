class_name HitImpact
extends RefCounted
## 한 타 충격 (HitImpactData): 맞은 적마다 닿는 자리 섬광·튐 줄기·먹 방울, 휘두름 한 번에 퍽 소리(타마다 음높이)·진동.
## 평타(AutoAttack._strike)와 기술 명중(SkillContext.hit)이 같이 쓴다. Feedback이 없으면 아무 일도 안 함 (테스트 안전).

static var _layer: HitImpactLayer


static func data() -> HitImpactData:
	return Feedback.feel_data().hit_impact_data()


## 그림 층 (Feedback.fx 아래에 처음 쓸 때 한 번 만든다).
static func layer() -> HitImpactLayer:
	var fb := Feedback.instance
	if fb == null or fb.fx == null:
		return null
	if _layer == null or not is_instance_valid(_layer) or _layer.get_parent() != fb.fx:
		_layer = HitImpactLayer.new(data())
		fb.fx.add_child(_layer)
		var atk := fb.player.get_node_or_null("AutoAttack") as AutoAttack if fb.player else null
		if atk and not atk.has_meta(&"tip_spark"):  # 닿기 직전 칼끝 불꽃
			atk.set_meta(&"tip_spark", true)
			atk.melee_windup.connect(func(dir: Vector2) -> void: tip_spark(atk, dir))
	return _layer


## 무기가 닿는 자리: 적 몸에서 때린 쪽 가장자리, 가슴 높이.
static func contact_point(e: Enemy, from: Vector2) -> Vector2:
	var to := e.global_position - from
	var dir := to.normalized() if to.length_squared() > 0.01 else Vector2.RIGHT
	var r := e.body_radius * e.size_mult
	var up := (e.data.sprite_offset.y if e.data else -24.0) * e.size_mult * data().body_height_ratio
	return e.global_position - dir * r + Vector2(0, up)


## 맞은 적 하나: 섬광·줄기·먹 방울 (step = 1~3타).
static func on_enemy(e: Enemy, from: Vector2, step: int, color: Color) -> void:
	if e == null or not is_instance_valid(e):
		return
	var d := data()
	var p := contact_point(e, from)
	var dir := (e.global_position - from)
	var l := layer()
	var fb0 := Feedback.instance
	var style := fb0.player.hero.impact_style if fb0 and fb0.player and fb0.player.hero else 0
	if l:
		l.add(p, dir, step, color, style)
	var fb := Feedback.instance
	if fb and fb.kill_fx:
		fb.kill_fx.drops(p, dir, HitImpactData.at_i(d.drops, step, 4))


## 휘두름(또는 기술 명중) 한 번: 퍽 소리 (타마다 음높이) + 짧은 진동.
static func on_swing(step: int) -> void:
	var fb := Feedback.instance
	if fb == null:
		return
	var d := data()
	if d.thud_sfx != &"":
		fb.play(d.thud_sfx, 0.03, HitImpactData.at_f(d.pitch, step, 1.0), 1.0)  # 퍽 소리는 1 밑으로 내리지 않는다
	fb.haptic(HitImpactData.at_i(d.haptic_ms, step, 12), HitImpactData.at_f(d.haptic_amp, step, 0.35))


## 닿기 spark_lead초 전에 칼끝(사거리 앞쪽, 가슴 높이)에 작은 흰 불꽃 (게임 시간 기준).
static func tip_spark(atk: AutoAttack, dir: Vector2) -> void:
	if atk == null or not atk.is_inside_tree() or atk.player == null:
		return
	var d := data()
	var wait := maxf(atk.melee_delay() + atk.step_pause() - d.spark_lead, 0.0)
	var at := dir.normalized() * atk.stats().melee_range * 0.55 + Vector2(0, -40)
	atk.get_tree().create_timer(wait, false).timeout.connect(func() -> void:
		var l := layer()
		if l and is_instance_valid(atk) and atk.player:
			l.add_spark(atk.player.global_position + at))

