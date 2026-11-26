class_name ZoneHopFeel
extends Resource
## 구역 건너뛰기 연출 값 (ZoneHop). 비면 이 기본값.

## 화살 방향과 내닫은 방향이 이 각도(도) 안이면 넘어간다.
@export var dash_angle: float = 50.0
## 화살이 영웅에게서 떨어진 거리(px)와 깜박임 빠르기(초당).
@export var arrow_dist: float = 260.0
@export var arrow_pulse: float = 2.2
## 꺾쇠 한 겹 크기(px)와 안내 글 크기(px).
@export var arrow_size: float = 58.0
@export var text_px: int = 44
## 뛰어오름: 내닫기가 끝난 뒤 하늘로 오르는 시간(초)·앞으로 가는 거리(px)·높이(px).
@export var rise_time: float = 0.42
@export var rise_dist: float = 260.0
@export var rise_height: float = 220.0
## 먹 덮기가 다 덮인 채로 머무는 시간(초) — 이 사이에 구역을 바꾼다.
@export var cover_time: float = 0.25
## 내려앉기: 시간(초)·뒤에서 날아오는 거리(px)·높이(px).
@export var land_time: float = 0.38
@export var land_dist: float = 220.0
@export var land_height: float = 200.0
## 구역 이름을 띄우는 시간(초).
@export var title_time: float = 1.6
## 먹 덮기 색.
@export var cover_color: Color = Color(0.06, 0.05, 0.05, 1.0)
