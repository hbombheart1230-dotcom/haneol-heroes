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
## false면 고르기 화면에 "준비 중"으로만 보인다 (아직 기술·모델이 없는 영웅).
@export var playable: bool = true
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

@export_group("전투")
@export var attack: BasicAttackData
@export var kit: SkillKit

@export_group("성장")
## 레벨업 때 나오는 성장 선택지.
@export var upgrade_pool: UpgradePool
## 정예 처치 보상: 기술 행동을 바꾸는 큰 변형.
@export var major_pool: UpgradePool
