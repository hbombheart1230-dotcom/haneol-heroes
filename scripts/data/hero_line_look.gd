class_name HeroLineLook
extends Resource
## 영웅 머리 위 한 줄 대사 겉모습·시간 (HeroLineView). 사용자 "대사는 아직 잘 안 보이네" (폰): 글자를 키우고 먹 바탕 띠를 깔고
## 더 오래 띄운다. 붉은색은 쓰지 않는다 (적 위험 예고 전용).

const PATH := "res://data/ui/hero_line.tres"

## 떠 있는 시간(초)과 끝에 흐려지는 시간(초).
@export var show_time: float = 3.0
@export var fade_time: float = 0.6
## 글자 크기(px). 연타 글씨(ComboCounter)와는 avoid_combo가 위아래로 비킨다.
@export var font_px: int = 44
@export var outline_px: int = 9
## 영웅 발밑에서 글 줄까지 높이(화면 px), 화면 위쪽 여백(우두머리 체력 띠 아래로만).
@export var head_offset: float = 200.0
@export var top_margin: float = 150.0
## 연타 글씨와 띄울 위아래 간격, 옆으로 이만큼 안이면 "가깝다" (화면 px).
@export var combo_gap: float = 24.0
@export var combo_reach: float = 140.0
## 다른 문구가 사라지고 더 기다리는 시간(초).
@export var settle_time: float = 0.6
## 글 뒤 먹 바탕 띠 (양 끝이 가는 붓 획 두 겹: 바깥 옅게, 안쪽 진하게). 글 폭 + pad_x, 높이 = 글자 × band_height.
@export var band_color: Color = Color(0.06, 0.05, 0.05, 0.55)
@export var band_soft_alpha: float = 0.28
@export var band_pad_x: float = 70.0
@export var band_height: float = 1.55

static var _default: HeroLineLook


static func default() -> HeroLineLook:
	if _default == null:
		_default = load(PATH) as HeroLineLook if ResourceLoader.exists(PATH) else HeroLineLook.new()
	return _default
