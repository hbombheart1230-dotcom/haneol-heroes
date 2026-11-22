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
	if l:
		l.add(p, dir, step, color)
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
