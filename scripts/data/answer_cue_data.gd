class_name AnswerCueData
extends Resource
## 정답 표가 화면·소리로 읽히게 (docs/research/enemy_answers.md): 맞는 수로 맞히면 "통!" + 한 박자 센 소리,
## 갑옷이 다른 수를 덜 받으면 "튕김" + 쇳소리. 색 규칙 (#164): 붉은 인주색은 적 위험 전용이라 쓰지 않는다.

@export var enabled: bool = true
@export_group("통함 (맞는 수)")
@export var hit_label: String = "통!"
@export var hit_color: Color = Color(0.98, 0.88, 0.55)  # 한지 금빛
@export var hit_sfx: StringName = &"gugak_bang"
@export var hit_pitch: float = 1.1
## 화면 흔들림 (Feedback.add_trauma).
@export var hit_trauma: float = 0.12
@export_group("튕김 (다른 수, 갑옷이 덜 받음)")
@export var deflect_label: String = "튕김"
@export var deflect_color: Color = Color(0.72, 0.75, 0.8)  # 먹 회색
@export var deflect_sfx: StringName = &"mat_blade"
@export var deflect_pitch: float = 1.7
## others_mult가 이보다 작을 때만 튕김을 보인다 (거의 1이면 표시 없음).
@export var deflect_below: float = 0.95
@export_group("자주 띄우지 않기")
## 한 적에게 같은 표시는 이 간격(초)보다 자주 띄우지 않는다 (연타가 갑옷을 칠 때 글자가 쌓이지 않게).
@export var per_enemy_gap: float = 0.8
