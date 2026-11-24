class_name TutorialData
extends Resource
## 첫 판 조작 안내 (data/tutorial/controls.tres). 단계 순서대로, 해 보면 넘어간다.

@export var steps: Array[TutorialStep] = []
## 다 끝나면 잠깐 띄우는 글.
@export var finish_caption: String = "전장으로!"
## 연습 상대를 세우는 자리 (플레이어 위쪽으로 이만큼, px)와 쓰러진 뒤 다시 나오기까지(초).
@export var practice_distance: float = 240.0
@export var practice_respawn: float = 1.2
## 연습 상대는 체력이 이 비율 아래로 내려가면 가득 채워진다 (더 빨라진 평타·기술에도 단계를 끝내기 전에 쓰러지지 않게).
@export_range(0.1, 0.9) var practice_refill_below: float = 0.5
