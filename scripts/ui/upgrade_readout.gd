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


## 값 줄들: [{label, from, to}] (화면 글). steps = 이번에 오르는 단계 수. 바뀌지 않는 값과
## 이 영웅이 쓰지 않는 값(원거리 평타가 없는 영웅의 원거리 피해)은 뺀다.
## 같은 한 줄 이름(shared_labels)을 가진 속성들이 값까지 같거나 하나만 남으면 그 이름으로 한 줄
## (근접·원거리 피해가 같이 오르는 "평타 피해"), 값이 다르면 각자 이름("베기 피해" / "날림 피해").
static func lines(u: UpgradeDef, build: RunBuild, steps: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if u == null or build == null or build.hero == null:
		return out
	var d := data()
	var shared := {}  # 한 줄 이름 → 첫 줄의 자리
	var members := {}  # 한 줄 이름 → 그 묶음 줄 수
	for m in u.mods:
		var obj := build.target_of(m.target)
		if obj == null or not (m.property in obj) or d.label(m.property) == "" or unused(build, m.property):
			continue
		var cur: Variant = obj.get(m.property)
		if float(cur) == 0.0:
			return []  # 0에서 켜지는 값 (큰 변형): 숫자 대신 설명
		var next: Variant = cur
		for i in maxi(steps, 1):
			next = m.apply_to(next)
		if is_equal_approx(float(next), float(cur)):
			continue
		var line := {"label": d.label(m.property), "from": d.fmt(m.property, cur), "to": d.fmt(m.property, next)}
		var sl := d.shared_label(m.property)
		if sl != "" and shared.has(sl):
			var first: Dictionary = out[shared[sl]]
			if first["from"] == line["from"] and first["to"] == line["to"]:
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
	return out


## 이 영웅이 쓰지 않는 평타 값인지 (원거리 평타도 원거리 탭도 없으면 원거리 피해).
static func unused(build: RunBuild, prop: StringName) -> bool:
	if prop != &"ranged_damage" or build.hero.attack == null:
		return false
	var kit := build.hero.kit
	return not build.hero.attack.use_ranged and not (kit != null and kit.ranged_taps)
