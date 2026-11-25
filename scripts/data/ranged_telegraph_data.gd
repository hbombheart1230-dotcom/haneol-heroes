class_name RangedTelegraphData
extends Resource
## 원거리(사격) 예고의 모양과 수치 (data/combat/ranged_telegraph.tres). 예고 시간은 건드리지 않고 보이는 것만 정한다.

const PATH := "res://data/combat/ranged_telegraph.tres"
static var _cached: RangedTelegraphData

## 모양: 0 = 굵은 띠 (맞는 폭 그대로, 먹 테두리 + 인주 속 + 밝은 속줄),
## 1 = 띠 + 좁아지는 폭 (처음엔 넓게 시작해 쏘는 순간 실제 맞는 폭으로), 2 = 띠 + 쏘는 적 머리 위 표시 + 화면 밖 사수 방향 표시.
@export_range(0, 2) var style: int = 2
@export_group("띠")
## 먹 테두리 굵기(px, 한쪽), 먹 테두리 진하기.
@export var border_px: float = 5.0
@export var border_alpha: float = 0.7
## 인주 속 진하기: 예고 처음 → 마지막.
@export var fill_alpha_from: float = 0.28
@export var fill_alpha_to: float = 0.6
## 쏘기 직전 번쩍일 때 속 진하기 (영웅이 그 밑에 비치게 완전히 덮지 않는다).
@export var flash_alpha: float = 0.78
## 밝은 속줄 (어두운 바닥에서 읽히게): 굵기(px), 진하기.
@export var core_px: float = 4.0
@export var core_alpha: float = 0.75
## 좁아지는 모양: 처음 폭이 실제 맞는 폭의 몇 배.
@export var narrow_from: float = 2.4
@export_group("머리 위 표시·화면 밖 방향")
## 머리 위 표시 크기(px)와 높이 (몸 반지름의 몇 배).
@export var head_mark_px: float = 46.0
@export var head_mark_lift: float = 2.7
## 화면 밖 사수 방향 쐐기 크기(px)와 화면 끝에서 안쪽 여백(px).
@export var edge_arrow_px: float = 34.0
@export var edge_margin: float = 44.0


static func default() -> RangedTelegraphData:
	if _cached == null:
		_cached = load(PATH) as RangedTelegraphData
		if _cached == null:
			_cached = RangedTelegraphData.new()
	return _cached
