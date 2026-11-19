class_name IntroData
extends Resource
## 입장 뒤 이야기 인트로 (첫 실행에 한 번, 건너뛰기 가능). 장면·글·음악은 데이터로만 바꾼다.

@export var slides: Array[IntroSlide] = []
## 인트로 동안 깔 음악. 비우면 지금 음악을 그대로 둔다.
@export var music: AudioStream
## 장면 사이 먹빛으로 어두워졌다 밝아지는 시간(초).
@export var fade: float = 0.8
