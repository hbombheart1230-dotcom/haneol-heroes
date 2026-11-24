class_name InkUiStyle
extends Resource
## 전투 화면의 막대·충전 원·화살·예고를 먹·붓 결로 그릴 때의 색과 굵기 (그림은 assets/vfx/ink_*.png, InkPaint가 그린다).
## 판정·범위의 모양과 크기는 여기 없다 — 겉모습만.

const PATH := "res://data/ui/ink_ui.tres"
static var _cached: InkUiStyle

@export_group("적 체력 막대")
@export var enemy_bar_height: float = 18.0
## 바탕 먹선에 곱하는 색 (투명도로 옅게).
@export var bar_back: Color = Color(1, 1, 1, 0.55)
## 빈 자리 밑칠 (옅은 한지색): 막대가 어두운 바닥에 묻히지 않게.
@export var bar_under: Color = Color(0.9, 0.84, 0.7, 0.26)
@export var enemy_fill: Color = Color(0.86, 0.2, 0.16)
@export var elite_fill: Color = Color(0.94, 0.74, 0.28)
@export_group("내닫기 충전 표시")
@export var pip_radius: float = 20.0
@export var pip_ring: Color = Color(0.09, 0.09, 0.11, 0.9)
## 빈 칸 고리: 어두운 바닥에서도 보이게 마른 금빛 먹.
@export var pip_empty: Color = Color(0.62, 0.5, 0.26, 0.6)
@export var pip_gold: Color = Color(0.94, 0.74, 0.28)
## 찬 칸 안쪽 금빛 번짐이 고리 반지름의 몇 배인지.
@export var pip_fill_scale: float = 0.78
@export_group("물결 진행 표시")
## 줄 높이(위쪽 y, 우두머리 막대 아래), 점 반지름·간격, 한 줄 최대 너비(넘으면 간격을 줄인다).
@export var wave_row_y: float = 146.0
@export var wave_radius: float = 14.0
@export var wave_spacing: float = 58.0
@export var wave_max_width: float = 420.0
## 지금 물결·우두머리 물결 점의 크기 배율 (중간 우두머리는 마름모).
@export var wave_current_scale: float = 1.3
@export var wave_boss_scale: float = 1.55
## 물결이 바뀐 순간 번지는 고리 시간(초).
@export var wave_flash_time: float = 0.7
@export var wave_label_size: int = 26
@export_group("예고 겉모습")
## 안쪽 먹 번짐 알파 곱 (범위 그대로, 겉모습만).
@export var wash_alpha_mult: float = 1.35
## 붓 고리 알파 곱.
@export var ring_alpha_mult: float = 1.5


static func default() -> InkUiStyle:
	if _cached == null:
		_cached = load(PATH) as InkUiStyle
		if _cached == null:
			_cached = InkUiStyle.new()
	return _cached
