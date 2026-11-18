class_name EnemyData
extends Resource
## 적 한 종류의 데이터. 새 적 = 새 .tres (+ 행동이 다르면 전용 스크립트).

@export var id: StringName = &""
@export var max_hp: int = 30
@export var move_speed: float = 120.0
## 플레이어 접촉 시 피해량.
@export var contact_damage: int = 10
@export var body_radius: float = 20.0
@export var color: Color = Color(0.75, 0.2, 0.25)
## 예고 공격 (없으면 접촉 피해만).
@export var attack: EnemyAttackData
