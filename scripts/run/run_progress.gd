class_name RunProgress
extends RefCounted
## 한 판의 성장 진행 (순수 로직): 점수(경험치), 레벨, 적립된 카드, 고른 성장 횟수. 저장하지 않는다 (판마다 1부터).

signal leveled_up(level: int)
## 점수가 들어옴 (kind: &"kill" | &"combo" | &"evade" | &"counter" | &"charge"): HUD 작은 반응.
signal scored(kind: StringName, amount: int)

var config: RunConfig
var level: int = 1
var xp: int = 0
## 적립된 카드 (레벨업마다 1장, 숨 고르기에서 고른다).
var pending: int = 0
## UpgradeDef.id → 고른 횟수.
var stacks: Dictionary = {}
## 이번 판에 얻은 점수 합 (기록·시뮬용).
var total: int = 0


func _init(p_config: RunConfig = null) -> void:
	config = p_config if p_config else RunConfig.new()


func rules() -> LevelRules:
	return config.levels


func xp_to_next() -> int:
	if config.levels:
		return config.levels.need(level)
	return maxi(config.xp_base + config.xp_growth * (level - 1), 1)


func xp_ratio() -> float:
	return clampf(float(xp) / float(xp_to_next()), 0.0, 1.0)


## 레벨에 따른 기술 모습 단계 보너스.
func vfx_bonus() -> int:
	return config.levels.vfx_bonus(level) if config.levels else 0


## 경험치를 얻고, 오른 레벨 수를 돌려준다.
func add_xp(amount: int, kind: StringName = &"kill") -> int:
	if amount <= 0:
		return 0
	xp += amount
	total += amount
	scored.emit(kind, amount)
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
