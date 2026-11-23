class_name EvadeRimData
extends Resource
## 회피 성공 무적 (Player.evade_invuln_time) 동안 영웅 몸 둘레 옅은 금빛 테두리 (EvadeRim): 남은 시간이 줄수록 옅어진다.
## 피격 후 무적(붉은 깜빡임)과 구분되게 금색·몸 밖 테두리만. 네 영웅 공통.

const PATH := "res://data/feel/evade_rim.tres"

@export var color: Color = Color(1.0, 0.82, 0.35, 0.9)
## 무적 동안 몸 전체 색 (예전 진한 금빛 Color(1, 0.9, 0.55)이 테두리를 덮어 옅게).
@export var body_tint: Color = Color(1.0, 0.96, 0.86)
## 테두리 두께(px, 화면): 실루엣을 둘레 8방향으로 이만큼 밀어 그린다.
@export var width_px: float = 3.0
## 남은 시간 비율에 곱하는 곡선 지수 (1 = 고르게 옅어짐, 크면 끝에서 빨리).
@export var fade_power: float = 1.0
## 끝나기 직전 깜빡여 알림: 남은 시간이 이 아래면 (초) blink_hz로 깜빡 (0이면 없음).
@export var blink_below: float = 0.25
@export var blink_hz: float = 12.0
