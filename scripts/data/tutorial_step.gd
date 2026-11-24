class_name TutorialStep
extends Resource
## 조작 안내 한 단계: 붓글씨 제목 + 설명, 무엇을 몇 번 하면 넘어가는지.
## event: &"move"(걸은 거리 px) / &"combo"(손으로 연계를 끝까지 이음) / &"skill_tap"(첫째 기술, 연타 마무리)
## / &"dash" / &"skill_dash" / &"skill_charge" / &"evade"(적의 예고 공격을 대시로 피하기)
## / &"skill_counter"(피한 직후 반격) / &"upgrade"(연습 강화 카드 하나 고르기) / &"wait"(초).

@export var caption: String = ""
@export_multiline var hint: String = ""
## 스킬 단추를 켠 경우의 설명 (비우면 hint).
@export_multiline var button_hint: String = ""
## 영웅마다 다른 설명 (영웅 id 글자열 → 글). 평타가 근접·중거리·원거리로 다른 단계에 쓴다. 없으면 hint.
@export var hero_hints: Dictionary = {}
## 물결 모드 무대(StageTheme.waves)에서의 설명 (비우면 위 규칙대로).
@export_multiline var wave_hint: String = ""
@export var event: StringName = &"wait"
@export var amount: float = 1.0
## 이 단계 동안 세워 둘 연습 상대 (비우면 없음). 이어진 단계가 같은 상대면 그대로 둔다 (TutorialSparring).
@export var practice_enemy: EnemyData
## 안내 띠를 화면 위쪽에 (아래쪽 게임 안내, 예: 반격 신호 "강화 반격!"을 가리지 않게).
@export var banner_top: bool = false
## 연습 상대를 세울 거리 (플레이어 위쪽, px). 0이면 TutorialData.practice_distance.
@export var practice_distance: float = 0.0


## 지금 보여 줄 설명: 물결 모드 → 스킬 단추 → 영웅별 → 기본 순.
func text_for(hero_id: StringName, button: bool, waves: bool) -> String:
	if waves and wave_hint != "":
		return wave_hint
	if button and button_hint != "":
		return button_hint
	return String(hero_hints.get(String(hero_id), hint))
