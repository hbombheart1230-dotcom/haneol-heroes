class_name ElementEvents
extends RefCounted
## 기술 성질 알림 (SkillDef.element): 성질이 있는 기술이 내리꽂히면 (SkillContext.impact) 자리·반경을 듣는 이들에게
## 알린다. 무대 장치가 듣는다 (만주 들불: thunder·meteor는 붙이고 water는 끈다). 영웅·기술 파일은 장치를 모른다.

static var _listeners: Array[Callable] = []


static func listen(c: Callable) -> void:
	if not _listeners.has(c):
		_listeners.append(c)


static func unlisten(c: Callable) -> void:
	_listeners.erase(c)


## element 기술이 pos에 반경 radius로 떨어졌다 (반경 0이면 듣는 쪽 기본값).
static func emit(element: StringName, pos: Vector2, radius: float) -> void:
	for i in range(_listeners.size() - 1, -1, -1):
		var c := _listeners[i]
		if c.is_valid():
			c.call(element, pos, radius)
		else:
			_listeners.remove_at(i)
