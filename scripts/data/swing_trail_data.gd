class_name SwingTrailData
extends Resource
## 평타 검기 궤적 (SwingTrail): 칼이 지나간 자리를 따라 그려지는 붓 획 띠. 수치는 data/feel/swing_trail.tres.
## 부채꼴(판정)과 같은 각도·사거리를 휩쓴다: 모양은 BasicAttackData(step_arc_mults·step_trail_flip·step_range_mults).

## 궤적을 쓰는 영웅 (HeroData.id). 없는 영웅은 예전 초승달 (SwingCrescent).
@export var heroes: PackedStringArray = PackedStringArray(["yi_sun_sin"])
## 띠 그림 (무채색, 세로 0 = 칼끝 가장자리 → 1 안쪽 마른 붓 결). tools/vfx/make_trail_band.py.
@export var band: Texture2D
## 휘두르는 방향 = step_trail_flip × sweep_sign (1 = 화면 시계 방향). 순신 굽기의 무기 끝 기록을 방향 8개로 재면
## attack 반시계 6/8, attack2 시계 6/8, attack3 반시계 5/8 → step_trail_flip [1, -1, 1]과 반대라 -1.
@export var sweep_sign: float = -1.0
## 칼이 닿는 순간(맞닿는 프레임) 앞뒤로 휘두르는 시간 (초). 닿는 순간 머리가 부채꼴 가운데를 조금 지난다.
@export var lead: float = 0.1
@export var follow: float = 0.06
## 꼬리 길이 (초): 머리가 지나간 뒤 이만큼 남았다 사라진다. 빠른 구간일수록 띠가 길다.
@export var life: float = 0.12
## 띠 바깥 반지름 = 사거리 × reach. 굵기(px)는 머리에서 가장 굵고 꼬리로 갈수록 가늘다.
@export var reach: float = 1.0
@export var width: float = 48.0
@export var step_widths: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 1.5])
## 꼬리 굵기 곡선 (1 = 일정하게 가늘어짐, 클수록 머리 쪽만 굵다).
@export var taper: float = 1.3
## 원 중심을 발이 아닌 가슴 높이로 (px).
@export var center_offset: Vector2 = Vector2(0, -26)
## 쿼터뷰라 원을 세로로 조금 눌러 그린다.
@export var squash: float = 0.85
## 띠 마디 수 (고정, 매 프레임 새 배열 없음).
@export var segments: int = 14
## 영웅색을 흰빛 쪽으로 섞는 비율 (어두운 바닥에서 보이게), 먹 외곽선 진하기·두께, 밝은 심 (바깥쪽 가장자리를 따라 가늘게).
@export var lighten: float = 0.45
@export var ink_alpha: float = 0.85
@export var ink_px: float = 4.0
@export var core_white: float = 0.9
@export var core_alpha: float = 1.0
@export var core_width: float = 0.3
