class_name TelegraphStyleData
extends Resource
## 적 공격 예고(바닥 원·부채·띠·돌진 길·포격선·사격 조준선)의 그림새 (data/ui/telegraph_style.tres, 사용자 2026-11-26
## "너무 빨갛게 뜬다. 게임 분위기에 안 맞고 튄다 — 수묵 처리를 하든지"). 빨강은 없애지 않고 양만 줄인다.
## 예고 시간·판정은 건드리지 않는다 (보이는 것만). 붉은 인주색은 적 위험 전용 (색 규칙) — 여기 seal도 그 계열.
## 그림새(look): 0 = (가) 지금 (쨍한 인주 채움 + 인주 테),
## 1 = (나) 먹 번짐 + 붉은 테: 채움은 먹이 번져 차오르고 (한지 결 있는 먹 번짐 그림), 인주색은 가는 테에만.
##     테는 먹 그림자 + 인주 획 + 밝은 속심 (원거리 예고 #192와 같은 짜임) — 어두운 바닥에서도 읽힌다.
##     치기 직전(EnemyAIData.strike_flash_time)엔 낙관을 찍듯 영역 전체가 인주로 한 번 번쩍.
## 2 = (다) 모양·채움 방식은 지금 그대로, 색만 탁한 인주(seal_dull)로 낮추고 한지 결 채움 + 먹 테를 입힌다 (가장 작은 변경).

const PATH := "res://data/ui/telegraph_style.tres"
const NOW := 0
const INK_BLEED := 1
const DULL_SEAL := 2
static var _cached: TelegraphStyleData

@export_range(0, 2) var look: int = INK_BLEED
## (가)의 쨍한 인주 (Ink.SEAL과 같게).
@export var seal_bright: Color = Color(0.72, 0.13, 0.1)
## (나)·(다)의 탁한 인주 (테·번쩍임·(다) 채움).
@export var seal_dull: Color = Color(0.6, 0.17, 0.12)

@export_group("(나) 먹 번짐 채움")
## 먹 채움 색, 진하기 (예고 처음 → 마지막). 번짐은 원은 가운데서, 부채는 적 쪽에서, 띠는 뒤에서 앞으로 차오른다.
@export var ink_color: Color = Color(0.09, 0.09, 0.11)
@export var ink_alpha: Vector2 = Vector2(0.22, 0.5)
## 어두운 바닥용 한지색 밑칠 (영역 전체, 처음부터). 0이면 없음.
@export var paper_under_alpha: float = 0.15
## 번짐이 처음부터 이만큼(0~1) 차 있다 (너무 작게 시작하면 자리가 안 읽힌다).
@export_range(0.0, 1.0) var bleed_start: float = 0.25

@export_group("(나) 붉은 테")
## 인주 테 굵기(px)·진하기, 먹 그림자 (테보다 이만큼 굵게, 진하기), 밝은 속심 (굵기, 진하기).
@export var rim_width: float = 3.0
@export var rim_alpha: float = 0.95
@export var shadow_extra: float = 3.5
@export var shadow_alpha: float = 0.55
@export var core_width: float = 1.0
@export var core_alpha: float = 0.7

@export_group("(나) 낙관 번쩍 (치기 직전)")
## 영역 전체 인주 진하기, 테 굵기 배율, 밝기 (테 색을 이만큼 밝게).
@export var stamp_alpha: float = 0.42
@export var stamp_rim_mult: float = 1.8
@export var stamp_lighten: float = 0.35

@export_group("(다) 탁한 인주")
## 채움 진하기 = fill_base + fill_gain × 진행 (+ 번쩍일 때 fill_flash). 먹 테: 인주 테 아래 이만큼 굵게, 진하기.
@export var fill_base: float = 0.12
@export var fill_gain: float = 0.26
@export var fill_flash: float = 0.18
@export var dull_rim_width: float = 3.5
@export var dull_ink_extra: float = 3.0
@export var dull_ink_alpha: float = 0.45


static func default() -> TelegraphStyleData:
	if _cached == null:
		_cached = load(PATH) as TelegraphStyleData
		if _cached == null:
			_cached = TelegraphStyleData.new()
	return _cached


## 예고 테·조준선의 인주색 (그림새에 따라).
func seal() -> Color:
	return seal_bright if look == NOW else seal_dull
