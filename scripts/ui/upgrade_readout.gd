class_name UpgradeReadout
extends RefCounted
## 강화 패가 바꾸는 값을 "지금 → 고른 뒤"로 계산한다 (순수 로직). 값은 패 데이터(StatMod)와 이번 판 수치(RunBuild)에서.
## 숫자로 못 읽는 패(큰 변형처럼 0에서 켜지는 값)는 빈 목록 → 화면은 설명 한 줄.

const DATA_PATH := "res://data/ui/upgrade_readout.tres"

static var _data: UpgradeReadoutData


static func data() -> UpgradeReadoutData:
	if _data == null:
		_data = load(DATA_PATH) as UpgradeReadoutData
	return _data


## 패의 종류 (첫 번째로 바꾸는 속성으로).
static func kind(u: UpgradeDef) -> StringName:
	if u == null or u.mods.is_empty():
		return data().default_kind
	return data().kind_of(u.mods[0].property)


## 값 줄들: [{label, from, to}] 또는 [{label, text}] (화면 글). steps = 이번에 오르는 단계 수.
## 값은 실제로 쓰이는 크기 (UpgradeEffect.real: 모습 단계 배율, 4타 마무리·자동 2번 배율, 마무리 간격, 상한).
## 판정 크기(범위·폭·길이)는 실제로 커지는 비율 "+47%"로. 패가 기술 모습 단계를 올려 판정이 같이 커지면
## (피해 패라도) 그 기술의 대표 크기 줄을 하나 더, 상한이 걸린 값(풀벌레 수명)이 같이 바뀌면 그 줄도 더 보인다.
## 바뀌지 않는 값과 이 영웅이 쓰지 않는 값(원거리 평타가 없는 영웅의 원거리 피해)은 뺀다.
## 같은 한 줄 이름(shared_labels)을 가진 속성들이 값까지 같거나 하나만 남으면 그 이름으로 한 줄
## (근접·원거리 피해가 같이 오르는 "평타 피해"), 값이 다르면 각자 이름("베기 피해" / "날림 피해").
static func lines(u: UpgradeDef, build: RunBuild, steps: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if u == null or build == null or build.hero == null:
		return out
	var d := data()
	steps = maxi(steps, 1)
	var shared := {}  # 한 줄 이름 → 첫 줄의 자리
	var members := {}  # 한 줄 이름 → 그 묶음 줄 수
	var after := {}  # 이 패가 건드리는 기술 → 패를 적용해 본 사본
	var said := {}  # 기술 → 이미 보인 속성들
	for m in u.mods:
		var obj := build.target_of(m.target)
		if obj == null or not (m.property in obj) or d.label(m.property) == "" or unused(build, m.property):
			continue
		var cur: Variant = obj.get(m.property)
		if float(cur) == 0.0:
			return []  # 0에서 켜지는 값 (큰 변형): 숫자 대신 설명
		var next: Variant = _applied(m, cur, steps)
		var lv := _levels(u, obj, steps)
		var a := UpgradeEffect.real(build, obj, m.property, cur, lv.x)
		var b := UpgradeEffect.real(build, obj, m.property, next, lv.y, _copy(after, build, u, obj, steps))
		if obj is SkillDef:
			said[obj] = said.get(obj, []) + [m.property]
		if is_equal_approx(a, b):
			continue
		var line := _line(d, obj, m.property, cur, a, b)
		var sl := d.shared_label(m.property)
		if sl != "" and shared.has(sl):
			var first: Dictionary = out[shared[sl]]
			if first.get("from") == line.get("from") and first.get("to") == line.get("to"):
				continue
			members[sl] += 1
		elif sl != "":
			shared[sl] = out.size()
			members[sl] = 1
		if not out.has(line):
			out.append(line)
	for sl in shared:
		if members[sl] == 1:
			out[shared[sl]]["label"] = sl
	for obj in after:  # 같이 바뀌는 몫: 모습 단계로 커지는 판정, 상한이 걸린 값
		out.append_array(_side_lines(d, build, u, obj, after[obj], said.get(obj, []), steps))
	return out


## 패 한 장을 steps번 적용한 값.
static func _applied(m: StatMod, cur: Variant, steps: int) -> Variant:
	var next: Variant = cur
	for i in steps:
		next = m.apply_to(next)
	return next


## (지금 모습 단계, 고른 뒤 모습 단계). 기술이 아니면 (0, 0).
static func _levels(u: UpgradeDef, obj: Object, steps: int) -> Vector2i:
	if not (obj is SkillDef):
		return Vector2i.ZERO
	var lv := (obj as SkillDef).vfx_level
	return Vector2i(lv, lv + u.vfx_level_gain * steps)


## 패가 건드리는 기술에 이 패의 값들을 적용해 본 사본 (상한 계산용, 기술마다 한 번만 만든다).
static func _copy(after: Dictionary, build: RunBuild, u: UpgradeDef, obj: Object, steps: int) -> SkillDef:
	if not (obj is SkillDef):
		return null
	if not after.has(obj):
		var c := (obj as SkillDef).duplicate() as SkillDef
		for m in u.mods:
			if build.target_of(m.target) == obj and m.property in c:
				c.set(m.property, _applied(m, c.get(m.property), steps))
		after[obj] = c
	return after[obj]


## 한 줄: 판정 크기는 실제 비율, 나머지는 "지금 → 뒤".
static func _line(d: UpgradeReadoutData, obj: Object, prop: StringName, cur: Variant, a: float, b: float) -> Dictionary:
	if UpgradeEffect.is_hit_prop(obj, prop):
		return {"label": d.label(prop), "text": pct(a, b)}
	if typeof(cur) == TYPE_INT:
		return {"label": d.label(prop), "from": d.fmt(prop, roundi(a)), "to": d.fmt(prop, roundi(b))}
	return {"label": d.label(prop), "from": d.fmt(prop, a), "to": d.fmt(prop, b)}


## 바뀐 비율 글 ("+47%", "-20%").
static func pct(a: float, b: float) -> String:
	if a == 0.0:
		return ""
	var p := roundi((b / a - 1.0) * 100.0)
	return ("+%d%%" % p) if p >= 0 else ("%d%%" % p)


## 패가 말하지 않지만 같이 바뀌는 줄들: 모습 단계로 커지는 대표 판정 크기, 상한이 걸린 값.
static func _side_lines(d: UpgradeReadoutData, build: RunBuild, u: UpgradeDef, obj: SkillDef, copy: SkillDef,
		said: Array, steps: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lv := _levels(u, obj, steps)
	var hp := UpgradeEffect.main_hit_prop(obj, func(p: StringName) -> bool: return d.label(p) != "")
	var g := SkillGrowthData.get_default()
	if hp != &"" and d.label(hp) != "" and not said.any(func(p: StringName) -> bool: return UpgradeEffect.is_hit_prop(obj, p)):
		var k0 := g.size_at(lv.x)
		var k1 := g.size_at(lv.y)
		if not is_equal_approx(k0, k1):
			out.append({"label": d.label(hp), "text": pct(k0, k1)})
	for cp in obj.capped_props():
		if cp in said or d.label(cp) == "":
			continue
		var a := UpgradeEffect.real(build, obj, cp, obj.get(cp), lv.x)
		var b := UpgradeEffect.real(build, obj, cp, copy.get(cp), lv.y, copy)
		if not is_equal_approx(a, b):
			out.append(_line(d, obj, cp, obj.get(cp), a, b))
	return out


## 이 영웅이 쓰지 않는 평타 값인지 (원거리 평타도 원거리 탭도 없으면 원거리 피해).
static func unused(build: RunBuild, prop: StringName) -> bool:
	if prop != &"ranged_damage" or build.hero.attack == null:
		return false
	var kit := build.hero.kit
	return not build.hero.attack.use_ranged and not (kit != null and kit.ranged_taps)
