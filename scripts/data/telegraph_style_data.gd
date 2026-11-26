class_name TelegraphStyleData
extends Resource
## 적 공격 예고(바닥 원·부채·띠·돌진 길·포격선·사격 조준선)의 그림새 (data/ui/telegraph_style.tres, 사용자 2026-11-26:
## "안의 색이 문제가 아니라 테두리가 쨍한 게 더 문제 — 그냥 직설적인 도형에 색도 진해서").
## 테두리를 붓으로 그은 먹 선으로 (굵기 들쭉날쭉·군데군데 끊기는 마른 붓 획, InkPaint 붓 획 그림), 채움 가장자리도 번짐 결로.
## 공정함: 가장 또렷한 선(가는 속심)은 정확히 판정 경계 위에 — 보이는 가장자리 = 맞는 가장자리. 예고 시간·판정은 안 건드린다.
## 치기 직전 신호: 영역 전체가 번쩍이지 않고, 가장자리 먹 선이 한 번 짙어지고 낙관(도장)이 찍힌다.
## 채움은 먹 번짐 (사용자: "안의 내용물은 먹 번짐 — 먹 붓 테랑 먹 번짐이 좋을 것 같은데"): 원은 가운데서, 부채는 적 쪽에서,
## 띠는 뒤에서 차오르고 영역 전체에 한지색 밑칠. 인주는 치기 직전 낙관 정도로만.
## 그림새(look): 0 = (가) 지금 (쨍한 인주 채움 + 인주 테),
## 1 = (바) 먹 붓 테 + 먹 번짐. 인주는 테(rim_tint)와 채움(fill_tint)에 따로 섞는다 (사용자: "안쪽 채움 인주 70%").
## 어두운 바닥(무대 floor_base 밝기 < dark_below, Arena가 floor_luma를 알려 준다)에선 한지색 밑획·속심을 키워 붓 테를 띄운다.
## 붉은 인주색은 적 위험 전용 (색 규칙) — seal_*도 그 계열.

const PATH := "res://data/ui/telegraph_style.tres"
const NOW := 0
const BRUSH_WASH := 1
static var _cached: TelegraphStyleData
## 지금 무대 바닥 밝기 (0~1, Arena.apply_theme이 StageTheme.floor_base로 정한다).
static var floor_luma: float = 1.0

@export_range(0, 1) var look: int = BRUSH_WASH
## (가)의 쨍한 인주 (Ink.SEAL과 같게). (바)의 탁한 인주 (배어남·채움·낙관·사격 조준선·포격 줄).
@export var seal_bright: Color = Color(0.72, 0.13, 0.1)
@export var seal_dull: Color = Color(0.6, 0.2, 0.15)

@export_group("붓 테 (바)")
## 먹 색, 붓 획 굵기(px)·진하기, 굵기 흔들림(0~1), 끊김 비율(0~1, 마른 붓), 한 획 길이(px).
@export var ink_color: Color = Color(0.09, 0.09, 0.11)
@export var brush_width: float = 13.0
@export var brush_alpha: float = 0.9
@export_range(0.0, 1.0) var brush_jitter: float = 0.7
@export_range(0.0, 0.6) var gap_rate: float = 0.22
@export var seg_px: float = 18.0
## 어두운 바닥용 한지색 밑획 (붓 획보다 이만큼 굵게, 진하기). 판정선 위 또렷한 속심 (굵기, 진하기).
@export var under_extra: float = 4.0
@export var under_alpha: float = 0.3
@export var core_width: float = 1.2
@export var core_alpha: float = 0.5

@export_group("어두운 바닥")
## 바닥 밝기가 이보다 낮으면: 한지색 밑획 진하기·굵기 더함, 속심 진하기·굵기.
@export var dark_below: float = 0.55
@export var dark_under_alpha: float = 0.6
@export var dark_under_extra: float = 10.0
@export var dark_core_alpha: float = 0.5
@export var dark_core_width: float = 1.4

@export_group("인주 배어남")
## 먹에서 탁한 인주(seal_dull) 쪽으로 섞는 비율. 테: 0.08 거의 먹 / 0.3 붉은 갈색. 채움: 0 먹 번짐 / 0.7 붉은 번짐
## (불투명도는 ink_alpha 그대로라 화면을 덮지 않는다).
@export_range(0.0, 1.0) var rim_tint: float = 0.08
@export_range(0.0, 1.0) var fill_tint: float = 0.7

@export_group("먹 번짐 채움")
## 먹 채움 색은 ink_color, 진하기 (예고 처음 → 마지막), 영역 전체 한지색 밑칠, 번짐이 처음부터 차 있는 비율.
@export var ink_alpha: Vector2 = Vector2(0.22, 0.5)
@export var paper_under_alpha: float = 0.15
@export_range(0.0, 1.0) var bleed_start: float = 0.25

@export_group("낙관 (도장)")
## 한 변(px), 평소 진하기 (0 = 치기 직전에만 찍힌다), 찍힐 때 진하기·크기 배율.
@export var stamp_px: float = 15.0
@export var stamp_idle: float = 0.0
@export var stamp_flash_alpha: float = 0.95
@export var stamp_flash_scale: float = 1.3

@export_group("치기 직전 (먹 선 짙어짐)")
## 붓 획 굵기 배율, 진하기.
@export var flash_width_mult: float = 1.5
@export var flash_alpha: float = 1.0


static func default() -> TelegraphStyleData:
	if _cached == null:
		_cached = load(PATH) as TelegraphStyleData
		if _cached == null:
			_cached = TelegraphStyleData.new()
	return _cached


func dark_floor() -> bool:
	return floor_luma < dark_below


## 채움 번짐 색 (먹 → 탁한 인주 fill_tint).
func fill_color() -> Color:
	return ink_color.lerp(seal_dull, fill_tint)


## 예고 테·조준선의 인주색 (그림새에 따라).
func seal() -> Color:
	return seal_bright if look == NOW else seal_dull
