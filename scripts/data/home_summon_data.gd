class_name HomeSummonData
extends Resource
## 주인 영웅 부르기 (원정 전장에서만): 그 전장의 주인 영웅이 나타나 ally_time초 동안 같이 싸운다 (AllyHero).
## 충전: 시간으로 찬다 (recharge_time초에 한 번, 최대 charges_max번 보관, 판 시작 때 charges_start번 차 있음,
## 우두머리가 나오면 charges_boss번 더 — 지금 0). 단추는 왼쪽 위 영웅 묶음 아래.
## 누가 주인인지는 영웅 전장 목록(HeroData.campaign)이 정한다. 어떤 기술인지와 세기는 entries.

const PATH := "res://data/summon/home_summon.tres"

@export var enabled: bool = true
@export var charges_start: int = 1
@export var charges_boss: int = 1
@export var charges_max: int = 2
## 다음 한 번이 차는 시간(초). 0이면 시간으로 차지 않는다.
@export var recharge_time: float = 60.0
## 기술을 모은 정도 (1 = 다 모음).
@export_range(0.0, 1.0) var charge: float = 1.0
## 한 번에 우두머리 체력의 이 비율 근처를 노린다 (시험 기준: boss_share_min~boss_share_max).
@export var boss_share_min: float = 0.08
@export var boss_share_max: float = 0.12
@export var entries: Array[HomeSummonEntry] = []
@export_group("같이 싸우기")
## 불려 온 주인 영웅이 머무는 시간(초)과 나타나는 자리 (고른 영웅 기준 px).
@export var ally_time: float = 7.0
@export var ally_offset: Vector2 = Vector2(-90, 50)
## 부르기 기술을 쓰는 때(나타난 뒤 초): 0초 = 나타나며 한 방, 그 뒤 한 번 더.
@export var ally_skill_times: PackedFloat32Array = PackedFloat32Array([0.0, 3.5])
## 부르기 기술 한 번의 피해 배율 (entries.damage_scale × 이 값: 두 번 쓰므로 예전 한 방보다 작게).
@export var ally_skill_scale: float = 0.5
## 적에게 이 거리(평타 사거리 × 배율) 안이면 서서 탭, 밖이면 걸어간다. 탭 간격(초).
@export var ally_reach_mult: float = 0.8
@export var ally_tap_gap: float = 0.12
## 이름 띠: 머리 위 높이(px)·글자 크기, 나타남·물러감 먹 번짐 모양 (DeathStyle).
@export var ally_name_lift: float = 150.0
@export var ally_name_px: int = 22
@export var ally_ink_style: StringName = &"smoke"
@export_group("단추")
## 단추 가운데: 왼쪽에서 button_x px, 위에서 화면 높이 × button_y (연타 글씨 ComboTextData.anchor 0.36보다 아래:
## 영웅 묶음 아래 행동 점수·경지 오름 글씨와 연타 글씨를 피한다). 반지름 px.
@export var button_x: float = 72.0
@export var button_y: float = 0.42
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
