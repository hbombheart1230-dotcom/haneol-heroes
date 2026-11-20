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
