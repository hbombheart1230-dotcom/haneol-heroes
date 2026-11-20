class_name SkillVfxData
extends Resource
## 기술 이펙트 한 종류 (입자 터짐 + 선택적으로 번개 줄기). SkillDef의 vfx_cast·vfx_hit·vfx_impact에 붙인다.
## 텍스처는 VfxTextures가 코드로 만들고(외부 이미지 없음), SkillVfx가 수묵 셰이더로 그린다.

enum Shape { DOT, STAR, PETAL, SHARD, SPLAT, GLYPH }
## RADIAL = 사방, FORWARD = 방향(dir) 쪽 부채꼴, UP = 위쪽 부채꼴.
enum Aim { RADIAL, FORWARD, UP }

@export var shape: Shape = Shape.DOT
## GLYPH일 때 차례로 쓸 글자.
@export var glyphs: String = ""
@export var count: int = 8
@export var aim: Aim = Aim.RADIAL
## FORWARD·UP일 때 부채꼴 전체 각도(도).
@export var spread_deg: float = 60.0
## 처음 속도 범위(px/s)와 초당 감속 비율.
@export var speed: Vector2 = Vector2(80.0, 240.0)
@export var damping: float = 3.0
## 화면 아래쪽으로 당기는 힘(px/s², 물방울·꽃잎이 떨어지는 모양).
@export var gravity: float = 0.0
## 생기는 자리 흩어짐 반지름(px).
@export var spawn_radius: float = 8.0
@export var life: Vector2 = Vector2(0.35, 0.6)
## 크기 범위(px)와 수명 끝 크기 배율.
@export var size: Vector2 = Vector2(10.0, 20.0)
@export var size_end: float = 0.4
## 회전 속도 최대(라디안/초).
@export var spin: float = 0.0
## true면 날아가는 방향으로 기울고 stretch배 길어진다 (불똥·물줄기).
@export var align_to_velocity: bool = false
@export var stretch: float = 1.0
@export var color: Color = Color(1, 1, 1)
@export var color_end: Color = Color(1, 1, 1, 0)

@export_group("번개 줄기")
## 0보다 크면 impact 때 하늘에서 내리꽂는 번개 줄기를 그린다 (꺾이는 마디 수).
@export var bolt_segments: int = 0
@export var bolt_jitter: float = 26.0
@export var bolt_width: float = 10.0
@export var bolt_time: float = 0.22
@export var bolt_height: float = 420.0
@export var bolt_color: Color = Color(1.0, 0.95, 0.6)


func has_bolt() -> bool:
	return bolt_segments > 0
