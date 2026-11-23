class_name ChargeMarkerData
extends Resource
## 궁극기(충전 기술)를 모으는 동안 발밑에 깔리는 영웅별 표시: 그림 두 겹이 돌며 충전만큼 커지고 진해진다,
## 모으는 동안 작은 입자, 다 모이면 번쩍. HeroData.charge_marker에 붙인다 (없으면 공통 붓 고리).

@export_group("그림")
## 바깥 그림과 안쪽 그림 (반대로 돈다), 각 색.
@export var art: Texture2D
@export var art2: Texture2D
@export var tint: Color = Color(1, 1, 1, 1)
@export var tint2: Color = Color(1, 1, 1, 0.8)
## 지름(px): 충전 0일 때와 다 찼을 때. 안쪽 그림은 바깥의 inner_scale배.
@export var size_min: float = 90.0
@export var size_max: float = 190.0
@export var inner_scale: float = 0.6
## 회전 속도(라디안/초, 바깥·안쪽).
@export var spin: float = 1.5
@export var spin2: float = -2.5
## 투명도: 충전 0 → 다 찼을 때.
@export var alpha_min: float = 0.45
@export var alpha_max: float = 0.95

@export_group("입자·번쩍임")
## 모으는 동안 이 간격(초)마다 작은 입자 (물방울·불똥·별·꽃잎).
@export var spark_vfx: SkillVfxData
@export var spark_interval: float = 0.12
## 다 모인 순간 터지는 이펙트와 번쩍임 (시간·커지는 배율·밝기).
@export var full_vfx: SkillVfxData
@export var full_flash_time: float = 0.3
@export var full_flash_scale: float = 1.5
@export var full_flash_bright: float = 1.8
## 다 모인 순간 소리 (SoundBank 종류, 비우면 없음).
@export var full_sfx: StringName = &""

@export_group("모으는 마디 (ChargeScaling.stages)")
## 발밑 고리 아래 마디 점: 반지름(px, 고리 바깥), 점 크기, 빈 마디 고리 색·찬 마디 색 (먹 바탕 위).
@export var pip_radius: float = 70.0
@export var pip_size: float = 7.0
@export var pip_empty: Color = Color(0.95, 0.91, 0.82, 0.6)
@export var pip_full: Color = Color(0.95, 0.91, 0.82, 0.95)
## 마디를 넘는 순간 소리 (마디마다 음이 오른다)와 고리가 잠깐 커지는 배율·시간.
@export var stage_sfx: StringName = &"gugak_pyeon"
@export var stage_pitch_step: float = 0.12
@export var stage_pulse_scale: float = 1.18
@export var stage_pulse_time: float = 0.14

@export_group("조준 길 (SkillDef.charge_aim)")
## 이동 입력이 이 크기(0~1) 이상일 때만 방향을 바꾼다.
@export var aim_min_input: float = 0.35
## 먹선 길: 시작 거리(px, 발밑 고리 밖), 가운데 먹선 굵기, 화살촉 크기, 색 (띠·먹선), 투명도 (충전 0 → 다 참).
@export var aim_start: float = 46.0
@export var aim_line_width: float = 4.0
@export var aim_head: float = 26.0
@export var aim_fill: Color = Color(0.95, 0.91, 0.82, 0.28)
@export var aim_ink: Color = Color(0.09, 0.09, 0.11, 0.85)
@export var aim_alpha_min: float = 0.55
@export var aim_alpha_max: float = 1.0
