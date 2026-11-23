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

@export_group("띠 (직선 기술)")
## 직선 기술(파도격·벽력돌파·발묵)은 경로를 따라 이 그림을 늘려 그린다 (출발점에서 앞으로 펼쳐짐).
## 그림은 가로로 길고 오른쪽이 앞 (assets/vfx/*_strip.png).
@export var strip: Texture2D
## 띠 두께(px), 보이는 시간(초), 앞으로 다 펼쳐지는 시간(초).
@export var strip_width: float = 110.0
@export var strip_time: float = 0.5
@export var strip_reveal: float = 0.15

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
## 강화로 커지는 크기 배율의 상한 (최대 단계에서도 화면을 다 덮지 않게, 띠 두께·입자도).
@export var max_size_mult: float = 1.4
## 켜면 위 단계 값 대신 성장 단계(SkillGrowthData: 기본은 작게, 큰 강화는 크고 화려하게)를 쓴다.
@export var growth: bool = false


func _growth() -> SkillGrowthData:
	return SkillGrowthData.get_default() if growth else null


func level_of(level: int) -> int:
	return clampi(level, 0, max_level)


func size_mult(level: int) -> float:
	var g := _growth()
	if g:
		return g.size_at(level)
	return minf(1.0 + level_size * level_of(level), maxf(max_size_mult, 1.0))


func count_for(level: int) -> int:
	var g := _growth()
	return roundi(count * (g.count_at(level) if g else 1.0 + level_count * level_of(level)))


func layers_for(level: int) -> int:
	var g := _growth()
	if g:
		return decal_layers + g.layers_at(level)
	return decal_layers + (1 if level_of(level) >= flourish_level else 0)


func glow_for(level: int) -> float:
	var g := _growth()
	if glow <= 0.0:
		return 0.0
	return glow * (g.glow_at(level) if g else 1.0 + level_glow * level_of(level))


## 밝기 배율 (조각·그림·띠).
func bright_for(level: int) -> float:
	var g := _growth()
	return g.bright_at(level) if g else 1.0 + level_glow * level_of(level)


## 금빛 고리를 두를 단계인지.
func ring_for(level: int) -> bool:
	var g := _growth()
	return g.ring_at(level) if g else level_of(level) >= ring_level


## 화면 너비 대비 상한 (성장 단계가 있으면 단계별, 없으면 base).
func screen_cap_for(level: int, base: float) -> float:
	var g := _growth()
	return g.cap_at(level) if g and base > 0.0 else base


@export_group("연출 · 조각 등장")
## 0보다 크면 그림을 통째로 내보내지 않고 이만큼의 부채꼴 조각으로 잘라, 시작 방향부터 차례로 휘감아 펼친다
## (조각마다 튀어나왔다 자리 잡음 → 다 모이면 번쩍 → 먹으로 번지며 조각이 흩어짐). 0이면 예전처럼 한 장.
@export var piece_count: int = 0
## 조각이 모두 나타나는 시간(초). 휘감는 기술은 이 시간에 맞춰 적을 차례로 벤다 (SweepOrder).
@export var piece_sweep: float = 0.18
## 조각이 처음 나타날 때 커지는 배율(튀어나옴)과 바깥으로 밀려 나왔다 들어오는 거리(px).
@export var piece_pop: float = 0.3
@export var piece_push: float = 26.0
## 그림 전체가 이만큼(라디안) 감겨 들어오며 멈춘다 (등속 회전 대신 감속).
@export var piece_spin_in: float = 0.9
## 사라질 때 조각이 바깥으로 흩어지는 거리(px).
@export var piece_scatter: float = 40.0
## 다 모인 순간 번쩍임 (더하기 빛 세기, 0이면 없음).
@export var piece_flash: float = 0.9
## 1 = 시계 방향, -1 = 반대.
@export var piece_dir: float = 1.0
## 조각 모양: RADIAL = 부채꼴로 휘감음, SCROLL = 세로 띠가 가운데에서 양옆으로 (두루마리 펼침).
enum PieceMode { RADIAL, SCROLL }
@export var piece_mode: PieceMode = PieceMode.RADIAL

@export_group("연출 · 바늘과 눈금 (해시계)")
## true면 조각과 함께 그림자 바늘이 한 바퀴 돈다 (붓 획 그림).
@export var sweep_hand: bool = false
@export var hand_color: Color = Color(0.1, 0.08, 0.06, 0.85)
@export var hand_width: float = 34.0
## 바늘 길이 (그림 지름 대비, 축에서 끝까지). 그림 바늘(hand_art)은 이 길이의 15%만큼 축 뒤로 나온다.
@export var hand_length: float = 0.42
## 0보다 크면 바늘이 지날 때마다 테두리 눈금이 하나씩 번쩍인다 (눈금 수).
@export var tick_count: int = 0
@export var tick_color: Color = Color(1.0, 0.85, 0.35)
@export var tick_size: float = 70.0
## 눈금이 번쩍이는 고리의 반지름 (그림 지름 대비: 판의 시각 눈금 자리).
@export var tick_ring: float = 0.4
## 눈금마다 울리는 소리 (SoundBank 종류).
@export var tick_sfx: StringName = &"mat_glyph"

