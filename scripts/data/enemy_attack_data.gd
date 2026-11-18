class_name EnemyAttackData
extends Resource
## 적의 예고 공격 수치.
##   SLAM  : 예고 원(플레이어 위치 고정) → 내려찍기
##   SHOOT : 조준선(플레이어 방향 고정) → 화살 발사 (원거리)

enum Kind { SLAM, SHOOT }

@export var kind: Kind = Kind.SLAM

## 플레이어가 이 거리(px) 안에 오면 공격을 시작한다.
@export var trigger_range: float = 130.0
## 예고 시간(초). 이 동안 바닥에 붉은 원이 차오른다.
@export var windup: float = 0.6
## 타격 원 반지름(px).
@export var radius: float = 80.0
@export var damage: int = 20
## 타격 후 다음 공격까지(초).
@export var cooldown: float = 2.5
## 타격 후 경직(초). 이 동안 움직이지 않는다.
@export var recovery: float = 0.3

@export_group("사격 (SHOOT)")
@export var projectile_speed: float = 520.0
@export var projectile_range: float = 650.0
## 화살 판정 반지름(px).
@export var projectile_radius: float = 14.0
