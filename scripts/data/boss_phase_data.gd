class_name BossPhaseData
extends Resource
## 보스 단계 하나 (EnemyData.phases): 체력이 hp_frac 아래로 내려가면 공격 목록을 바꾸고 부하를 부른다.

@export var hp_frac: float = 0.66
## 이 단계의 공격 순환 (비면 그대로). cooldown_mult로 쿨타임을 줄인다 (주기 단축).
@export var patterns: Array[EnemyAttackData] = []
@export var cooldown_mult: float = 1.0
## 부를 부하 (먹 번짐 예고 뒤 등장).
@export var summon: Array[EnemyData] = []
## 단계가 바뀌는 순간 잠깐 무적(초)과 낙인 그림 (비면 글자만).
@export var invuln_time: float = 1.0
@export var seal_art: Texture2D
@export var seal_label: String = "진격!"
## 이 단계에 들어가면 경직(휘청) 게이지 최대를 이 배로 (성장한 영웅이 보스를 자주 휘청에 묶지 않게).
@export var stagger_gauge_mult: float = 1.0
## 이 단계에 들어간 뒤 이 시간(초) 동안 휘청하지 않는다 (격노).
@export var stagger_immune: float = 0.0
