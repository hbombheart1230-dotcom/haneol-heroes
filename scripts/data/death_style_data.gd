class_name DeathStyleData
extends Resource
## 무엇에 죽었는가에 따른 처치 모습 (DeathFx, d2r_benchmark.md 제안). 새 속성 시스템 없이 "처치한 영웅"으로 정한다:
## 순신 = 물(번지며 씻겨 내려감, 젖은 자국), 광개토 = 번개·땅(번쩍 → 재·먼지, 금 간 자국),
## 세종 = 글자·빛(글자 획·금빛 조각이 떠오름), 사임당 = 먹·꽃(먹 방울과 꽃잎으로 풀림).
## 작은 처치(평타)는 짧고 담백하게, 큰 처치(강타·센 피해·정예·보스)는 크게. 화면 흔들림·감속은 Feedback 규칙 그대로.

const PATH := "res://data/feel/death_styles.tres"

## 영웅 id → 속성 (water, thunder, glyph, ink). 없으면 군대별 예전 모습 (연기·종이).
@export var hero_element: Dictionary = {&"yi_sun_sin": &"water", &"gwanggaeto": &"thunder", &"sejong": &"glyph",
	&"shin_saimdang": &"ink"}

@export_group("크기")
## 작은 처치·큰 처치의 조각 수 배율, 크기 배율, 시간 배율.
@export var small_count: float = 0.6
@export var big_count: float = 1.4
@export var small_scale: float = 0.8
@export var big_scale: float = 1.25
@export var small_time: float = 0.7
@export var big_time: float = 1.0
## 동시에 그리는 조각·자국 상한 (넘치면 가장 오래된 칸부터 덮음).
@export var max_bits: int = 96
@export var max_marks: int = 12

@export_group("물 (순신)")
@export var water_parts: Array[Texture2D] = []
@export var water_stain: Texture2D
@export var water_color: Color = Color(0.55, 0.8, 1.0, 1.0)
## 조각 수(기본), 번지는 물 얼룩 지름(px)·내려가는 거리(px)·시간, 남는 젖은 자국 시간.
@export var water_bits: int = 6
@export var water_bloom: float = 130.0
@export var water_slide: float = 34.0
@export var water_bloom_time: float = 0.55
@export var water_stain_time: float = 1.6

@export_group("번개·땅 (광개토)")
@export var ash_parts: Array[Texture2D] = []
## 비면 먹 붓 얼룩(Ink.splash)을 그을린 색으로 (불 고리 그림은 금 간 자국으로 안 읽혀서 비워 둠).
@export var crack_art: Texture2D
@export var flash_color: Color = Color(1.0, 0.97, 0.8, 1.0)
@export var ash_color: Color = Color(0.32, 0.29, 0.26, 1.0)
@export var crack_color: Color = Color(0.16, 0.12, 0.08, 0.55)
@export var ash_bits: int = 8
@export var flash_radius: float = 46.0
@export var flash_time: float = 0.09
@export var crack_size: float = 110.0
@export var crack_time: float = 1.5

@export_group("글자·빛 (세종)")
@export var star_art: Texture2D
@export var glyph_color: Color = Color(1.0, 0.82, 0.35, 1.0)
@export var glyphs: String = "ㄱㄴㄷㄹㅁㅂㅅㅇㅈㅊㅋㅌㅍㅎ"
@export var glyph_bits: int = 6
@export var star_bits: int = 3

@export_group("먹·꽃 (사임당)")
@export var petal_color: Color = Color(0.95, 0.62, 0.75, 1.0)
@export var petal_bits: int = 8
@export var ink_drops: int = 6

static var _cached: DeathStyleData


static func get_default() -> DeathStyleData:
	if _cached == null:
		_cached = load(PATH) as DeathStyleData if ResourceLoader.exists(PATH) else null
		if _cached == null:
			_cached = DeathStyleData.new()
	return _cached


func element_of(hero_id: StringName) -> StringName:
	return hero_element.get(hero_id, &"")


func count(base: int, big: bool) -> int:
	return maxi(roundi(base * (big_count if big else small_count)), 1)


func size_k(big: bool) -> float:
	return big_scale if big else small_scale


func time_k(big: bool) -> float:
	return big_time if big else small_time
