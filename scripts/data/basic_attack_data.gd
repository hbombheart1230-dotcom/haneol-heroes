class_name BasicAttackData
extends Resource
## 자동 기본 공격 수치 (근접 부채꼴 + 원거리 투사체).

@export_group("근접")
@export var melee_interval: float = 0.55
@export var melee_range: float = 110.0
@export var melee_arc_degrees: float = 140.0
@export var melee_damage: int = 12

@export_group("원거리")
@export var ranged_interval: float = 0.8
@export var ranged_range: float = 480.0
@export var ranged_damage: int = 10
@export var ranged_speed: float = 700.0
@export var ranged_lifetime: float = 0.8
