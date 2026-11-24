class_name EnemyBehaviourData
extends Resource
## 적 종류별 움직임·특수 동작 (군대마다 다른 버릇). EnemyData.behaviour에 붙인다. 없으면 그냥 쫓아온다.

## CHASE = 쫓아옴, HOP = 포물선으로 뛰어오름(방아깨비), AMBUSH = 숨어 있다가 가까이 오면 덮침(사마귀).
enum Style { CHASE, HOP, AMBUSH }

@export var style: Style = Style.CHASE
## 비어 있지 않으면 EnemyData.attack 대신 이 공격을 쓴다 (예: 여진 졸병 = 돌진).
@export var attack: EnemyAttackData
## 보스 패턴 바꾸기 (비어 있으면 EnemyData.patterns 그대로).
@export var patterns: Array[EnemyAttackData] = []
## 공격권(EnemyAIData.max_melee_tokens)을 받아야 다가오는지. false면 늘 바로 덤빈다.
@export var uses_token: bool = true

@export_group("방패 (정면 막기)")
## 0보다 크면 플레이어가 이 각도(도) 앞쪽에 있을 때 받는 피해를 front_guard_mult배로 (왜군 방패 무사).
@export var front_guard_deg: float = 0.0
@export var front_guard_mult: float = 0.3

@export_group("뛰기 (HOP)")
@export var hop_interval: float = 1.6
@export var hop_distance: float = 220.0
@export var hop_time: float = 0.45
@export var hop_height: float = 70.0
## 플레이어 쪽에서 좌우로 비트는 최대 각도(도).
@export var hop_swerve_deg: float = 45.0

@export_group("매복 (AMBUSH)")
## 플레이어가 이 거리 안에 오면 모습을 드러낸다. 그 전에는 흐릿하고 느리게.
@export var ambush_range: float = 260.0
@export var ambush_alpha: float = 0.22
@export var ambush_speed_mult: float = 0.4
