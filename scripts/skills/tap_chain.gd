class_name TapChain
extends RefCounted
## 탭 연타 (SkillCaster에서 나눔): 탭 하나 = 평타 한 타 / 마무리 기술 / 기억, 손 평타 최소 간격, 기억해 둔 탭 내기.
## 상태(TapCombo)는 SkillCaster.combo에 그대로.


## 제자리 탭 하나: 평타 한 타, 연계가 찼으면 tap 기술 마무리, 너무 빠르면 잠깐 기억. 반환: 마무리면 TAP.
static func tap(c: SkillCaster) -> SkillCaster.Slot:
	var atk := c.auto_attack()
	var can := atk != null and atk.can_manual(c.tap_gap())
	match c.combo.decide(c.kit.combo_hits, can, c.is_ready(SkillCaster.Slot.TAP)):
		TapCombo.Action.FINISH:
			if not ComboSteps.finisher_ready(atk, c.kit.finisher_after_strike):
				c.combo.buffer(c.kit.finisher_buffer)  # 3타가 닿을 때까지 기억 (F1)
				return SkillCaster.Slot.NONE
			c.combo.on_finish()
			c.cast(SkillCaster.Slot.TAP, 0.0, c.kit.combo_finisher_mult, c.kit.tap.cooldown * c.kit.combo_finisher_cd_ratio)
			c.combo_count.emit(c.kit.combo_hits + 1)  # 마무리 = 4타
			return SkillCaster.Slot.TAP
		TapCombo.Action.HIT:
			atk.manual_strike(c.combo.on_hit(c.kit.combo_hits, atk.stats().chain_len), c.kit.ranged_taps)
		TapCombo.Action.BUFFERED:
			c.combo.buffer(c.kit.tap_buffer)
	return SkillCaster.Slot.NONE


## 손 평타 최소 간격(초): 평타 간격 × tap_min_gap_mult (공격속도 강화를 따른다).
static func gap(c: SkillCaster) -> float:
	var atk := c.auto_attack()
	if atk == null or c.kit == null:
		return 0.0
	var d := atk.stats()
	var next := c.combo.step % maxi(d.chain_len, 1) + 1  # 다음 타 번호의 박자 (빠름·빠름·묵직)
	return (d.ranged_interval if c.kit.ranged_taps else d.melee_interval) * ComboSteps.at(d.step_gap_mults, next, c.kit.tap_min_gap_mult)


## 기억해 둔 탭: 칠 수 있게 되면(또는 마무리가 준비되면) 바로 낸다.
static func flush(c: SkillCaster) -> void:
	if not c.combo.has_buffer() or c.player == null or c.player.is_dead():
		return
	var instant := c._instant_slot()  # 기억해 둔 탭도 반격·대시 연계가 열리면 그쪽이 먼저 (Codex 41741bc 지적)
	if instant != SkillCaster.Slot.NONE:
		c.combo.buffer(0.0)
		c.cast(instant)
		return
	var atk := c.auto_attack()
	var finish := c.combo.streak >= c.kit.combo_hits and c.is_ready(SkillCaster.Slot.TAP)
	if finish or (atk and atk.can_manual(c.tap_gap())):
		tap(c)
