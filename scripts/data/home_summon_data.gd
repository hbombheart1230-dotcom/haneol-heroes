class_name HomeSummonData
extends Resource
## 주인 영웅 부르기 (원정 전장에서만): 그 전장의 주인 영웅을 불러 큰 기술 한 번을 다 모은 세기로 쓴다.
## 횟수: 판마다 charges_start번, 우두머리가 나오면 charges_boss번 더 (최대 charges_max). 단추는 왼쪽 위 영웅 묶음 바로 아래.
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
## 단추 자리 (사용자 2026-11-26 "왼쪽 위, 영웅 표시 바로 아래"): 가운데 x = button_x px (초상 가운데 HeroBadge.ORIGIN.x와 같은 줄),
## 테 위 끝이 영웅 묶음 아래 끝(HeroBadge.BOTTOM)에서 button_gap px 아래. 화면 높이와 상관없이 같은 자리 (세로·긴 화면·폴드).
@export var button_x: float = 70.0
@export var button_gap: float = 10.0
@export var button_radius: float = 42.0
## 잘못 눌림 막기 (독립 검토: 왼쪽 가장자리에서 움직이려던 손가락이 단추에 먹혀 떼면 부르기가 나갔다):
## 누른 손가락이 tap_slop(px) 넘게 움직이면 그 손가락은 영웅 움직이기로 넘긴다 (TouchController, 부르기 없음),
## 짧게 톡 누른 것(tap_max_time초 안에 뗌)만 부른다.
@export var tap_slop: float = 18.0
@export var tap_max_time: float = 0.45
## 단추 옆 한 줄 안내가 떠 있는 시간(초). 판 시작 뒤 단추가 처음 보일 때와 우두머리 때 한 번 더.
@export var hint_time: float = 5.0
@export var hint_text: String = "%s 부르기 · 누르면 한 번 돕는다"
@export var hint_more_text: String = "%s 부르기 한 번 더"
## 부를 때 주인 영웅 대사(HeroLines.Case.SUMMON)가 단추 옆에 떠 있는 시간(초).
@export var line_time: float = 2.2
@export var font_px: int = 26
## 단추 옆 안내 줄·대사의 글 바닥 줄 (단추 가운데 기준 px): 단추 위쪽 반에 붙여, 그 아래를 행동 점수 자리로 남긴다.
@export var text_dy: float = -8.0
## 단추가 보이는 동안 영웅 묶음 아래 행동 점수·"경지 오름" 글을 이만큼 옮긴다 (단추를 덮지 않게 단추 오른쪽, 단추 안내 줄 아래로).
@export var badge_text_shift: Vector2 = Vector2(113, 62)

static var _default: HomeSummonData


static func get_default() -> HomeSummonData:
	if _default == null:
		_default = load(PATH) as HomeSummonData if ResourceLoader.exists(PATH) else HomeSummonData.new()
	return _default


## 테 두께 (HomeSummonButton이 반지름 + 이만큼 옻칠 테를 그린다).
const RIM := 7.0


func button_center(_vp: Vector2 = Vector2.ZERO) -> Vector2:
	return Vector2(button_x, HeroBadge.BOTTOM + button_gap + button_radius + RIM)


func entry_for(hero_id: StringName) -> HomeSummonEntry:
	for e in entries:
		if e and e.hero_id == hero_id:
			return e
	return null
