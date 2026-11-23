class_name EnemyPoise
extends RefCounted
## 무게 등급 규칙 (B3, 순수 로직). 수치는 EnemyAIData("무게 등급").
## 잡몹: 넉백 그대로 (경직은 HitReaction). 정예: 갑옷이 있는 동안 넉백 면역 → 갑옷이 깨지면 기절, 얼마 뒤 갑옷이 다시 찬다.
## 보스: 넉백 면역, 받은 피해가 경직 게이지를 채우면 짧게 휘청 (한 번 휘청일 때마다 게이지가 커진다, Diablo IV식).

enum Event { NONE, ARMOR_BREAK, STAGGER }

var tier: HitReaction.Tier
var ai: EnemyAIData
var armor_max: float = 0.0
var armor: float = 0.0
## 갑옷이 깨진 뒤 다시 찰 때까지 남은 시간(초).
var regen_left: float = 0.0
var gauge_max: float = 0.0
var gauge: float = 0.0
var staggers: int = 0
## 휘청하지 않는 남은 시간(초, 격노 단계 BossPhaseData.stagger_immune).
var immune_left: float = 0.0


func _init(p_tier: HitReaction.Tier, max_hp: int, p_ai: EnemyAIData) -> void:
	tier = p_tier
	ai = p_ai if p_ai else EnemyAIData.new()
	if tier == HitReaction.Tier.ELITE and ai.elite_armor_frac > 0.0:
		armor_max = maxf(max_hp * ai.elite_armor_frac, 1.0)
		armor = armor_max
	elif tier == HitReaction.Tier.BOSS and ai.boss_stagger_frac > 0.0:
		gauge_max = maxf(max_hp * ai.boss_stagger_frac, 1.0)


## 받은 피해 (배율 적용 뒤). 갑옷이 깨지거나 보스가 휘청이면 그 사건.
func on_damage(applied: int) -> Event:
	if applied <= 0:
		return Event.NONE
	if armor_max > 0.0 and armor > 0.0:
		armor = maxf(armor - applied, 0.0)
		if armor <= 0.0:
			regen_left = ai.armor_regen_delay
			return Event.ARMOR_BREAK
	elif gauge_max > 0.0 and immune_left <= 0.0:
		gauge += applied
		if gauge >= gauge_max:
			gauge = 0.0
			staggers += 1
			gauge_max *= ai.boss_stagger_growth
			return Event.STAGGER
	return Event.NONE


func tick(delta: float) -> void:
	immune_left = maxf(immune_left - delta, 0.0)
	if armor_max > 0.0 and armor <= 0.0:
		regen_left = maxf(regen_left - delta, 0.0)
		if regen_left <= 0.0:
			armor = armor_max


## 넉백 배율 (적 종류의 knockback_scale에 곱한다).
func knockback_mult() -> float:
	if tier == HitReaction.Tier.BOSS:
		return 0.0
	if armor_max > 0.0 and armor > 0.0:
		return 0.0
	return 1.0


func is_armored() -> bool:
	return armor_max > 0.0 and armor > 0.0


## 머리 위 막대 비율 (갑옷 남은 양 또는 경직 게이지). 막대가 없으면 -1.
func bar_ratio() -> float:
	if armor_max > 0.0:
		return armor / armor_max
	if gauge_max > 0.0:
		return gauge / gauge_max
	return -1.0
