class_name RunProgress
extends RefCounted
## 한 판의 성장 진행 (순수 로직): 경험치, 레벨, 대기 중인 레벨업, 고른 성장 횟수.

signal leveled_up(level: int)

var config: RunConfig
var level: int = 1
var xp: int = 0
## 아직 선택하지 않은 레벨업 수.
var pending: int = 0
## UpgradeDef.id → 고른 횟수.
var stacks: Dictionary = {}


func _init(p_config: RunConfig = null) -> void:
	config = p_config if p_config else RunConfig.new()


func xp_to_next() -> int:
	return maxi(config.xp_base + config.xp_growth * (level - 1), 1)


func xp_ratio() -> float:
	return clampf(float(xp) / float(xp_to_next()), 0.0, 1.0)


## 경험치를 얻고, 오른 레벨 수를 돌려준다.
func add_xp(amount: int) -> int:
	if amount <= 0:
		return 0
	xp += amount
	var gained := 0
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		pending += 1
		gained += 1
		leveled_up.emit(level)
	return gained


func record_choice(u: UpgradeDef) -> void:
	stacks[u.id] = int(stacks.get(u.id, 0)) + 1
	pending = maxi(pending - 1, 0)
