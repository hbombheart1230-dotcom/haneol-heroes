class_name HeroData
extends Resource
## 영웅 하나의 데이터: 능력치, 대시, 기본 공격, 단일 버튼 기술 구성.
## 새 영웅 = 새 .tres + 영웅 전용 SkillDef 스크립트.

@export var id: StringName = &""
@export var display_name: String = ""
@export var body_color: Color = Color(0.15, 0.4, 0.8)

@export_group("능력치")
@export var max_hp: int = 100
@export var move_speed: float = 340.0
## 피격 후 무적 시간(초).
@export var hurt_invuln_time: float = 0.6
## 회피 성공(예고 원을 대시로 벗어남) 즉시 무적 시간(초).
@export var evade_invuln_time: float = 1.0

@export_group("대시")
@export var dash_distance: float = 260.0
@export var dash_duration: float = 0.16
@export var max_dash_charges: int = 2
@export var dash_recharge_time: float = 1.2

@export_group("전투")
@export var attack: BasicAttackData
@export var kit: SkillKit
