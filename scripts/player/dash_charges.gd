class_name DashCharges
extends RefCounted
## 대시(무영보) 충전 관리. 충전은 한 번에 1개씩 순차 회복된다.

signal charges_changed(charges: int)

var max_charges: int = 2
## 충전 1개 회복 시간(초). 실험 초기값.
var recharge_time: float = 1.2

var charges: int = 2
var _progress: float = 0.0


func _init(p_max_charges: int = 2, p_recharge_time: float = 1.2) -> void:
	max_charges = maxi(p_max_charges, 1)
	recharge_time = maxf(p_recharge_time, 0.01)
	charges = max_charges


func is_full() -> bool:
	return charges >= max_charges


func can_consume() -> bool:
	return charges > 0


## 다음 충전까지 진행률 0~1 (가득 차 있으면 0).
func get_recharge_ratio() -> float:
	return 0.0 if is_full() else _progress / recharge_time


func try_consume() -> bool:
	if charges <= 0:
		return false
	charges -= 1
	charges_changed.emit(charges)
	return true


func update(delta: float) -> void:
	if is_full():
		_progress = 0.0
		return
	_progress += delta
	while _progress >= recharge_time and not is_full():
		_progress -= recharge_time
		charges += 1
		charges_changed.emit(charges)
	if is_full():
		_progress = 0.0
