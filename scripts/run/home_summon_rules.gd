class_name HomeSummonRules
extends RefCounted
## 주인 영웅 부르기 규칙 (순수 로직, 화면·노드 없음): 누가 주인인지, 남은 횟수, 피해 배율.

var data: HomeSummonData
## 이 판에 부를 주인 영웅 (자기 전장이거나 주인이 없으면 null → 단추 없음).
var home: HeroData
var entry: HomeSummonEntry
var charges: int = 0
var used: int = 0
var _boss_given := false


func _init(p_data: HomeSummonData = null) -> void:
	data = p_data if p_data else HomeSummonData.get_default()


## 판 시작: 이 전장의 주인 영웅을 찾고 첫 횟수를 준다. 부를 수 있으면 true.
func begin(heroes: Array, player_hero: HeroData, stage_id: StringName) -> bool:
	home = home_hero(heroes, player_hero, stage_id)
	entry = data.entry_for(home.id) if home else null
	if not data.enabled or entry == null or skill() == null:
		home = null
		entry = null
	charges = mini(data.charges_start, data.charges_max) if home else 0
	used = 0
	_boss_given = false
	return home != null


func active() -> bool:
	return home != null


## 우두머리가 나왔다: 한 번만 횟수를 더한다 (최대까지). 더했으면 true.
func on_boss() -> bool:
	if home == null or _boss_given:
		return false
	_boss_given = true
	var before := charges
	charges = mini(charges + data.charges_boss, data.charges_max)
	return charges > before


func can_use() -> bool:
	return home != null and charges > 0


## 한 번 쓴다. 쓸 수 있었으면 true.
func use() -> bool:
	if not can_use():
		return false
	charges -= 1
	used += 1
	return true


## 주인 영웅이 쓸 기술 (entry.slot 칸).
func skill() -> SkillDef:
	if home == null or home.kit == null or entry == null:
		return null
	match entry.slot:
		1:
			return home.kit.tap
		2:
			return home.kit.dash
		4:
			return home.kit.counter
	return home.kit.charge


## 이번에 쓸 피해 배율: 데이터 배율 × 이 판 우두머리 체력이 원래보다 늘어난 만큼 ÷ 고른 영웅의 성장 피해 배율
## (적이 받는 피해에 HeroGrowth.run_damage_mult가 곱해진다: 주인 영웅의 도움은 고른 영웅이 자란 만큼 커지지 않는다).
func damage_scale(scaled_boss: EnemyData, base_boss: EnemyData, growth_mult: float = HeroGrowth.run_damage_mult) -> float:
	return (entry.damage_scale if entry else 1.0) * boss_factor(scaled_boss, base_boss) / maxf(growth_mult, 0.01)


## 겨눈 적의 체력 배율로 (독립 검토: 중간 우두머리·졸병에도 최종 우두머리 배율을 썼다): 그 적 데이터의 체력 /
## 배율을 입히기 전 체력 (BossHpScale·DifficultyCurve가 사본에 hp_base로 남긴다, 없으면 1).
func damage_scale_for(target: EnemyData, growth_mult: float = HeroGrowth.run_damage_mult) -> float:
	return (entry.damage_scale if entry else 1.0) * hp_factor(target) / maxf(growth_mult, 0.01)


static func hp_factor(d: EnemyData) -> float:
	if d == null or d.max_hp <= 0:
		return 1.0
	return float(d.max_hp) / maxf(float(d.get_meta(&"hp_base", d.max_hp)), 1.0)


## 이 판 우두머리(영웅 배율·난이도가 곱해진 사본) 체력 / 무대 원래 우두머리 체력. 없으면 1.
static func boss_factor(scaled_boss: EnemyData, base_boss: EnemyData) -> float:
	if scaled_boss == null or base_boss == null or base_boss.max_hp <= 0:
		return 1.0
	return float(scaled_boss.max_hp) / float(base_boss.max_hp)


## 이 전장의 주인 영웅: 전장 목록(campaign)에 이 전장이 있는 영웅. 고른 영웅 자신이면(자기 전장) null.
static func home_hero(heroes: Array, player_hero: HeroData, stage_id: StringName) -> HeroData:
	if player_hero and player_hero.campaign and player_hero.campaign.has(stage_id):
		return null
	for h in heroes:
		var hd := h as HeroData
		if hd and hd != player_hero and (player_hero == null or hd.id != player_hero.id) and hd.campaign \
				and hd.campaign.has(stage_id):
			return hd
	return null
