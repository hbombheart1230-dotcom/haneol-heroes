class_name BreakableData
extends Resource
## 무대에 놓이는 부서지는 물건 (옹기·술통·수박...) 과 거기서 나오는 탕약. 수치는 여기서만 바꾼다.

@export var texture: Texture2D
## 화면에 그릴 높이(px). 폭은 그림 비율대로.
@export var display_height: float = 96.0
## 대시·공격이 닿는 반지름.
@export var radius: float = 44.0
## 한 번에 지도에 놓이는 개수, 깨진 뒤 다른 곳에 다시 생기기까지(초).
@export var count: int = 3
@export var respawn_time: float = 25.0
## 서로·시작 지점에서 떨어뜨릴 거리.
@export var min_gap: float = 420.0
@export var clear_radius: float = 260.0

@export_group("탕약")
## 깨졌을 때 탕약이 나올 확률 (0~1).
@export_range(0.0, 1.0) var drop_chance: float = 0.6
## 최대 체력 대비 회복 비율.
@export_range(0.0, 1.0) var heal_fraction: float = 0.25
## 이만큼 가까이 가면 마신다(px). 바닥에 남아 있는 시간(초).
@export var pickup_radius: float = 48.0
@export var potion_lifetime: float = 20.0
