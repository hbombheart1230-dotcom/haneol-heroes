class_name TutorialData
extends Resource
## 첫 판 조작 안내 (data/tutorial/controls.tres). 단계 순서대로, 해 보면 넘어간다.

@export var steps: Array[TutorialStep] = []
## 다 끝나면 잠깐 띄우는 글.
@export var finish_caption: String = "전장으로!"
