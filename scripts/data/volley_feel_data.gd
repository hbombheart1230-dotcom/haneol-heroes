class_name VolleyFeelData
extends Resource
## 일제 사격(EnemyAttackData.volley)을 공정하고 읽히고 안 끊기게 (data/combat/volley_feel.tres).
## 사용자 2026-11-26 "넓은 띠 말고 각자 예고를 딱 맞추는 게 좋을 것 같은데": 구성원마다 원거리 예고를 같은 순간 시작·끝
## (시작을 맞추는 것은 FormationBrain, 여기는 그리기·명중 상한·소리).

const PATH := "res://data/combat/volley_feel.tres"
static var _cached: VolleyFeelData

## 한 번의 일제 사격(같은 박자)에서 영웅이 맞는 탄 수 상한. 넘친 탄은 지나간다 (피해 12×8 즉사 방지).
@export var max_hero_hits: int = 2
## 일제 사격 소리: 같은 소리를 이 간격(초) 안에 다시 내지 않는다 (8발이 따로 울리지 않게 한 묶음).
@export var sfx_gap: float = 0.2
@export_group("예고 그리기")
## 켜면 원거리 예고를 전장의 한 층(RangedTelegraphLayer)에서 InkBatch 하나로 그린다 (사수 수와 상관없이 그리기 호출 하나).
@export var batch_telegraphs: bool = true
## 한꺼번에 이 수 이상 예고 중이면 붐빔 모양 (아래 배율, 1이면 그대로).
@export var crowd_from: int = 6
@export var crowd_width_mult: float = 1.0
@export var crowd_alpha_mult: float = 1.0
@export var crowd_shadow_mult: float = 1.0


static func default() -> VolleyFeelData:
	if _cached == null:
		_cached = load(PATH) as VolleyFeelData
		if _cached == null:
			_cached = VolleyFeelData.new()
	return _cached
