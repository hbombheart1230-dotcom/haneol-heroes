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

@export_group("그림 (그려진 이펙트)")
## 비어 있지 않으면 이 그림을 터뜨린다 (assets/vfx/*.png: 아이콘에서 뽑거나 GPT 그림).
@export var decal: Texture2D
## 지름(px)과 끝 크기 배율, 보이는 시간(초), 처음 나타나는 시간(초).
@export var decal_size: float = 300.0
@export var decal_grow: float = 1.35
@export var decal_time: float = 0.55
@export var decal_fade_in: float = 0.08
## 회전 속도(라디안/초). true면 방향(dir) 쪽으로 돌려 놓는다 (베기·유성·벼락길).
@export var decal_spin: float = 0.0
@export var decal_align: bool = false
## 그림이 원래 가리키는 방향(도, 0 = 오른쪽). 맞출 때 빼 준다 (번개 그림은 아래 = 90).
@export var decal_angle_deg: float = 0.0
## true면 돌리지 않고 그림 그대로 세운다 (내리꽂는 벼락·유성).
@export var decal_upright: bool = false
## 같은 그림을 이만큼 더 겹친다 (돌려서, 조금 작게). 강화 단계가 오르면 늘어난다.
@export var decal_layers: int = 1
## 더하기 빛 (어두운 바닥에서 빛나게): 세기와 색, 그림 대비 크기.
@export var glow: float = 0.0
@export var glow_color: Color = Color(1, 0.9, 0.6)
@export var glow_size: float = 0.9

@export_group("강화 단계")
## 기술 강화 단계(SkillDef.vfx_level)마다: 크기, 입자 수, 빛 세기가 늘어난다.
@export var level_size: float = 0.12
@export var level_count: float = 0.25
@export var level_glow: float = 0.12
## 이 단계부터 그림을 한 겹 더, 이 단계부터 금빛 고리까지 (화려해짐).
@export var flourish_level: int = 2
@export var ring_level: int = 4
## 단계 상한 (이 이상은 더 커지지 않음).
@export var max_level: int = 6


func level_of(level: int) -> int:
	return clampi(level, 0, max_level)


func size_mult(level: int) -> float:
	return 1.0 + level_size * level_of(level)


func count_for(level: int) -> int:
	return roundi(count * (1.0 + level_count * level_of(level)))


func layers_for(level: int) -> int:
	return decal_layers + (1 if level_of(level) >= flourish_level else 0)


func glow_for(level: int) -> float:
	return glow * (1.0 + level_glow * level_of(level)) if glow > 0.0 else 0.0
