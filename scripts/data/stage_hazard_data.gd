class_name StageHazardData
extends Resource
## 무대 장치 하나의 공통 수치 (연구: docs/research/stage_identity.md). 장치는 중립이다: 적과 영웅을 다 치되 적에게 훨씬 세게
## (하데스 함정은 적에게 20배). 종류마다 이 Resource를 이어받아 make()로 장치 노드를 만든다.
## StageTheme.hazards에 넣는다 (비면 장치 없음 = 예전 그대로).

## 판 시작 뒤 첫 예고까지(초), 예고와 예고 사이(초). 박자는 물결 싸움·우두머리전에만 흐른다
## (숨 고르기·강화 고르기·우두머리 등장 중엔 멈춤, 이미 시작한 예고는 끝까지 간다).
@export var first_delay: float = 6.0
@export var period: float = 12.0
## 우두머리전에서 간격 배율 (1.6 = 12초 → 19.2초). 0이면 우두머리전에는 쉰다.
@export var boss_period_mult: float = 1.6
## 예고 길이(초): 이만큼 앞서 바닥에 모양을 보이고 소리로 알린다.
@export var warn_time: float = 1.2
## 한 번 맞을 때 피해: 적 / 영웅 (영웅은 대시·피격 무적이면 안 맞는다).
@export var enemy_damage: int = 60
@export var hero_damage: int = 10


## 장치 노드 (종류마다 덮어쓴다). null이면 만들지 않는다.
func make() -> Node2D:
	return null
