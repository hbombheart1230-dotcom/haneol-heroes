class_name SkillRun
extends RefCounted
## 발동된 기술의 진행 상태. 여러 프레임에 걸치는 기술(연타 등)은 상속해 tick을 구현한다.

var finished: bool = false
var hits: int = 0


static func instant(p_hits: int) -> SkillRun:
	var r := SkillRun.new()
	r.hits = p_hits
	r.finished = true
	return r


## 반환: 끝났으면 true.
func tick(_delta: float) -> bool:
	return finished
