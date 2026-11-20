class_name SfxVoices
extends RefCounted
## 효과음 재생기 고르기 (순수 로직, S3). 재생기 수는 고정, 소리마다 우선순위·동시 최대 수가 있다.
## 1) 같은 종류가 이미 max_same개 울리면 그중 가장 오래된 것을 다시 쓴다 (군중 명중음이 다른 소리를 밀어내지 않게).
## 2) 빈 재생기가 있으면 그것.
## 3) 없으면 우선순위가 같거나 낮은 것 중 (가장 낮은 → 가장 오래된) 것을 끊는다. 모두 더 높으면 -1 (안 냄).

var kinds: Array[StringName] = []
var prios: Array[int] = []
var starts: Array[float] = []


func _init(count: int) -> void:
	kinds.resize(count)
	prios.resize(count)
	starts.resize(count)
	for i in count:
		kinds[i] = &""
		prios[i] = 0
		starts[i] = -INF


## playing[i]: i번 재생기가 지금 울리는 중인지. 반환: 쓸 재생기 번호 (-1이면 내지 않음).
func pick(kind: StringName, prio: int, max_same: int, now: float, playing: Array[bool]) -> int:
	var same := -1
	var same_n := 0
	for i in kinds.size():
		if playing[i] and kinds[i] == kind:
			same_n += 1
			if same < 0 or starts[i] < starts[same]:
				same = i
	if max_same > 0 and same_n >= max_same:
		return _take(same, kind, prio, now)
	for i in kinds.size():
		if not playing[i]:
			return _take(i, kind, prio, now)
	var best := -1
	for i in kinds.size():
		if prios[i] > prio:
			continue
		if best < 0 or prios[i] < prios[best] or (prios[i] == prios[best] and starts[i] < starts[best]):
			best = i
	return _take(best, kind, prio, now) if best >= 0 else -1


func _take(i: int, kind: StringName, prio: int, now: float) -> int:
	kinds[i] = kind
	prios[i] = prio
	starts[i] = now
	return i
