class_name InkBurstData
extends Resource
## 먹물 방울·죽음 모양(연기·종이)·먹 자국·금빛 고리 수치. CombatFeelData.burst로 쓴다.

@export_group("먹물 방울")
## 퍼지는 각도(라디안, 한쪽)와 속도 범위(px/s).
@export var drop_spread: float = 0.9
@export var drop_speed: Vector2 = Vector2(120.0, 320.0)
## 수명 범위(초)와 반지름 범위(px).
@export var drop_life: Vector2 = Vector2(0.3, 0.5)
@export var drop_radius: Vector2 = Vector2(3.0, 6.5)
## 초당 감속 비율과 몸 중심 높이 보정(px).
@export var drop_damping: float = 7.0
@export var drop_lift: float = 16.0
@export var drop_alpha: float = 0.85
## 수명 끝에서 방울이 줄어드는 비율.
@export var drop_shrink: float = 0.5

@export_group("먹 자국")
@export var mark_radius: float = 26.0
@export var mark_radius_finisher: float = 48.0
@export var mark_alpha: float = 0.45

@export_group("죽음 모양")
## 조각이 생기는 자리 흩어짐 (x: 좌우 ±, y: 위로 0~y px).
@export var spawn_jitter: Vector2 = Vector2(16.0, 30.0)
## 날아가는 시체가 끝에서 옅어지는 정도와 그림자 반지름(px).
@export var corpse_fade: float = 0.4
@export var corpse_shadow: float = 18.0
## 정예·보스는 조각·방울 수가 이 배수.
@export var finisher_scale: int = 2
@export var paper_count: int = 6
@export var paper_speed_x: float = 160.0
## 위로 튀는 속도 범위(px/s, 음수 = 위).
@export var paper_speed_y: Vector2 = Vector2(-220.0, -80.0)
@export var paper_life: Vector2 = Vector2(0.5, 0.8)
@export var paper_size: Vector2 = Vector2(6.0, 11.0)
@export var paper_spin: float = 9.0
@export var paper_gravity: float = 520.0
@export var smoke_color: Color = Color(0.35, 0.55, 0.85)
@export var smoke_count: int = 5
@export var smoke_drift_x: float = 40.0
@export var smoke_rise: Vector2 = Vector2(-90.0, -40.0)
@export var smoke_life: Vector2 = Vector2(0.45, 0.7)
@export var smoke_size: Vector2 = Vector2(10.0, 18.0)
## 연기가 커지는 배율(수명 끝에서 1 + grow)과 투명도.
@export var smoke_grow: float = 1.2
@export var smoke_alpha: float = 0.5
## 정예·보스 금빛 고리.
@export var ring_time: float = 0.5
@export var ring_radius: float = 140.0
## 고리가 처음 크기(배율)에서 커지고, 두께는 ring_width → ring_width_min으로 가늘어진다.
@export var ring_start_scale: float = 0.3
@export var ring_width: float = 12.0
@export var ring_width_min: float = 2.0
## 종이 조각 테두리 먹선 투명도와 두께(px).
@export var paper_edge_alpha: float = 0.7
@export var paper_edge_width: float = 1.5
