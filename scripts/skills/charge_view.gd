class_name ChargeView
extends RefCounted
## 충전 중 바닥 표시 (SkillCaster에서 나눔): 영웅별 발밑 고리(ChargeMarker)와 모으는 마디(ChargeScaling.stages),
## 조준 기술이면 먹선 길(ChargeAim). 고리·길 상태는 SkillCaster(_marker(), aim)에 그대로.

static var _fallback: ChargeMarkerData


static func _now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0


## 매 물리 프레임: 조준 방향 따라가기, 고리 입자·마디 소리·다 찬 번쩍임.
static func tick(c: SkillCaster, delta: float) -> void:
	if c.player == null:
		return
	var charging := c.is_charging_alive()
	var k := c.input.charge_ratio(_now()) if charging else 0.0
	var m := c._marker()
	var md := m.data if m.data else _default_data()
	c.aim.tick(charging and aims(c), c.player.facing, c.player.move_input, md.aim_min_input)
	if c.player.is_dead():
		m.cancel()  # 죽으면 번쩍임까지 바로 지운다
		return
	var sc := scaling(c)
	m.tick(delta, charging, k, c.player.global_position, sc.stage_of(k) if sc else 0, sc.stages if sc else 0)


static func draw(c: SkillCaster) -> void:
	if c.player == null:
		return
	var charging := c.is_charging_alive()
	var k := c.input.charge_ratio(_now()) if charging else 1.0
	var m := c._marker()
	m.draw(c, charging, k)
	if charging and aims(c):
		c.aim.draw(c, c.kit.charge.aim_length(k), c.kit.charge.aim_width(k), k, m.data if m.data else _default_data())


## 충전 기술이 조준하는지 (SkillDef.charge_aim).
static func aims(c: SkillCaster) -> bool:
	return c.kit != null and c.kit.charge != null and c.kit.charge.charge_aim


## 충전 기술의 충전 비례 곡선 (마디 표시용, 없으면 null).
static func scaling(c: SkillCaster) -> ChargeScaling:
	return c.kit.charge.charge_scaling if c.kit and c.kit.charge else null


static func _default_data() -> ChargeMarkerData:
	if _fallback == null:
		_fallback = ChargeMarkerData.new()
	return _fallback
