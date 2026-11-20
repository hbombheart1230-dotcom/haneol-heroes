class_name EliteAffixData
extends Resource
## 정예 변종 (철갑·질풍·분열 등). 정예가 나올 때 EnemyAIData.elite_affixes에서 하나 붙는다.

@export var id: StringName = &""
## 머리 위에 띄우는 이름.
@export var label: String = ""
## 테두리 색 (변종마다 다르게 보이게).
@export var rim_color: Color = Color(1, 0.8, 0.2, 1)
@export var rim_width_add: float = 1.0
@export var hp_mult: float = 1.0
@export var speed_mult: float = 1.0
## 받는 피해 배율 (철갑 < 1).
@export var damage_taken_mult: float = 1.0
## 죽으면 이만큼 작은 적으로 갈라진다 (분열). 갈라진 적의 체력·크기 배율.
@export var split_count: int = 0
@export var split_hp_mult: float = 0.3
@export var split_scale: float = 0.7
