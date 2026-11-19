class_name StatMod
extends Resource
## 성장 선택 하나가 바꾸는 수치 하나. 코드가 아니라 데이터로 성장을 정의한다.
##   target: hero | attack | kit | tap | dash | charge | counter
##   property: 대상 리소스의 @export 이름 (예: radius, damage, cooldown)

enum Op { ADD, MUL }

@export var target: StringName = &"tap"
@export var property: StringName = &""
@export var op: Op = Op.MUL
@export var value: float = 1.0


## 현재 값에 적용한 결과. 정수 속성은 반올림하되 늘리는 변화면 최소 1은 오르게 한다.
func apply_to(current: Variant) -> Variant:
	var f := float(current)
	var result := f + value if op == Op.ADD else f * value
	if typeof(current) == TYPE_INT:
		var r := roundi(result)
		if r == int(current) and result != f:
			r += 1 if result > f else -1
		return r
	return result
