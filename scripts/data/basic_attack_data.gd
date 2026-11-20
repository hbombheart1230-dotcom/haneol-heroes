class_name BasicAttackData
extends Resource
## 자동 기본 공격 수치 (근접 부채꼴 + 원거리 투사체).

@export_group("근접")
@export var melee_interval: float = 0.55
@export var melee_range: float = 110.0
@export var melee_arc_degrees: float = 140.0
@export var melee_damage: int = 12
## 근접 적중 시 적을 밀어내는 힘 (피격 반응).
@export var melee_knockback: float = 140.0
## 근접 적중 시 플레이어가 반대로 살짝 밀리는 거리(px). 칼이 닿은 반동 (Hollow Knight식).
@export var melee_recoil: float = 0.0

@export_group("원거리")
@export var ranged_interval: float = 0.8
@export var ranged_range: float = 480.0
@export var ranged_damage: int = 10
@export var ranged_speed: float = 700.0
@export var ranged_lifetime: float = 0.8
## 원거리 적중 시 넉백 (근접의 절반 정도).
@export var ranged_knockback: float = 0.0
## 비어 있지 않으면 원거리 투사체를 이 글자들로 차례로 그린다 (세종 문자탄).
@export var ranged_glyphs: String = ""
