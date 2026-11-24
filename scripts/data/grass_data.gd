class_name GrassData
extends StageHazardData
## 풀숲 (초충도): 먹으로 그린 풀숲 면에 영웅이 들어가면 반쯤 비치고, 잡몹·정예는 겨냥을 놓친다 (들어간 자리로 가서
## 두리번거린다, 쏘지도 휘두르지도 않는다 — 바로 곁 sense_range 안이면 그래도 안다). 우두머리는 속지 않는다.
## 숨은 채로, 또는 나온 뒤 ambush_window초 안에 친 첫 공격은 기습 (피해 ×ambush_mult, 금빛 "기습").
## 친 뒤에는 reveal_time초 동안 드러난다. 박자 없음 (공통 period 등은 쓰지 않는다).

## 풀숲: (월드 x, 월드 y, 반지름).
@export var patches: PackedVector3Array = PackedVector3Array()
@export var sense_range: float = 70.0
@export var ambush_mult: float = 1.5
@export var ambush_window: float = 1.2
@export var reveal_time: float = 1.5
## 숨었을 때 영웅 그림 진하기.
@export var hidden_alpha: float = 0.5
@export_group("그림·소리")
@export var grass_color: Color = Color(0.22, 0.3, 0.16, 0.85)
@export var grass_light: Color = Color(0.45, 0.55, 0.28, 0.8)
## 풀포기 수 (반지름 100px당).
@export var blades_per_100: float = 14.0
@export var rustle_sfx: StringName = &"w_brush"
@export var ambush_sfx: StringName = &"gugak_bang"
@export var ambush_color: Color = Color(1.0, 0.82, 0.3)
@export var ambush_word: String = "기습"


func make() -> Node2D:
	return GrassHide.new(self)
