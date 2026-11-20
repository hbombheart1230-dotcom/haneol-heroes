class_name TutorialStep
extends Resource
## 조작 안내 한 단계: 붓글씨 제목 + 설명, 무엇을 몇 번 하면 넘어가는지.
## event: &"move"(걸은 거리 px) / &"dash" / &"skill_tap" / &"skill_dash" / &"skill_charge" / &"wait"(초).

@export var caption: String = ""
@export_multiline var hint: String = ""
## 스킬 단추를 켠 경우의 설명 (비우면 hint).
@export_multiline var button_hint: String = ""
@export var event: StringName = &"wait"
@export var amount: float = 1.0
