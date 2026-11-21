class_name TutorialStep
extends Resource
## 조작 안내 한 단계: 붓글씨 제목 + 설명, 무엇을 몇 번 하면 넘어가는지.
## event: &"move"(걸은 거리 px) / &"dash" / &"skill_tap" / &"skill_dash" / &"skill_charge" / &"wait"(초)
## / &"upgrade"(연습 강화 카드 하나 고르기: 단계가 시작되면 카드 셋이 나온다)
## / &"evade"(적의 예고 공격을 대시로 피하기) / &"skill_counter"(피한 직후 반격).

@export var caption: String = ""
@export_multiline var hint: String = ""
## 스킬 단추를 켠 경우의 설명 (비우면 hint).
@export_multiline var button_hint: String = ""
@export var event: StringName = &"wait"
@export var amount: float = 1.0
## 이 단계 동안 세워 둘 연습 상대 (비우면 없음). 이어진 단계가 같은 상대면 그대로 둔다 (TutorialSparring).
@export var practice_enemy: EnemyData
