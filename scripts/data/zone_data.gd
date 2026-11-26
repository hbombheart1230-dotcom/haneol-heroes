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
