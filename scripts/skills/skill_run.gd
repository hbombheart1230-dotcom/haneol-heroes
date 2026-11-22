class_name SkillRun
extends RefCounted
## 발동된 기술의 진행 상태. 여러 프레임에 걸치는 기술(연타 등)은 상속해 tick을 구현한다.

var finished: bool = false
var hits: int = 0
## 0 이상이면 누르는 순간 이 맞힐 수로 발동을 알린다 (휘감는 기술: 소리·흔들림이 붓보다 늦지 않게).
## 끝날 때 다시 알리지 않는다.
var announce_hits: int = -1


static func instant(p_hits: int) -> SkillRun:
	var r := SkillRun.new()
	r.hits = p_hits
	r.finished = true
	return r


## 반환: 끝났으면 true.
func tick(_delta: float) -> bool:
	return finished
