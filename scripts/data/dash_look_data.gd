class_name DashLookData
extends Resource
## 내닫기(대시) 생김새를 둘로 나누기 (사용자 A안: "들어가는 건지 빠지는 건지 구분이 안 간다"). HeroData.dash_look.
## 치는 내닫기 (돌진 타격이 있는 대시, DashDirection): 무기를 앞으로 내지르는 자세 + 칼 궤적 한 줄 + 맞으면 타격음·타격 효과, 금테 없음.
## 피하는 내닫기 (그 밖: 물러남·옆·예고 안에서 시작·연속 대시·돌진 타격이 없는 영웅): 몸을 낮춘 자세 + 잔상 + 금테, 궤적 없음.
## 자세는 이미 있는 동작의 한 칸을 붙잡는다 (2D 구운 칸 = 3D 같은 시각으로 멈춤). 칸이 -1이면 그 동작을 그대로 튼다.

@export_group("치는 내닫기")
## 내지르는 자세: 동작 이름과 붙잡을 칸 (시트에 없으면 dash).
@export var strike_anim: StringName = &"cast_dash"
@export var strike_frame: int = 1
## 칼 궤적 한 줄 (출발 → 도착, 영웅 평타 색을 흰빛 쪽으로 line_lighten만큼): 굵기(px)·남는 시간(초).
@export var strike_line: bool = true
@export var line_width: float = 40.0
@export var line_time: float = 0.22
@export var line_lighten: float = 0.35
## 맞은 몹마다 평타와 같은 타격 효과 (HitImpact: 섬광·튐 줄기·퍽).
@export var strike_hit_fx: bool = true

@export_group("피하는 내닫기")
## 낮춘 자세: 동작 이름과 붙잡을 칸.
@export var evade_anim: StringName = &"dash"
@export var evade_frame: int = 2
## 잔상: 개수, 남기는 간격(초), 남는 시간(초), 처음 진하기, 색 (지금 자세 그림을 이 색으로).
@export var afterimages: int = 4
@export var afterimage_gap: float = 0.03
@export var afterimage_life: float = 0.22
@export var afterimage_alpha: float = 0.45
@export var afterimage_color: Color = Color(0.85, 0.92, 1.0, 1.0)
## 대시 동안 금테 (EvadeRim) 진하기 (0이면 없음).
@export var evade_rim: float = 1.0

@export_group("공통")
## 영웅 회피 생김새(DashStyleData)의 지나간 길 띠를 그릴지 (칼 궤적·잔상과 헷갈리지 않게 기본 끔).
@export var style_path: bool = false


## 이번 대시 종류에 맞는 [동작, 칸].
func pose(strike: bool) -> Array:
	return [strike_anim, strike_frame] if strike else [evade_anim, evade_frame]
