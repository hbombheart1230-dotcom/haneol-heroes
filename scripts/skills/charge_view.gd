class_name ChargeView
extends RefCounted
## 충전 중 바닥 표시 (SkillCaster에서 나눔): 영웅별 발밑 고리(ChargeMarker)와 모으는 마디(ChargeScaling.stages),
## 조준 기술이면 먹선 길(ChargeAim). 고리·길 상태는 SkillCaster(_marker(), aim)에 그대로.

static var _fallback: ChargeMarkerData
static var _sc_src: SkillDef
static var _sc_level: int = -1
static var _sc: SkillDef
static var _dim_src: ChargeMarkerData
static var _dim: ChargeMarkerData


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
	m.tick(delta, charging, k, c.player.global_position, sc.stage_of(k) if sc else 0, sc.stages if sc else 0,
		c.cooldown_left(SkillCaster.Slot.CHARGE))  # 쿨타임이면 흐린 고리 + 남은 시간 (떼도 안 나감)


static func draw(c: SkillCaster) -> void:
	if c.player == null:
		return
	var charging := c.is_charging_alive()
	var k := c.input.charge_ratio(_now()) if charging else 1.0
	var m := c._marker()
	m.draw(c, charging, k)
	if not charging:
		_sc = null  # 모을 때마다 새로 (강화로 바뀐 값도 따라간다)
	if charging and aims(c):
		var md := m.data if m.data else _default_data()
		var d := c.kit.charge
		if d.charge_aim_auto and not c.aim.steered:
			return  # 끌지 않으면 예전 자동: 표시 없음
		if m.waiting():  # 쿨타임이면 조준 길도 흐리게 (마디 점·고리와 같은 배율)
			md = _dimmed(md)
		if not scaled(d).draw_aim(c, k, c.aim.dir, md):
			c.aim.draw(c, scaled(d).aim_length(k), aim_width(c, k), k, md)  # 길이도 성장 배율이 든 판정대로


## 조준 길 폭: 쏘는 물결과 같은 성장 단계 배율 (SkillCaster.cast가 SkillGrowthData.scaled_def로 키운 판정과 맞춘다).
static func aim_width(c: SkillCaster, k: float) -> float:
	var d := c.kit.charge
	var w: float = d.aim_width(k)
	return w * SkillGrowthData.get_default().size_at(d.vfx_level) if SkillGrowthData.applies(d) else w


## 성장 단계 배율이 들어간 사본 (발동 때와 같은 SkillGrowthData.scaled_def): 그린 모양 = 판정. 모으기 한 번에 한 번 만든다.
static func scaled(d: SkillDef) -> SkillDef:
	if d != _sc_src or d.vfx_level != _sc_level or _sc == null:
		_sc_src = d
		_sc_level = d.vfx_level
		_sc = SkillGrowthData.get_default().scaled_def(d)
	return _sc


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


## 쿨타임 중 조준 길용 흐린 사본 (데이터마다 한 번 만든다).
static func _dimmed(md: ChargeMarkerData) -> ChargeMarkerData:
	if _dim_src != md or _dim == null:
		_dim_src = md
		_dim = md.duplicate() as ChargeMarkerData
		_dim.aim_fill.a *= md.wait_dim
		_dim.aim_ink.a *= md.wait_dim
	return _dim
