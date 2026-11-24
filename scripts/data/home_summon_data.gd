class_name HomeSummonData
extends Resource
## 주인 영웅 부르기 (원정 전장에서만): 그 전장의 주인 영웅을 불러 큰 기술 한 번을 다 모은 세기로 쓴다.
## 횟수: 판마다 charges_start번, 우두머리가 나오면 charges_boss번 더 (최대 charges_max). 단추는 왼쪽 위 영웅 묶음 아래.
## 누가 주인인지는 영웅 전장 목록(HeroData.campaign)이 정한다. 어떤 기술인지와 세기는 entries.

const PATH := "res://data/summon/home_summon.tres"

@export var enabled: bool = true
@export var charges_start: int = 1
@export var charges_boss: int = 1
@export var charges_max: int = 2
## 기술을 모은 정도 (1 = 다 모음).
@export_range(0.0, 1.0) var charge: float = 1.0
## 한 번에 우두머리 체력의 이 비율 근처를 노린다 (시험 기준: boss_share_min~boss_share_max).
@export var boss_share_min: float = 0.08
@export var boss_share_max: float = 0.12
@export var entries: Array[HomeSummonEntry] = []
@export_group("단추")
## 단추 가운데: 왼쪽에서 button_x px, 위에서 화면 높이 × button_y (연타 글씨 ComboTextData.anchor 0.36보다 아래:
## 영웅 묶음 아래 행동 점수·경지 오름 글씨와 연타 글씨를 피한다). 반지름 px.
@export var button_x: float = 72.0
@export var button_y: float = 0.42
@export var button_radius: float = 42.0
## 단추 옆 한 줄 안내가 떠 있는 시간(초). 판 시작 뒤 단추가 처음 보일 때와 우두머리 때 한 번 더.
@export var hint_time: float = 5.0
@export var hint_text: String = "%s 부르기 · 누르면 한 번 돕는다"
@export var hint_more_text: String = "%s 부르기 한 번 더"
## 부를 때 주인 영웅 대사(HeroLines.Case.SUMMON)가 단추 옆에 떠 있는 시간(초).
@export var line_time: float = 2.2
@export var font_px: int = 26

static var _default: HomeSummonData


static func get_default() -> HomeSummonData:
	if _default == null:
		_default = load(PATH) as HomeSummonData if ResourceLoader.exists(PATH) else HomeSummonData.new()
	return _default


func button_center(vp: Vector2) -> Vector2:
	return Vector2(button_x, vp.y * button_y)


func entry_for(hero_id: StringName) -> HomeSummonEntry:
	for e in entries:
		if e and e.hero_id == hero_id:
			return e
	return null
