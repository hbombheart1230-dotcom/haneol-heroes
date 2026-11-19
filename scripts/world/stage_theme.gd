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
## 보스가 나오면 바꿔 트는 곡 (반복). 비우면 무대 곡을 그대로.
@export var boss_music: AudioStream
## 판이 끝났을 때 한 번 트는 짧은 곡. 비우면 무대 곡을 그대로.
@export var victory_music: AudioStream
@export var defeat_music: AudioStream

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
