class_name ZonePlan
extends RefCounted
## 구역 차례 (순수 로직, StageTheme.zones): 지금 구역, 어느 물결을 깨면 다음 구역으로 넘어가는지.

var zones: Array[ZoneData] = []
var current: int = 0


func _init(p_zones: Array[ZoneData] = []) -> void:
	zones = p_zones


## 구역이 둘 이상일 때만 건너뛰기가 있다.
func active() -> bool:
	return zones.size() >= 2


func zone() -> ZoneData:
	return zones[current] if current < zones.size() else null


func next_zone() -> ZoneData:
	return zones[current + 1] if current + 1 < zones.size() else null


## 구역 i가 끝나는 물결 번호 (0부터, 그 구역 마지막 물결). 물결이 없는 구역이면 앞 구역 끝과 같다.
func last_wave(i: int) -> int:
	var n := 0
	for k in mini(i + 1, zones.size()):
		n += maxi(zones[k].waves, 0)
	return n - 1


## 방금 깬 물결(0부터)이 지금 구역의 마지막이고 다음 구역이 있으면 true.
func ends_zone(cleared: int) -> bool:
	return active() and current < zones.size() - 1 and cleared >= last_wave(current)


## 다음 구역으로. 넘어간 구역을 돌려준다 (없으면 null).
func advance() -> ZoneData:
	if current + 1 >= zones.size():
		return null
	current += 1
	return zones[current]


## 다음 구역 쪽 안내 글.
func prompt() -> String:
	var z := zone()
	var n := next_zone()
	if z == null or n == null:
		return ""
	return z.prompt if z.prompt != "" else "%s 쪽으로 내닫기" % n.title
