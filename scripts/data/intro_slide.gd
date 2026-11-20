class_name IntroSlide
extends Resource
## 이야기 인트로의 한 장면: 그림 한 장 + 위쪽 연도 글 + 아래에서 하나씩 떠오르는 줄들.

@export var image: Texture2D
## 그림에 덧칠할 색 (망령 장면을 어둡게·푸르게 등). 흰색이면 그대로.
@export var tint: Color = Color.WHITE
## 위쪽 붓글씨 (예: "서기 395년"). 비우면 없음.
@export var caption: String = ""
@export var lines: PackedStringArray = PackedStringArray()
## 이 장면 길이(초). 줄은 이 안에서 고르게 나온다.
@export var duration: float = 7.0
## 천천히 다가가기: 시작·끝 배율과 끝에서 화면 비율만큼 옮겨 가는 거리.
@export var zoom_from: float = 1.0
@export var zoom_to: float = 1.08
@export var pan: Vector2 = Vector2(0.0, -0.03)
