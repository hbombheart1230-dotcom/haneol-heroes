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