@export_group("연출 · 예고와 자국")
## 0보다 크면 이 시간(초) 동안 기운이 가운데로 모인다 (지연 기술의 예고: 유성·화폭·벽력돌파).
@export var gather_time: float = 0.0
@export var gather_count: int = 10
@export var gather_radius: float = 220.0
@export var gather_color: Color = Color(1, 1, 1, 0.9)
## 0보다 크면 터진 자리 바닥에 먹 자국이 이 시간(초) 남는다 (적·영웅 아래).
@export var ground_time: float = 0.0
@export var ground_size: float = 260.0
@export var ground_color: Color = Color(0.08, 0.08, 0.1, 0.55)

@export_group("연출 · 맞은 자리")
## 0보다 크면 맞은 적마다 베인 자국(초승달 붓 획)이 맞은 방향에 가로로 긋는다 (크기 px).
@export var hit_mark_size: float = 0.0
@export var hit_mark_time: float = 0.22
@export var hit_mark_color: Color = Color(1, 1, 1, 0.95)

@export_group("연출 · 그림 속 움직임")
## 떠 있는 동안 그림 속이 일렁이는 세기 (0~1, 물·불·먹). 0이면 정지 그림.
@export var flicker: float = 0.0
## 사라지는 동안 가운데가 감겨 드는 각도(라디안, 소용돌이 흐름). 0이면 없음. 최대 4.
@export var twist: float = 0.0

@export_group("연출 · 판정 크기 맞춤")
## true면 기술이 판정 반경을 알려 줄 때 그림 지름을 판정에 맞춘다 (강화로 판정이 커지면 그림도). 강화 단계의 크기 배율은 쓰지 않는다.
@export var fit_to_hit: bool = true
## 그림 네모 안에서 칠해진 부분의 반지름 비율 (가장자리 투명 여백 제외, tools/art 측정값).
@export var art_fill: float = 0.88

@export_group("연출 · 움직이는 그림 (프레임 시트)")
## 비어 있지 않으면 decal 대신 이 시트를 프레임으로 재생한다 (docs/skill_vfx_sheets.md 규격). strip_sheet는 띠용.
@export var sheet: Texture2D
@export var strip_sheet: Texture2D
## 시트 칸 수 (가로 × 세로), 쓸 장 수 (0 = 전부), 초당 장 수, 끝나면 처음으로 (false면 마지막 장에 멈춤).
@export var sheet_cols: int = 4
@export var sheet_rows: int = 2
@export var sheet_count: int = 0
@export var sheet_fps: float = 16.0
@export var sheet_loop: bool = false


@export_group("연출 · 부품 그림 (층별 슬롯, B안)")
## 층마다 따로 그린 정지 그림 (docs/skill_vfx_sheets.md B안). 비어 있으면 지금처럼 코드·공용 붓 그림을 쓴다.
## 본체 원판은 decal (예: 바늘 없는 해시계 판), 띠는 strip 슬롯을 그대로 쓴다.
## 바늘 (오른쪽을 가리키는 가로 그림, 왼쪽 끝이 돌리는 축). 비면 코드 바늘.
@export var hand_art: Texture2D
## 바닥 자국 (금 간 바닥·물자국·불탄 자국). 비면 공용 먹 웅덩이를 ground_color로 물들여 씀.
@export var ground_art: Texture2D
## 흩어지는 조각 (물보라 덩어리·돌 조각·꽃잎…). 여러 장이면 번갈아. 비면 shape 모양 입자.
@export var part_art: Array[Texture2D] = []


## 판정 반경(px)에 맞춘 그림 지름.
func fitted_size(radius: float) -> float:
	return 2.0 * radius / maxf(art_fill, 0.1)


## 정점 색: r = 밝기, g = 일렁임, b = 감김/4, a = 남은 수명 (shaders/ink_decal.gdshader).
func ink_color(bright: float, life: float) -> Color:
	return Color(bright, clampf(flicker, 0.0, 1.0), clampf(twist / 4.0, 0.0, 1.0), life)


## t초 때 그릴 그림 (시트가 있으면 그 장, 없으면 decal).
func decal_at(t: float) -> Texture2D:
	if sheet:
		return VfxSheets.frame_at(sheet, sheet_cols, sheet_rows, sheet_count, sheet_fps, t, sheet_loop)
	return decal


func strip_at(t: float) -> Texture2D:
	if strip_sheet:
		return VfxSheets.frame_at(strip_sheet, sheet_cols, sheet_rows, sheet_count, sheet_fps, t, sheet_loop)
	return strip


## 그림이 있는지 (정지 그림 또는 시트).
func has_decal() -> bool:
	return decal != null or sheet != null
