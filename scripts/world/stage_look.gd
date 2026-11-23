class_name StageLook
extends Resource
## 무대 "조명" 한 벌: 바닥 색 보정(shaders/floor_grade.gdshader) + 빛 웅덩이(LightPools).
## StageTheme.look에 넣으면 floor_value·floor_saturation 대신 쓴다. 비우면 예전 방식 그대로.

@export_group("바닥 색 보정")
@export var value_mult: float = 1.0
@export var saturation: float = 1.0
## 대비 배율과 기준 밝기 (pivot보다 밝은 곳은 더 밝게, 어두운 곳은 더 어둡게).
@export var contrast: float = 1.0
@export var pivot: float = 0.3
## 어두운 곳·밝은 곳에 입힐 색 (밝기는 그대로, 색만). tint_mix 0이면 안 입힌다.
@export var shadow_tint: Color = Color.WHITE
@export var light_tint: Color = Color.WHITE
@export var tint_mix: float = 0.0
@export var tint_split: float = 0.3

@export_group("바닥 결 (사진 재질 층)")
## 회색 결 그림 (0.5 = 그대로, tools/art/make_grain.py). 그린 바닥에 곱해 질감만 더한다 (색·판선은 그림 그대로).
## 같은 계열 무대(한산·명량·노량 등)가 같은 결을 다시 쓴다.
@export var detail_texture: Texture2D
## 결 한 칸 크기 (월드 px)와 세기 (0이면 없음).
@export var detail_px: float = 512.0
@export var detail_strength: float = 0.0

@export_group("가장자리 겹침 그림 (먹선·문양)")
## 지도와 같은 월드 영역에 얹는 투명 그림 (tools/art/make_hansan_edge.py: 한산 귀선도 먹선). 비우면 없음.
@export var overlay_texture: Texture2D
@export var overlay_alpha: float = 1.0

@export_group("소품 빛 (화톳불·등불)")
## 이 이름(그림 파일 이름, 확장자 없이)의 소품 둘레에 빛 웅덩이를 깐다.
@export var lit_props: PackedStringArray = PackedStringArray()
@export var prop_light_color: Color = Color(1.0, 0.6, 0.25, 0.8)
@export var prop_light_radius: float = 240.0
## 소품 발밑에서 빛 중심까지 (그림 아래 가운데 기준, 위로 올리면 불꽃 쪽).
@export var prop_light_offset: Vector2 = Vector2(0, -20)

@export_group("바닥 빛 웅덩이 (달빛 등)")
## 바닥 1000×1000px당 웅덩이 수 (0이면 없음).
@export var pools_per_mpx: float = 0.0
@export var pool_color: Color = Color(0.4, 0.8, 0.9, 0.35)
@export var pool_radius_min: float = 160.0
@export var pool_radius_max: float = 280.0
## 쿼터뷰라 웅덩이를 세로로 눌러 그린다.
@export var pool_squash: float = 0.6
## 웅덩이끼리 이 거리보다 붙지 않게.
@export var pool_spacing: float = 360.0

@export_group("영웅 발밑 빛")
## 알파 0이면 없음.
@export var hero_light_color: Color = Color(1.0, 0.85, 0.6, 0.0)
@export var hero_light_radius: float = 120.0
