class_name EnemyData
extends Resource
## 적 한 종류의 데이터. 새 적 = 새 .tres (+ 행동이 다르면 전용 스크립트).

@export var id: StringName = &""
@export var max_hp: int = 30
@export var move_speed: float = 120.0
## 플레이어 접촉 시 피해량.
@export var contact_damage: int = 10
@export var body_radius: float = 20.0
## 처치 시 얻는 경험치.
@export var xp: int = 1
@export var color: Color = Color(0.75, 0.2, 0.25)
## 예고 공격 (없으면 접촉 피해만).
@export var attack: EnemyAttackData
## 0보다 크면 플레이어와 이 거리(px)를 유지한다 (궁수). 0이면 추적.
@export var preferred_range: float = 0.0
## 넉백을 받는 정도 (중장병은 작게).
@export var knockback_scale: float = 1.0
## 처치 때 날아가는 거리 배율 (무거운 적·보스는 작게).
@export var launch_scale: float = 1.0
## 죽는 모양: &"smoke" (망령 → 푸른 연기), &"paper" (초충도 생물 → 조각난 종이 + 먹).
@export var death_style: StringName = &"smoke"
## 기절 시간 배율 (보스·정예는 작게). 1 미만이면 예고 공격을 끊지 않는다.
@export var stun_scale: float = 1.0
## 여러 공격 패턴을 차례로 쓴다 (보스). 있으면 attack 대신 사용.
@export var patterns: Array[EnemyAttackData] = []
## 보스: 처치하면 승리, 화면 위 체력 막대 표시.
@export var is_boss: bool = false
## 정예: 정해진 시각에 나오고, 처치하면 큰 변형 보상.
@export var is_elite: bool = false
@export var display_name: String = ""
## 구워진 8방향 스프라이트 (tools/bake). 비어 있으면 코드 그림.
@export var sprite_sheet: SpriteSheetSet
@export var sprite_scale: float = 1.0
@export var sprite_offset: Vector2 = Vector2(0, -24)
## 스프라이트 색 보정 (보스 금빛 등).
@export var sprite_tint: Color = Color(1, 1, 1)

@export_group("잘 보이게 (shaders/enemy_rim.gdshader)")
## 몸 둘레 망령 빛 테두리 색. 알파가 0이면 셰이더를 쓰지 않는다.
@export var rim_color: Color = Color(0, 0, 0, 0)
## 테두리 두께 (구운 텍스처 픽셀). 정예·보스는 더 크게.
@export var rim_width: float = 3.0
## 몸 밝기 더하기와 대비 배율 (칙칙한 회색 망령을 바닥에서 띄운다).
@export var body_lift: float = 0.0
@export var body_contrast: float = 1.0
## 군대 색과 섞는 비율 (0 = 원래 색).
@export var army_tint: Color = Color(1, 1, 1)
@export var tint_mix: float = 0.0
