class_name UpgradeReadoutData
extends Resource
## 강화 패 읽기 표: 바꾸는 속성(StatMod.property)마다 종류(띠 낱말·색)와 값 이름. 패 화면(UpgradeCards)이 읽는다.
## 화면 글은 우리말만 (tests/test_korean_wording).

## 속성 → 종류 (kind_words·kind_colors의 열쇠). 없으면 default_kind.
@export var kinds: Dictionary = {}
@export var default_kind: StringName = &"strong"
## 종류 → 띠에 크게 쓸 한 낱말.
@export var kind_words: Dictionary = {}
## 종류 → 띠 색 (순적색은 적 위험 전용이라 쓰지 않는다).
@export var kind_colors: Dictionary = {}
## 큰 변형 패의 띠 낱말·색.
@export var major_word: String = "큰 변형"
@export var major_color: Color = Color(0.78, 0.6, 0.18)
## 속성 → 값 이름 ("범위 100 → 125"의 "범위").
@export var labels: Dictionary = {}
## 같이 오르는 속성들의 한 줄 이름: 이 속성들의 값 줄이 "지금 → 뒤"까지 똑같으면 이 이름으로 한 줄만
## (근접·원거리 피해가 같으면 "평타 피해", 다르면 "베기 피해" / "날림 피해" 두 줄).
@export var shared_labels: Dictionary = {}
## 초로 읽는 속성 (뒤에 "초").
@export var seconds: Array[StringName] = []
## 비율(0~1)로 읽는 속성 (백분율로).
@export var percents: Array[StringName] = []


func kind_of(prop: StringName) -> StringName:
	return kinds.get(prop, default_kind)


func word(kind: StringName) -> String:
	return kind_words.get(kind, "")


func color(kind: StringName) -> Color:
	return kind_colors.get(kind, Color(0.5, 0.5, 0.5))


func label(prop: StringName) -> String:
	return labels.get(prop, "")


func shared_label(prop: StringName) -> String:
	return shared_labels.get(prop, "")


## 값 하나를 화면 글로 (정수는 그대로, 초·백분율은 붙여서, 소수는 뒤 0을 뗀다).
func fmt(prop: StringName, v: Variant) -> String:
	if typeof(v) == TYPE_INT:
		return str(v)
	var f := float(v)
	if prop in percents:
		return "%d%%" % roundi(f * 100.0)
	var s := ("%.2f" % f).rstrip("0").rstrip(".")
	if f >= 10.0:
		s = str(roundi(f))
	return s + ("초" if prop in seconds else "")
