class_name RunConfig
extends Resource
## 한 판(런)의 진행 규칙: 경험치 곡선, 선택지 수, 보스 등장 시각, 난이도 상승.

## 다음 레벨까지 필요 경험치 = xp_base + xp_growth × (현재 레벨 - 1).
@export var xp_base: int = 5
@export var xp_growth: int = 4
@export var choice_count: int = 3
## 보스 등장 시각(초). 보스를 쓰러뜨리면 승리.
@export var boss_time: float = 150.0
## 적 생성 간격이 최소가 되기까지(초).
@export var ramp_time: float = 120.0
## 0보다 크면 이 시간을 버티면 승리 (P0 방식). 0이면 보스 처치만 승리.
@export var survive_time: float = 0.0
## 정예 등장 시각(초). 처치하면 큰 변형(금빛 인장)을 고른다.
@export var elite_times: PackedFloat32Array = PackedFloat32Array([60.0, 110.0])
## 판 안 레벨 곡선·카드 규칙. 비우면 옛 곡선(xp_base·xp_growth), 레벨업 효과 없음.
@export var levels: LevelRules
## 처치 외 점수(연타 마무리·회피·반격·충전)와 상한. 비우면 처치 점수만.
@export var score: ScoreTable
## 무대 (바닥·소품·시작 문구). docs/scenario.md 3.2의 연표.
@export var stage: StageTheme
