class_name HeroData
extends Resource
## 영웅 하나의 데이터: 능력치, 대시, 기본 공격, 단일 버튼 기술 구성.
## 새 영웅 = 새 .tres + 영웅 전용 SkillDef 스크립트.

@export var id: StringName = &""
@export var display_name: String = ""
## 영웅 고르기 화면의 짧은 소개 (줄바꿈 가능).
@export_multiline var tagline: String = ""
## 영웅 고르기 화면 일러스트 (전신).
@export var card_art: Texture2D
## HUD 초상 (지금 게임 속 모델과 같은 얼굴, tools/art/make_portraits.py가 새 원화에서 자름). 비면 body_color 원.
@export var portrait: Texture2D
## false면 고르기 화면에 "준비 중"으로만 보인다 (아직 기술·모델이 없는 영웅).
@export var playable: bool = true
## 3타·큰 기술의 한 타 충격 줄기 모양 (HitImpactLayer.Style): 순신 물보라, 광개토 번개와 흙, 세종 금빛 획, 사임당 먹과 꽃잎.
@export_enum("ink", "water", "thunder", "gold", "petal") var impact_style: int = 0
## 이 영웅이 처음 서는 무대 (StageTheme.id). 이기면 무대 순서대로 다음 전장으로 이어간다.
@export var home_stage: StringName = &""
## 이 영웅을 처음 고르면 무대 전에 보여 줄 영웅 이야기 (data/intro/story_<영웅>.tres). 비우면 없음.
@export var story: IntroData
@export var body_color: Color = Color(0.15, 0.4, 0.8)
## 구워진 8방향 스프라이트 (tools/bake). 비어 있으면 수묵풍 코드 그림.
@export var sprite_sheet: SpriteSheetSet
## 스프라이트 표시 배율과 발 위치 보정(px).
@export var sprite_scale: float = 0.75
@export var sprite_offset: Vector2 = Vector2(0, -30)

@export_group("능력치")
@export var max_hp: int = 100
@export var move_speed: float = 340.0
## 멈춤 → 최고 속도까지 걸리는 시간(초)과 최고 속도 → 멈춤 시간. 0이면 즉시 (가벼움 ↔ 무게감).
@export var move_accel_time: float = 0.0
@export var move_decel_time: float = 0.0
## 피격 후 무적 시간(초).
@export var hurt_invuln_time: float = 0.6
## 회피 성공(예고 원을 대시로 벗어남) 즉시 무적 시간(초).
@export var evade_invuln_time: float = 1.0

@export_group("대시")
@export var dash_distance: float = 260.0
@export var dash_duration: float = 0.12
@export var max_dash_charges: int = 2
@export var dash_recharge_time: float = 1.2
## 0보다 크면 대시 경로 옆의 적을 이 힘으로 밀쳐 낸다 (광개토대왕 돌격). 대시 한 번에 적마다 한 번.
@export var dash_shove: float = 0.0
@export var dash_shove_radius: float = 70.0
## 영웅마다 다른 회피 생김새·도착 효과 (없으면 기본 대시).
@export var dash_style: DashStyleData

@export_group("무게감 (보이는 무게, 조작은 그대로)")
## 발밑 먹 그림자: 몸 반지름 배율·속 진하기.
@export var shadow_scale: float = 1.15
@export var shadow_alpha: float = 0.34
## 대시 착지: 눌림(발 기준 가로·세로 배율)·되돌아오는 시간(초)·그림 멈칫(초, 이동은 그대로)·먹 튐 방울 수·흔들림·화면 밀림(px).
@export var land_squash: Vector2 = Vector2(1.1, 0.88)
@export var land_time: float = 0.12
@export var land_hold: float = 0.04
@export var land_drops: int = 4
@export var land_trauma: float = 0.0
@export var land_kick_px: float = 0.0
## 달리다 멈출 때 몸이 앞으로 쏠렸다 돌아오는 거리(px)·시간(초) (그림만).
@export var stop_slide_px: float = 6.0
@export var stop_slide_time: float = 0.14
## 명중 재질 소리 겹 (SoundBank 종류, 공통 몸통 "hit" 위에 같이 울린다). 예: 순신 물·칼.
@export var hit_sfx: Array[StringName] = []
## 궁극기를 모으는 동안 발밑 표시 (없으면 공통 붓 고리).
@export var charge_marker: ChargeMarkerData
## 무기가 몹에 박히는 느낌 (역경직, BladeBiteData). 비면 꺼짐 (예전 방식). 지금은 순신만.
@export var blade_bite: BladeBiteData

@export_group("전투")
@export var attack: BasicAttackData
@export var kit: SkillKit
## 이 영웅이 만나는 보스의 체력 배율 (영웅 화력 차이를 메워 어느 무대 보스든 비슷한 길이로, BossHpScale).
## 근거: tests/test_hero_dps_probe.gd (허수아비 초당 피해), tests/test_boss_balance_sim.gd (16조합 시간).
@export var boss_hp_mult: float = 1.0

@export_group("성장")
## 레벨업 때 나오는 성장 선택지.
@export var upgrade_pool: UpgradePool
## 정예 처치 보상: 기술 행동을 바꾸는 큰 변형.
@export var major_pool: UpgradePool
## 판 안 레벨이 오를 때마다 바로 적용하는 작은 능력치 상승 (UpgradeDef의 mods만 쓴다. 기술 모습은 LevelRules.vfx_every).
@export var level_up: UpgradeDef
