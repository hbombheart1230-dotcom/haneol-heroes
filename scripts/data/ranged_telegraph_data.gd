class_name RangedTelegraphData
extends Resource
## 원거리(사격) 예고의 모양과 수치 (data/combat/ranged_telegraph.tres). 가늘고 날렵한 인주 획은 그대로, 예고 시간은 건드리지 않고 보이는 것만 정한다.

const PATH := "res://data/combat/ranged_telegraph.tres"
static var _cached: RangedTelegraphData

## 모양: 0 = 굵은 띠 (맞는 폭 그대로, 먹 테두리 + 인주 속 + 밝은 속줄),
## 1 = 띠 + 좁아지는 폭 (처음엔 넓게 시작해 쏘는 순간 실제 맞는 폭으로), 2 = 띠 + 쏘는 적 머리 위 표시 + 화면 밖 사수 방향 표시.
## 모양: 0 = 또렷한 획 (불투명 + 얇은 먹 그림자 + 밝은 속심), 1 = 쏘는 쪽에서 과녁으로 그어지는 획 + 쏘기 직전 팽팽,
## 2 = 또렷한 획 + 맞는 폭을 끝에만 옅게 + 쏘는 적 발밑 인주빛 번짐.
@export_range(0, 2) var style: int = 0
@export_group("획")
## 획 굵기(px): 예고 처음 → 마지막 (전 모양은 3 → 10). 인주 진하기: 처음 → 마지막.
@export var width_from: float = 4.0
@export var width_to: float = 8.0
@export var alpha_from: float = 0.75
@export var alpha_to: float = 1.0
## 먹 그림자: 획보다 이만큼(px) 굵게, 진하기. 밝은 속심: 굵기(px), 진하기.
@export var shadow_extra: float = 3.0
@export var shadow_alpha: float = 0.5
@export var core_width: float = 1.6
@export var core_alpha: float = 0.6
@export_group("그어짐·팽팽 (모양 1)")
## 예고의 앞 이만큼(0~1) 동안 그어진다. 이 비율부터 팽팽해져 이 굵기(px)로.
@export_range(0.1, 1.0) var draw_part: float = 0.55
@export_range(0.0, 1.0) var tense_from: float = 0.8
@export var tense_width: float = 3.0
@export_group("맞는 폭·인주빛 (모양 2)")
## 끝 가까이 드러내는 길이 비율, 진하기 (예고가 차오를수록).
@export_range(0.05, 0.6) var hit_tail: float = 0.22
@export var hit_alpha: float = 0.35
## 쏘는 적 발밑 번짐: 몸 반지름의 몇 배, 진하기.
@export var glow_radius: float = 1.7
@export var glow_alpha: float = 0.4


static func default() -> RangedTelegraphData:
	if _cached == null:
		_cached = load(PATH) as RangedTelegraphData
		if _cached == null:
			_cached = RangedTelegraphData.new()
	return _cached
