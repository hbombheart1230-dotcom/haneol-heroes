class_name EnemyAttackData
extends Resource
## 적의 예고 공격 수치.
##   SLAM  : 예고 원(플레이어 위치 고정) → 내려찍기
##   SHOOT : 조준선(플레이어 방향 고정) → 화살 발사 (원거리)
##   SHOCKWAVE : 자기 주변 원 → 충격파
##   CONE  : 플레이어 방향 부채꼴 → 베기
##   CHARGE: 플레이어 방향 직사각형 → 그 끝까지 돌진

enum Kind { SLAM, SHOOT, SHOCKWAVE, CONE, CHARGE }

@export var kind: Kind = Kind.SLAM
## 예고·공격 중 보여 줄 스프라이트 동작 (시트에 없으면 "attack"). 보스 패턴마다 다르게.
@export var anim: StringName = &"attack"

## 플레이어가 이 거리(px) 안에 오면 공격을 시작한다.
@export var trigger_range: float = 130.0
## 예고 시간(초). 이 동안 바닥에 붉은 원이 차오른다.
@export var windup: float = 0.6
## 타격 원 반지름(px). 부채꼴(CONE)은 길이로 쓴다.
@export var radius: float = 80.0
## 부채꼴 각도(도).
@export var angle_degrees: float = 100.0
## 돌진(CHARGE) 직사각형 길이·폭(px).
@export var length: float = 420.0
@export var width: float = 100.0
## 동시 예고 수 제한을 받지 않음 (보스).
@export var bypass_cap: bool = false
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
