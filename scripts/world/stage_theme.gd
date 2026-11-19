class_name StageTheme
extends Resource
## 무대 하나의 겉모습과 이름 (역사 속 전장). 바닥 색, 흩뿌릴 수묵 소품, 시작 문구.
## 무대 연표: docs/scenario.md 3.2.

@export var id: StringName = &""
## 시작 문구 윗줄 (예: "395년") / 아랫줄 (예: "만주 벌판").
@export var year_label: String = ""
@export var title: String = ""
@export_multiline var subtitle: String = ""

@export_group("바닥")
@export var floor_base: Color = Color(0.92, 0.88, 0.79)
@export var floor_stain: Color = Color(0.09, 0.09, 0.11)

@export_group("소품 (코드로 그리는 수묵)")
## 바닥 1000×1000px당 풀포기·바위 수.
@export var grass_per_mpx: float = 9.0
@export var rock_per_mpx: float = 1.6
@export var grass_color: Color = Color(0.25, 0.27, 0.16, 0.55)
@export var rock_color: Color = Color(0.2, 0.19, 0.17, 0.6)
## 시작 위치 주변은 비워 둔다 (px).
@export var clear_radius: float = 260.0
@export var seed: int = 395
