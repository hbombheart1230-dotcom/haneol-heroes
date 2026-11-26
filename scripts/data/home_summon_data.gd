class_name HomeSummonData
extends Resource
## 주인 영웅 부르기 (원정 전장에서만): 그 전장의 주인 영웅을 불러 큰 기술 한 번을 다 모은 세기로 쓴다.
## 횟수: 판마다 charges_start번, 우두머리가 나오면 charges_boss번 더 (최대 charges_max). 단추는 오른쪽 아래 기술 표시 줄 왼쪽.
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
## 단추 자리 (사용자 2026-11-26 정정 "오른쪽 아래, 기술 단추 아래에 맞춰서"): 가운데 = 화면 오른쪽 아래 끝 - button_from_corner.
## 기술 표시 줄 (SkillButtonDrawer._draw_status: 가운데 y = 아래 끝 - 74, 반지름 32, 오른쪽 끝에서 60·144·228, 간격 84)에 맞춤:
## 단추 테 아래 끝 = 기술 원 아래 끝 (아래 끝 - 42 → 가운데 아래 끝 - 91, 화면 아래 가장자리 쓸어 올리기와 떨어지게),
## 가장 왼쪽 기술 원과 사이 20px (기술 원끼리 사이와 같음 → 오른쪽 끝에서 228 + 32 + 20 + 49 = 329). 화면 비율과 상관없이 모서리 기준.
@export var button_from_corner: Vector2 = Vector2(329, 91)
## 설정에서 큰 기술 단추를 켰을 때 (TouchController.skill_button_offset 170,300, 반지름 110, 기술 표시 줄은 안 그림):
## 그 단추 바로 아래 같은 세로줄, 아래 끝 맞춤은 위와 같음 (큰 단추 아래 끝과 테 사이 약 50px).
@export var button_from_corner_big: Vector2 = Vector2(170, 91)
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
## 안내 줄·대사: 단추 테 위 끝에서 text_gap px 위가 글 바닥 줄, 오른쪽 끝은 화면 오른쪽에서 text_right px (기술 이름 줄 위).
@export var text_gap: float = 14.0
@export var text_right: float = 16.0

static var _default: HomeSummonData


static func get_default() -> HomeSummonData:
	if _default == null:
		_default = load(PATH) as HomeSummonData if ResourceLoader.exists(PATH) else HomeSummonData.new()
	return _default


## 테 두께 (HomeSummonButton이 반지름 + 이만큼 옻칠 테를 그린다).
const RIM := 7.0


func button_center(vp: Vector2, big_skill_button: bool = false) -> Vector2:
	return vp - (button_from_corner_big if big_skill_button else button_from_corner)


func entry_for(hero_id: StringName) -> HomeSummonEntry:
	for e in entries:
		if e and e.hero_id == hero_id:
			return e
	return null
