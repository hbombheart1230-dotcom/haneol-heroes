class_name ZoneHopFxData
extends Resource
## 구역 건너뛰기 뜀·착지 연출 값 (ZoneHopFx). ZoneHopFeel.fx에 붙인다. 비면 연출 없음 (예전처럼).
## 사용자 (한산 배 건너뛰기 시험판): "점프하고 착지할 때 효과가 아예 없고 소리도 없어". 수묵·국악 말투.
## 그림은 있는 것만 쓴다: 먹 방울·먹 자국(KillFx, 한 번에 그림), 나무 조각·물보라(SkillVfxData 입자), 흔들림·멈춤·진동(Feedback).

## 먹 방울 색: 밤바다 갑판(어두운 남색)에서 먹색은 묻혀 안 보인다 (시험판에서 착지 먹 튐이 "아예 없다"로 보인 까닭) →
## 물보라·한지 쪽 밝은 색. 큰 먹 자국(land_ink)도 같은 까닭으로 기본 끔.
@export var drop_color: Color = Color(0.9, 0.93, 0.96, 1.0)

@export_group("뜀 (도움닫기 끝)")
## 갑판 나무 먼지 (cannon_splinter 같은 입자, 비면 없음)와 뒤로 튀는 먹 방울 수.
@export var takeoff_vfx: SkillVfxData
## 발밑 밝은 먼지 뭉게 (어두운 갑판에서 보이게, 비면 없음).
@export var takeoff_puff_vfx: SkillVfxData
@export var takeoff_drops: int = 10
## 발 구르는 소리, 바람 가르는 소리 (SoundBank 종류)와 음높이.
@export var takeoff_stomp_sfx: StringName = &"thud"
@export var takeoff_stomp_pitch: float = 0.8
@export var takeoff_wind_sfx: StringName = &"evade"
@export var takeoff_wind_pitch: float = 0.85
@export var takeoff_trauma: float = 0.12

@export_group("공중")
## 영웅 뒤 먹 꼬리: 이 간격(초)마다 방울 n개를 뛰는 반대쪽으로 (그림 높이에서).
@export var trail_gap: float = 0.05
@export var trail_drops: int = 3
## 먹 꼬리에 겹치는 옅은 물안개 뭉게 (trail_puff_gap초마다, 비면 없음).
@export var trail_puff_vfx: SkillVfxData
@export var trail_puff_gap: float = 0.1
## 바다 위 물보라: 뛰어오름 몫(0~1) 자리마다 한 번, 영웅 발밑 바다에 (비면 없음).
@export var splash_vfx: SkillVfxData
@export var splash_at: PackedFloat32Array = PackedFloat32Array([0.35, 0.75])
## 화면 살짝 끌어당김 (줌 배율, 오르는 데 걸리는 몫 그대로, 착지 때 돌아옴). 1이면 없음.
@export var air_zoom: float = 1.04

@export_group("착지")
## 큰 번짐 (밝은 물안개 먹 번짐 입자), 나무 조각 입자, KillFx 먹 자국(어두운 무대용, 기본 끔).
@export var land_bloom_vfx: SkillVfxData
@export var land_vfx: SkillVfxData
@export var land_ink: bool = false
@export var land_drops: int = 14
## 흔들림·멈춤(실제 초, 게임 속도)·진동(ms, 세기) — 약하게.
@export var land_trauma: float = 0.35
@export var land_stop: float = 0.06
@export var land_stop_scale: float = 0.1
@export var land_haptic_ms: int = 40
@export var land_haptic_amp: float = 0.8
## 묵직한 착지음 + 국악 한 타 (북; 꽹과리 아님).
@export var land_sfx: PackedStringArray = PackedStringArray(["w_heavy", "thud", "gugak_buk"])
@export var land_pitch: float = 0.9
## 줌이 제자리로 돌아오는 시간(초).
@export var zoom_back: float = 0.25
