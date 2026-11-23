class_name EnemyData
extends Resource
## 적 한 종류의 데이터. 새 적 = 새 .tres (+ 행동이 다르면 전용 스크립트).

@export var id: StringName = &""
@export var max_hp: int = 30
@export var move_speed: float = 120.0
## 플레이어 접촉 시 피해량.
@export var contact_damage: int = 10
@export var body_radius: float = 20.0
## 무기 길이(px): 거리 유지 고리에서 이만큼 더 떨어져 선다 (창·두 손 무기, 타격감 2차).
@export var reach_px: float = 0.0
## 처치 시 얻는 경험치.
@export var xp: int = 1
@export var color: Color = Color(0.75, 0.2, 0.25)
## 예고 공격 (없으면 접촉 피해만).
@export var attack: EnemyAttackData
## 0보다 크면 플레이어와 이 거리(px)를 유지한다 (궁수). 0이면 추적.
@export var preferred_range: float = 0.0
## 넉백을 받는 정도 (중장병은 작게).
@export var knockback_scale: float = 1.0
## 슈퍼아머 (던파식): 잡몹이어도 맞아서 예고가 끊기거나 넘어지지 않는다 (중장병).
@export var super_armor: bool = false
## 보스 단계 (체력 비율 내림차순). 비면 단계 없음.
@export var phases: Array[BossPhaseData] = []
## 처치 때 날아가는 거리 배율 (무거운 적·보스는 작게).
@export var launch_scale: float = 1.0
## 죽는 모양: &"smoke" (망령 → 푸른 연기), &"paper" (초충도 생물 → 조각난 종이 + 먹).
@export var death_style: StringName = &"smoke"
## 기절 시간 배율 (보스·정예는 작게). 1 미만이면 예고 공격을 끊지 않는다.
@export var stun_scale: float = 1.0
## 잡몹 경직(초, 하데스 OnHitStun 0.5): 음수면 공통값 (HitReactionData.stagger_time).
@export var stagger_time: float = -1.0
## 경직이 걸리면 기다리던 공격 대기를 처음부터 (디아1·Flare식, 예고 중이면 끊김 규칙대로).
## 상한은 ImpactFeelData.reset_max_gap_mult (영구 경직 방지).
@export var hit_resets_attack: bool = false
## 움직임·특수 동작 (군대마다 다른 버릇). 없으면 그냥 쫓아온다.
@export var behaviour: EnemyBehaviourData
## 여러 공격 패턴을 차례로 쓴다 (보스). 있으면 attack 대신 사용.
@export var patterns: Array[EnemyAttackData] = []
## 보스: 처치하면 승리, 화면 위 체력 막대 표시.
@export var is_boss: bool = false
## 보스전 박자·연출 (공격 고르기, 등장·전환·처치). 비면 옛 방식.
@export var boss_feel: BossFeelData
## 보스 체력 궁합 (영웅 id → 배율, HeroData.boss_hp_mult에 곱함). 영웅 배율 하나로 안 맞는 조합만 (BossHpScale).
@export var boss_hp_by_hero: Dictionary = {}
## 둘레에 미치는 힘 (깃발·북잡이: 아군 빠르게, 먹물 장판). 비면 없음.
@export var aura: EnemyAuraData
## 정예: 정해진 시각에 나오고, 처치하면 큰 변형 보상.
@export var is_elite: bool = false
@export var display_name: String = ""
## 구워진 8방향 스프라이트 (tools/bake). 비어 있으면 코드 그림.
@export var sprite_sheet: SpriteSheetSet
@export var sprite_scale: float = 1.0
@export var sprite_offset: Vector2 = Vector2(0, -24)
## 스프라이트 색 보정 (보스 금빛 등).
@export var sprite_tint: Color = Color(1, 1, 1)

@export_group("망령 (사람 모습 + 수묵·후처리)")
## 망령 빛 색 (군대마다). 알파 0이면 망령 처리 없음 (곤충 등). 알파 = 세기.
@export var ghost_color: Color = Color(0, 0, 0, 0)
## 몸 불투명도 (1 = 안 비침), 발쪽이 사라지는 비율, 발밑 도깨비불 크기 배율.
@export var ghost_body_alpha: float = 1.0
@export var ghost_fade: float = 0.1
@export var ghost_fire_scale: float = 1.0
@export_group("잘 보이게 (shaders/enemy_rim.gdshader)")
## 몸 둘레 망령 빛 테두리 색. 알파가 0이면 셰이더를 쓰지 않는다.
@export var rim_color: Color = Color(0, 0, 0, 0)
## 테두리 두께 (구운 텍스처 픽셀). 정예·보스는 더 크게.
@export var rim_width: float = 3.0
## 테두리 바깥 옅은 번짐 진하기 (두 배 거리, 0이면 없음). 어두운 바닥에서 몸이 떠 보이게.
@export var rim_halo: float = 0.55
## 망령이면 테두리 색에 망령 색을 섞는 비율 (1 = 망령 색만). 진하기는 rim_color 알파를 따른다.
@export var ghost_rim_mix: float = 0.45
## 몸 밝기 더하기와 대비 배율 (칙칙한 회색 망령을 바닥에서 띄운다).
@export var body_lift: float = 0.0
@export var body_contrast: float = 1.0
## 군대 색과 섞는 비율 (0 = 원래 색).
@export var army_tint: Color = Color(1, 1, 1)
@export var tint_mix: float = 0.0
