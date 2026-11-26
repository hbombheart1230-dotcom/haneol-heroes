class_name UpgradeEffect
extends RefCounted
## 강화 값이 판에서 실제로 쓰이는 크기 (순수 계산). 패 글 "지금 → 뒤"(UpgradeReadout)와 헛된 패 거르기(UpgradePool)가 같이 쓴다.
## 실제 값 = 기술 상한(SkillDef.effective, 예: 풀벌레 수명) → 판정 크기는 모습 단계 배율(SkillGrowthData)
## → 피해는 4타 마무리 배율(1번, combo_finisher_mult)·내닫기 뒤 자동 배율(2번, dash_auto_damage_mult)
## → 1번 쿨타임은 마무리 간격(× combo_finisher_cd_ratio). 판정·그림 쪽은 건드리지 않고 읽기만 한다.

## 4타 마무리 배율 패가 보여 줄 값: 1번 기술의 이 피해 속성 × 배율.
const FINISHER_PROP := &"combo_finisher_mult"


## 피해 속성인지 (TapCombo.scaled_def와 같은 규칙: 이름에 damage, mult·ratio는 아님).
static func is_damage(prop: StringName) -> bool:
	var n := String(prop)
	return n.contains("damage") and not n.contains("mult") and not n.contains("ratio")


## 판정 크기 속성인지 (모습 단계 배율을 받는 것).
static func is_hit_prop(obj: Object, prop: StringName) -> bool:
	return obj is SkillDef and SkillGrowthData.applies(obj) and String(prop) in SkillGrowthData.get_default().hit_props


## 이 기술의 피해가 실제로 곱해지는 배율 (1번 = 4타 마무리, 자동 2번 = 자동 배율).
static func damage_mult(kit: SkillKit, d: Object) -> float:
	if kit == null:
		return 1.0
	if d == kit.tap and kit.tap_combo:
		return kit.combo_finisher_mult
	if d == kit.dash and kit.dash_auto:
		return kit.dash_auto_damage_mult
	return 1.0


## obj.prop 값이 v일 때 실제로 쓰이는 값. level = 그 기술의 모습 단계 (판정 크기 배율).
## as_def: 상한 계산에 쓸 기술 (패를 적용해 본 사본, 없으면 obj). 배율은 obj가 1번·2번 자리인지로 정한다.
static func real(build: RunBuild, obj: Object, prop: StringName, v: Variant, level: int, as_def: SkillDef = null) -> float:
	var kit: SkillKit = build.hero.kit if build and build.hero else null
	if obj == kit and prop == FINISHER_PROP:
		return float(finisher_damage(kit, float(v)))
	if not (obj is SkillDef):
		return float(v)
	var d := obj as SkillDef
	var x: Variant = (as_def if as_def else d).effective(prop, v, kit)
	if is_hit_prop(d, prop):
		return float(x) * SkillGrowthData.get_default().size_at(level)
	if is_damage(prop):
		var m := damage_mult(kit, d)
		return float(maxi(roundi(float(x) * m), 1)) if typeof(v) == TYPE_INT else float(x) * m
	if prop == &"cooldown" and kit and d == kit.tap and kit.tap_combo and not kit.combo_finisher_free:
		return float(x) * kit.combo_finisher_cd_ratio  # 단추는 기본 꺼짐: 실제로 도는 것은 마무리 간격
	return float(x)


## 4타 마무리 한 번의 피해 (1번 기술의 첫 피해 속성 × 배율). 피해 속성이 없으면 0.
static func finisher_damage(kit: SkillKit, mult: float) -> int:
	if kit == null or kit.tap == null:
		return 0
	for p in [&"damage", &"max_damage"]:
		if p in kit.tap:
			return maxi(roundi(float(kit.tap.get(p)) * mult), 1)
	return 0


## 이 기술의 대표 판정 크기 속성 (값이 있고 named(이름)가 참인 첫 hit_prop). 없으면 빈 이름.
static func main_hit_prop(d: SkillDef, named: Callable) -> StringName:
	if not SkillGrowthData.applies(d):
		return &""
	for n in SkillGrowthData.get_default().hit_props:
		if n in d and typeof(d.get(n)) == TYPE_FLOAT and float(d.get(n)) > 0.0 and named.call(StringName(n)):
			return StringName(n)
	return &""


## 이 패를 지금 고르면 패가 말하는 값 중 하나라도 실제로 달라지는지 (상한에 닿아 헛된 패는 false).
## 모습 단계로 커지는 몫은 보지 않는다 (패가 말하는 값만). 0에서 켜지는 큰 변형은 늘 true.
static func useful(build: RunBuild, u: UpgradeDef) -> bool:
	if build == null or build.hero == null or u == null or u.mods.is_empty():
		return true
	for m in u.mods:
		var obj := build.target_of(m.target)
		if obj == null or not (m.property in obj):
			continue
		var cur: Variant = obj.get(m.property)
		if float(cur) == 0.0:
			return true
		var lv: int = (obj as SkillDef).vfx_level if obj is SkillDef else 0
		if not is_equal_approx(real(build, obj, m.property, cur, lv), real(build, obj, m.property, m.apply_to(cur), lv)):
			return true
	return false
