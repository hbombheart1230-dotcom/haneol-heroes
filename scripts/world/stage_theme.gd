class_name StageTheme
extends Resource
## 무대 하나의 겉모습과 이름 (역사 속 전장). 바닥 색, 흩뿌릴 수묵 소품, 시작 문구.
## 무대 연표: docs/scenario.md 3.2.

@export var id: StringName = &""
## 시작 문구 윗줄 (예: "395년") / 아랫줄 (예: "만주 벌판").
@export var year_label: String = ""
@export var title: String = ""
@export_multiline var subtitle: String = ""
## 무대 배경 음악 (반복).
@export var music: AudioStream

@export_group("배경 지도")
## 무대 전체를 덮는 큰 그림 (tools/art/make_backgrounds.py). 경로로 두고 무대를 열 때만 불러온다
## (무대 고르기 화면이 네 무대를 다 들고 있어도 큰 그림은 메모리에 올라오지 않게).
@export_file("*.png") var background_path: String = ""
## 지도를 그릴 월드 영역. 걸어 다닐 부분이 전장(Arena.rect)에 맞게 만든다.
@export var background_rect: Rect2 = Rect2()
## 흩뿌리는 소품을 전장 가장자리에서 이만큼 띄운다 (지도 가장자리 그림과 겹치지 않게).
@export var prop_inset: float = 0.0
## 지도에 그려진 막히는 것들 (월드 x, y, 반지름). tools/art/make_backgrounds.py가 원본 픽셀에서 옮긴다.
@export var map_blockers: PackedVector3Array = PackedVector3Array()
## 흩뿌린 소품 중 막히는 것 (그림 파일 이름, 확장자 없이). 발밑에 원 충돌.
@export var solid_props: PackedStringArray = PackedStringArray()

@export_group("부서지는 물건")
## 깨면 탕약(체력 회복)이 나오는 물건. 비우면 없음.
@export var breakable: BreakableData

@export_group("적 (망령 군대)")
## 비어 있으면 장면(EnemySpawner)에 정해 둔 적을 그대로 쓴다.
@export var spawn_table: Array[EnemyData] = []
@export var spawn_weights: PackedFloat32Array = PackedFloat32Array()
@export var unlock_times: PackedFloat32Array = PackedFloat32Array()
@export var elite: EnemyData
@export var boss: EnemyData
## 고르기 화면 카드 그림 (없으면 첫 소품).
@export var card_art: Texture2D
## 이 무대의 주인공 (고르기 화면 표시용).
@export var hero_hint: String = ""

@export_group("바닥")
@export var floor_base: Color = Color(0.92, 0.88, 0.79)
@export var floor_stain: Color = Color(0.09, 0.09, 0.11)

@export_group("소품 (코드로 그리는 수묵)")
## 바닥 1000×1000px당 풀포기·바위 수.
@export var grass_per_mpx: float = 9.0
@export var rock_per_mpx: float = 1.6
@export var grass_color: Color = Color(0.25, 0.27, 0.16, 0.55)
@export var rock_color: Color = Color(0.2, 0.19, 0.17, 0.6)
@export_group("소품 (그림)")
## 사용자 그림에서 잘라 낸 소품 (바위·수레·깃발 등). 바닥에 흩뿌린다.
@export var prop_textures: Array[Texture2D] = []
## 바닥 1000×1000px당 그림 소품 수.
@export var picture_props_per_mpx: float = 3.0
## 그림 소품 표시 배율 범위.
@export var prop_scale_min: float = 0.55
@export var prop_scale_max: float = 0.8

## 시작 위치 주변은 비워 둔다 (px).
@export var clear_radius: float = 260.0
@export var seed: int = 395
