class_name HazardClock
extends RefCounted
## 무대 장치 박자 (순수 로직): 기다림 → 예고(warn_time) → 발동 → 다시 기다림.
## running이 거짓이면 기다림이 멈춘다 (숨 고르기·강화 고르기 등). 이미 시작한 예고는 멈추지 않고 끝까지 간다
## (보인 예고가 사라지거나 길어지지 않게). 우두머리전에는 기다림이 boss_period_mult배로 늘고, 0이면 쉰다.

enum Event { NONE, WARN, STRIKE }

var data: StageHazardData
## 다음 예고까지 남은 시간(초).
var wait: float = 0.0
## 예고 중 남은 시간 (음수 = 예고 아님).
var warn: float = -1.0


func _init(d: StageHazardData) -> void:
	data = d
	wait = d.first_delay


func warning() -> bool:
	return warn >= 0.0


## 예고 진행 0 → 1.
func warn_ratio() -> float:
	if warn < 0.0 or data.warn_time <= 0.0:
		return 0.0
	return clampf(1.0 - warn / data.warn_time, 0.0, 1.0)


## 예고가 시작된 뒤 흐른 시간(초).
func warn_elapsed() -> float:
	return data.warn_time - warn if warn >= 0.0 else 0.0


func step(delta: float, running: bool, boss: bool) -> Event:
	if warn >= 0.0:
		warn -= delta
		if warn <= 0.0:
			warn = -1.0
			return Event.STRIKE
		return Event.NONE
	if not running or (boss and data.boss_period_mult <= 0.0):
		return Event.NONE
	wait -= delta / (data.boss_period_mult if boss else 1.0)
	if wait > 0.0:
		return Event.NONE
	wait += maxf(data.period - data.warn_time, 0.0)  # 예고 동안엔 기다림이 멈추니 빼 둔다: 예고 시작 → 다음 예고 시작 = period
	warn = maxf(data.warn_time, 0.0001)
	return Event.WARN
