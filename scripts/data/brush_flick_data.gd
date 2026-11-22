class_name BrushFlickData
extends Resource
## 사임당 중거리 먹 털기의 그림·소리 (BrushFlick). 판정·타이밍은 BasicAttackData (AutoAttack._strike, 타격감 세션):
## 1타 = 부채꼴 가로 털기, 2타 = 좁고 긴 세로 털기 (한 줄 먹 획), 3타 = 둘레 원으로 뿌리기 (먹 고리 + 튄 먹).
## 닿는 순간 붓 획이 판정 모양을 따라 휘둘러지듯 그려지고(reveal), 잠깐 머문 뒤 먹으로 풀린다. 바닥엔 먹 방울 자국이 잠깐.

const PATH := "res://data/feel/brush_flick.tres"

## 이 연출을 쓰는 영웅 (HeroData.id).
@export var heroes: PackedStringArray = PackedStringArray(["shin_saimdang"])

@export_group("모양")
## 판정 각도가 이 아래면 한 줄 먹 획(세로 털기), 이 위면 둘레 고리(원으로 뿌리기), 그 사이는 부채꼴.
@export var streak_below_deg: float = 60.0
@export var ring_above_deg: float = 300.0
## 부채꼴: 획 가운데 반지름(판정 거리 비율)과 두께(px). 한 줄 획: 시작 거리 비율과 두께. 고리: 반지름 비율과 두께.
@export var arc_mid: float = 0.72
@export var arc_width: float = 58.0
@export var streak_from: float = 0.18
@export var streak_width: float = 34.0
@export var ring_mid: float = 0.85
@export var ring_width: float = 52.0
## 획을 나누는 조각 수 (휘어진 획).
@export var segments: int = 14
## 휘어진 획은 이 각도(도)마다 적어도 한 조각 (원으로 뿌리기 360°면 45조각).
@export var seg_deg: float = 8.0

@export_group("시간 (초)")
## 획이 그려지는 시간, 다 그려진 채 머무는 시간, 먹으로 풀리는 시간.
@export var reveal: float = 0.1
@export var hold: float = 0.06
@export var fade: float = 0.22

@export_group("색")
## 먹색 (영웅 색으로 살짝 물든 짙은 보라 먹), 젖은 윤기 (밝은 테두리 한 번 더).
@export var ink_color: Color = Color(0.14, 0.07, 0.18, 0.88)
@export var sheen_mix: float = 0.35
@export var sheen_alpha: float = 0.45

@export_group("튄 먹 · 바닥 자국")
## 연타 번호(1~3)별 바닥에 남는 먹 방울 자국 수, 공중 먹 방울 수.
@export var splats: PackedInt32Array = PackedInt32Array([3, 2, 9])
@export var drops: PackedInt32Array = PackedInt32Array([4, 3, 10])
@export var splat_radius: Vector2 = Vector2(9.0, 17.0)
@export var splat_time: float = 0.9
@export var splat_alpha: float = 0.4

@export_group("소리")
## 붓 터는 소리 (짧은 바람 소리, 연타 번호별 음높이). 젖은 타격음은 영웅 명중 소리(mat_ink·mat_brush)가 이미 낸다.
@export var flick_sfx: StringName = &"slash"
@export var flick_pitch: PackedFloat32Array = PackedFloat32Array([0.95, 1.12, 0.82])
@export var flick_gap: float = 0.03

@export_group("상한")
@export var max_strokes: int = 6
@export var max_splats: int = 24

static var _cached: BrushFlickData


static func get_default() -> BrushFlickData:
	if _cached == null:
		_cached = load(PATH) as BrushFlickData if ResourceLoader.exists(PATH) else null
		if _cached == null:
			_cached = BrushFlickData.new()
	return _cached


func applies_to(hero_id: StringName) -> bool:
	return heroes.has(String(hero_id))


## 판정 각도(도)로 모양: 0 = 부채꼴, 1 = 한 줄 획, 2 = 고리.
func shape_of(arc_deg: float) -> int:
	if arc_deg >= ring_above_deg:
		return 2
	if arc_deg < streak_below_deg:
		return 1
	return 0


func life() -> float:
	return reveal + hold + fade
