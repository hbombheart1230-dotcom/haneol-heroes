class_name ZoneData
extends Resource
## 전장 안 구역 하나 (하데스의 섬 건너뛰기: 한산은 우리 배 → 왜 적선 → 대장선). StageTheme.zones 차례대로 지나간다.
## 구역의 물결을 다 깨면 다음 구역 쪽 화살이 뜨고, 그쪽으로 내닫으면 뛰어넘는다 (ZoneHop).

## 넘어올 때 화면 가운데 띄울 이름 (예: "왜 적선").
@export var title: String = ""
## 이 구역에서 치르는 물결 수 (WaveSetData.waves 차례대로 이어 센다). 마지막 구역은 남은 물결과 우두머리.
@export var waves: int = 1
## 배경 위에 덮는 색 (임시 색판: 같은 갑판 그림을 구역마다 다른 색으로, 알파 = 세기). 투명 = 그대로.
@export var wash: Color = Color(0, 0, 0, 0)
## 걸을 수 있는 곳 (WalkArea 다각형). 비면 무대 walk_area 그대로.
@export var walk_area: PackedVector2Array = PackedVector2Array()
## 다음 구역 방향 (화살 표시, 이쪽으로 내닫으면 넘어간다). 마지막 구역은 쓰지 않는다.
@export var exit_dir: Vector2 = Vector2.UP
## 이 구역으로 넘어와 내려앉는 자리 (전장 좌표).
@export var entry: Vector2 = Vector2(0, 900)
## 화살 옆 안내 (비면 "<다음 구역 이름> 쪽으로 내닫기").
@export var prompt: String = ""

@export_group("배 그림")
## 이 구역 바닥 그림 (res:// 경로, 비면 무대 그림 그대로). 같은 전장 영역에 놓는다 (StageTheme.background_rect).
@export var background_path: String = ""
## 이 배의 바닥 색 입힘·빛 웅덩이 (비면 무대 look 그대로). 배마다 달라 보이게: 한산 중형선 검은 옻칠·연기, 대장선 노을.
@export var look: StageLook
## 무대 소품(대포·통 등)을 이 구역에도 두는지. 다른 배 그림 위에는 끈다 (그림에 갑판 물건이 그려져 있다).
@export var props: bool = true
## 그림에 그려진 막는 것 (x, y, 반지름) — 소품을 끄면 이것만 막는다.
@export var blockers: PackedVector3Array = PackedVector3Array()

@export_group("우두머리")
## 이 구역에서 우두머리가 나오는 자리를 정하는지 (끄면 영웅 둘레 아무 데나). 한산 대장선은 누각 계단 위.
@export var has_boss_at: bool = false
## 우두머리가 나오는 자리 (전장 좌표, 걸을 수 있는 곳 안).
@export var boss_at: Vector2 = Vector2.ZERO

@export_group("뛰어넘기")
## 뛰어넘는 난간 자리 (전장 좌표, 여럿이면 가까운 곳). 비면 exit_dir 쪽 아무 데서나.
## 한산 중형선 → 대장선: 안 B(계단 밟고 선실 지붕 넘기) 한 점이 기본, 안 A는 지붕 옆 모서리 둘 — 데이터만 바꿔 고른다.
@export var exits: PackedVector2Array = PackedVector2Array()
## 난간 자리에서 이 거리(px) 안에서 그쪽으로 내닫아야 넘어간다.
@export var exit_reach: float = 480.0
