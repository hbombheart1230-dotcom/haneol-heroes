class_name AttackTokens
extends RefCounted
## 공격권 (Doom 2016식): 동시에 덤비는 근접 적 수를 제한한다. 나머지는 둘레에서 맴돈다 (순수 로직).

static var _holders: Dictionary = {}


## 공격권 받기. 이미 가졌으면 true, 자리가 있으면 받고 true.
static func request(id: int, max_tokens: int) -> bool:
	if _holders.has(id):
		return true
	if _holders.size() >= max_tokens:
		return false
	_holders[id] = true
	return true


static func release(id: int) -> void:
	_holders.erase(id)


static func has(id: int) -> bool:
	return _holders.has(id)


static func count() -> int:
	return _holders.size()


static func clear() -> void:
	_holders.clear()
