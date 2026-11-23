class_name ComboLockData
extends Resource
## 연타 중 처음 때린 몹에 붙기 (사용자: "연타 중 처음 때린 몹에 붙기를 봐야 확정할 수 있을 것 같아"): 1타가 맞힌 몹을 연타 대상으로
## 잡고, 연타가 이어지는 동안 방향·전진·검기·넷째 탭 마무리 방향을 그 몹에 맞춘다 (타마다 가장 가까운 몹을 다시 찾지 않음).
## 칼이 닿는 순간 대상 쪽으로 살짝 끌려 붙는다 (몸을 뚫지 않게, 이동은 충돌을 따른다). HeroData.combo_lock (비면 꺼짐).

@export var enabled: bool = true
## 대상이 (그 타의 사거리 + 이 값) 밖으로 나가면 풀고 평소대로 가장 가까운 몹 (px).
@export var keep_slack: float = 50.0
## 붙기: 닿는 순간 대상과의 몸 사이 틈을 이만큼까지 줄인다 (px), 한 타에 끌려가는 상한 (px)과 걸리는 시간 (초).
@export var ideal_gap: float = 12.0
@export var pull_max: float = 24.0
@export var pull_time: float = 0.1
## 이동 입력이 이 크기(0~1) 이상이면 바로 풀림 (플레이어 입력 우선). 대시도 바로 풀림.
@export var release_input: float = 0.35
