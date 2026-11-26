class_name Haptics
extends RefCounted
## 타격 진동 (설정 "타격 진동"을 따른다). 안드로이드는 내보내기 설정의 VIBRATE 권한이 필요하다.

## 마지막 진동 요청 (테스트·진단용): [밀리초, 세기].
static var last: Array = []


static func pulse(ms: int = 30, amplitude: float = 0.5) -> bool:
	if not GameSettings.haptics_enabled or ms <= 0:
		return false
	last = [ms, amplitude]
	Input.vibrate_handheld(ms, clampf(amplitude, 0.0, 1.0))
	return true


## 간격 규칙 (순수): 앞 진동에서 gap초가 지났거나, 이번 진동(ms × 세기)이 앞 것보다 세면 낸다.
## 예전엔 간격 안이면 늘 버려서, 4타(해룡참)가 누르는 순간 낸 약한 진동(15ms)이 0.1초 뒤 칼이 닿을 때의
## 센 진동(30ms)을 막았다 (폴드 7 0570b0b "4타가 진동이랑 타격감이 없다", PC 실측 13번 중 9번).
static func passes_gap(since: float, gap: float, power: float, last_power: float) -> bool:
	return since >= gap or power > last_power
