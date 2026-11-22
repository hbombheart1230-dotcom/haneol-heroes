class_name WaveSetData
extends Resource
## 무대 하나의 물결 구성 (StageTheme.waves). 물결을 다 깨면 보스.

@export var waves: Array[WaveData] = []
## 화면에 동시에 있는 적 최대 (예고 중인 자리 포함). 난이도 단계만큼 더해진다.
@export var max_alive: int = 8
## 살아 있는 적이 이 수 이하가 되면 남은 적이 이어서 나온다.
@export var next_when_left: int = 2
## 등장: 영웅에게서 이 거리(px, 화면 안)에 먹 번짐 예고를 warn_time초 보인 뒤 나타난다. 예고끼리 간격(초).
@export var spawn_min: float = 260.0
@export var spawn_max: float = 420.0
@export var warn_time: float = 0.6
@export var spawn_stagger: float = 0.12
## 물결 사이 숨 고르기(초, 강화 고르기가 끝난 뒤부터)와 마지막 물결 뒤 보스까지(초).
@export var gap_time: float = 1.2
@export var boss_delay: float = 1.5
## 처치 경험치 배율 (적이 적은 만큼, 강화 횟수가 지금과 비슷하게).
@export var xp_mult: float = 3.5
