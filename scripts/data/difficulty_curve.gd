class_name DifficultyCurve
extends Resource
## 난이도 곡선 (data/difficulty/curve.tres): 영웅이 무대 순서에서 몇 번째 전장인지(단계)에 따라 적을 강하게.
## 단계 0 = 그 영웅의 첫 전장. 영웅도 깬 전장마다 오르므로 (HeroGrowth +8%) 적은 그보다 조금 더 오른다 ('나' 안, 2026-11-24). 표의 끝을 넘으면 (한 바퀴 돈 뒤) per_loop만큼 계속 오른다.

@export var hp_mult: PackedFloat32Array = PackedFloat32Array([1.0, 1.11, 1.22, 1.33])
@export var damage_mult: PackedFloat32Array = PackedFloat32Array([1.0, 1.1, 1.2, 1.3])
@export var speed_mult: PackedFloat32Array = PackedFloat32Array([1.0, 1.02, 1.04, 1.06])
## 적이 나오는 간격 배율 (작을수록 자주).
@export var interval_mult: PackedFloat32Array = PackedFloat32Array([1.0, 0.97, 0.94, 0.91])
@export var max_alive_add: PackedInt32Array = PackedInt32Array([0, 2, 4, 6])
## 표 끝 다음 단계마다 더하는 양.
@export var per_loop_hp: float = 0.11
@export var per_loop_damage: float = 0.1
@export var per_loop_speed: float = 0.02
@export var per_loop_interval: float = -0.03
@export var per_loop_alive: int = 2
@export var min_interval_mult: float = 0.6
@export var max_speed_mult: float = 1.15
## 체력·공격·동시에 있는 적 상한 (지금 전장 수 12 안에서는 닿지 않는다: 단계 12 = 체력 ×2.32, 공격 ×2.2, +24).
@export var max_hp_mult: float = 3.0
@export var max_damage_mult: float = 3.0
@export var max_alive_cap: int = 30


static func _at(table: PackedFloat32Array, tier: int, per_loop: float) -> float:
	if table.is_empty():
		return 1.0
	var t := maxi(tier, 0)
	if t < table.size():
		return table[t]
	return table[table.size() - 1] + per_loop * (t - table.size() + 1)


func hp(tier: int) -> float:
	return minf(_at(hp_mult, tier, per_loop_hp), max_hp_mult)


func damage(tier: int) -> float:
	return minf(_at(damage_mult, tier, per_loop_damage), max_damage_mult)


func speed(tier: int) -> float:
	return minf(_at(speed_mult, tier, per_loop_speed), max_speed_mult)


func interval(tier: int) -> float:
	return maxf(_at(interval_mult, tier, per_loop_interval), min_interval_mult)


func alive_add(tier: int) -> int:
	if max_alive_add.is_empty():
		return 0
	var t := maxi(tier, 0)
	if t < max_alive_add.size():
		return mini(max_alive_add[t], max_alive_cap)
	return mini(max_alive_add[max_alive_add.size() - 1] + per_loop_alive * (t - max_alive_add.size() + 1), max_alive_cap)


## 적 데이터의 단계 사본 (원본 .tres는 건드리지 않는다). 단계 0이면 원본 그대로.
func scaled(e: EnemyData, tier: int) -> EnemyData:
	if e == null or tier <= 0:
		return e
	var c := e.duplicate() as EnemyData
	c.set_meta(&"hp_base", e.get_meta(&"hp_base", e.max_hp))  # 배율 전 체력 (HomeSummonRules.hp_factor)
	c.max_hp = maxi(1, roundi(e.max_hp * hp(tier)))
	c.contact_damage = roundi(e.contact_damage * damage(tier))
	c.move_speed = e.move_speed * speed(tier)
	if e.attack:
		c.attack = _scaled_attack(e.attack, tier)
	var pats: Array[EnemyAttackData] = []
	for p in e.patterns:
		pats.append(_scaled_attack(p, tier))
	c.patterns = pats
	var phases: Array[BossPhaseData] = []
	for ph in e.phases:  # 보스 단계 공격도 (이어치기까지) 같은 배율로
		var pc := ph.duplicate() as BossPhaseData
		var pp: Array[EnemyAttackData] = []
		for p in ph.patterns:
			pp.append(_scaled_attack(p, tier))
		pc.patterns = pp
		phases.append(pc)
	c.phases = phases
	return c


## 공격 사본 (이어치기 follow_up도 사본으로, 같은 이어치기는 같은 사본: 데이터 비교가 그대로 맞게).
func _scaled_attack(a: EnemyAttackData, tier: int, done: Dictionary = {}) -> EnemyAttackData:
	if a == null:
		return null
	if done.has(a):
		return done[a]
	var c := a.duplicate() as EnemyAttackData
	done[a] = c
	c.damage = roundi(a.damage * damage(tier))
	c.follow_up = _scaled_attack(a.follow_up, tier, done)
	return c
