class_name FinisherCueData
extends Resource
## 마무리 준비 표시 (FinisherCue): 1·2·3을 이어 "다음 탭은 마무리(4타)"가 되면 발밑에 금빛 붓 고리 + 맑은 소리 한 번.
## 준비가 풀리면(연타 끊김·마무리 냄) 바로 사라진다. 색은 금빛/영웅색 (순적색은 적 위험 전용, #164).

@export var enabled: bool = true
## 붓 고리 그림 (비면 CombatFeelData.ring_art).
@export var art: Texture2D
## 발밑 고리 지름(px)과 영웅 발 기준 위치 (그림자 자리).
@export var size: float = 170.0
@export var offset: Vector2 = Vector2(0, 4)
## 금빛. hero_tint > 0이면 영웅 몸 색(HeroData.body_color)을 이만큼 섞는다.
@export var color: Color = Color(1.0, 0.88, 0.45, 1.0)
## 같은 고리를 한 번 더 (더하기 섞기 대신 겹쳐 진하게, 1 = 한 번).
@export var layers: int = 2
@export_range(0.0, 1.0) var hero_tint: float = 0.15
@export_range(0.0, 1.0) var alpha: float = 1.0
## 켜질 때 크게 들어왔다(pop_scale배) pop_time초 동안 제 크기로, 그 뒤 pulse_hz로 숨 쉬듯 (± pulse_amount 크기·밝기).
@export var pop_scale: float = 1.35
@export var pop_time: float = 0.12
@export var pulse_hz: float = 2.5
@export var pulse_amount: float = 0.08
## 꺼질 때 옅어지는 시간(초) — 짧게 (풀리면 바로).
@export var fade_time: float = 0.06
## 켜질 때 한 번 (SfxBank 이름, 비면 소리 없음)과 높낮이.
@export var sfx: StringName = &"gugak_pyeon"
@export var sfx_pitch: float = 1.5
