class_name ComboHits
extends RefCounted
## 연타 숫자 (순수 로직): 적을 맞힐 때마다 하나씩 오르고 (5타, 6타…), timeout초 동안 못 맞히면 바로 0.


var count: int = 0
## 마지막으로 맞힌 뒤 흐른 시간 (초).
var since: float = INF


func add(n: int = 1) -> void:
	if n <= 0:
		return
	count += n
	since = 0.0


## 반환: 이번에 끊겨 0이 됐으면 true.
func tick(delta: float, timeout: float) -> bool:
	since += delta
	if count > 0 and since > timeout:
		count = 0
		return true
	return false
