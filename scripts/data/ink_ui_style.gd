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
