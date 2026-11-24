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


## 값 줄들: [{label, from, to}] (화면 글). steps = 이번에 오르는 단계 수. 바뀌지 않는 값은 뺀다.
static func lines(u: UpgradeDef, build: RunBuild, steps: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if u == null or build == null or build.hero == null:
		return out
	var d := data()
	for m in u.mods:
		var obj := build.target_of(m.target)
		if obj == null or not (m.property in obj) or d.label(m.property) == "":
			continue
		var cur: Variant = obj.get(m.property)
		if float(cur) == 0.0:
			return []  # 0에서 켜지는 값 (큰 변형): 숫자 대신 설명
		var next: Variant = cur
		for i in maxi(steps, 1):
			next = m.apply_to(next)
		if is_equal_approx(float(next), float(cur)):
			continue
		out.append({"label": d.label(m.property), "from": d.fmt(m.property, cur), "to": d.fmt(m.property, next)})
	return out
