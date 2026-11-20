class_name DifficultyCurve
extends Resource
## 난이도 곡선 (data/difficulty/curve.tres): 영웅이 무대 순서에서 몇 번째 전장인지(단계)에 따라 적을 강하게.
## 단계 0 = 그 영웅의 첫 전장. 표의 끝을 넘으면 (한 바퀴 돈 뒤) per_loop만큼 계속 오른다.

@export var hp_mult: PackedFloat32Array = PackedFloat32Array([1.0, 1.35, 1.75, 2.2])
@export var damage_mult: PackedFloat32Array = PackedFloat32Array([1.0, 1.15, 1.3, 1.45])
@export var speed_mult: PackedFloat32Array = PackedFloat32Array([1.0, 1.04, 1.08, 1.12])
## 적이 나오는 간격 배율 (작을수록 자주).
@export var interval_mult: PackedFloat32Array = PackedFloat32Array([1.0, 0.9, 0.8, 0.72])
@export var max_alive_add: PackedInt32Array = PackedInt32Array([0, 4, 8, 12])
## 표 끝 다음 단계마다 더하는 양.
@export var per_loop_hp: float = 0.45
@export var per_loop_damage: float = 0.15
@export var per_loop_speed: float = 0.03
@export var per_loop_interval: float = -0.05
@export var per_loop_alive: int = 3
@export var min_interval_mult: float = 0.45
@export var max_speed_mult: float = 1.3


static func _at(table: PackedFloat32Array, tier: int, per_loop: float) -> float:
	if table.is_empty():
		return 1.0
	var t := maxi(tier, 0)
	if t < table.size():
		return table[t]
	return table[table.size() - 1] + per_loop * (t - table.size() + 1)


func hp(tier: int) -> float:
	return _at(hp_mult, tier, per_loop_hp)


func damage(tier: int) -> float:
	return _at(damage_mult, tier, per_loop_damage)


func speed(tier: int) -> float:
	return minf(_at(speed_mult, tier, per_loop_speed), max_speed_mult)


func interval(tier: int) -> float:
	return maxf(_at(interval_mult, tier, per_loop_interval), min_interval_mult)


func alive_add(tier: int) -> int:
	if max_alive_add.is_empty():
		return 0
	var t := maxi(tier, 0)
	if t < max_alive_add.size():
		return max_alive_add[t]
	return max_alive_add[max_alive_add.size() - 1] + per_loop_alive * (t - max_alive_add.size() + 1)


## 적 데이터의 단계 사본 (원본 .tres는 건드리지 않는다). 단계 0이면 원본 그대로.
func scaled(e: EnemyData, tier: int) -> EnemyData:
	if e == null or tier <= 0:
		return e
	var c := e.duplicate() as EnemyData
	c.max_hp = maxi(1, roundi(e.max_hp * hp(tier)))
	c.contact_damage = roundi(e.contact_damage * damage(tier))
	c.move_speed = e.move_speed * speed(tier)
	if e.attack:
		c.attack = _scaled_attack(e.attack, tier)
	var pats: Array[EnemyAttackData] = []
	for p in e.patterns:
		pats.append(_scaled_attack(p, tier))
	c.patterns = pats
	return c


func _scaled_attack(a: EnemyAttackData, tier: int) -> EnemyAttackData:
	if a == null:
		return null
	var c := a.duplicate() as EnemyAttackData
	c.damage = roundi(a.damage * damage(tier))
	return c
