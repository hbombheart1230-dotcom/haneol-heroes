class_name ComboTextData
extends Resource
## 연타 글씨 ("1타"~"4타", ComboCounter): 붓글씨 한지 톤, 타수가 오를수록 크게, 마무리(4타)는 인주색으로 가장 크게.
## 자리는 화면 비율 (영웅·적·피해 숫자를 가리지 않는 왼쪽 가운데 위), 연타가 끊기면 사라진다.

## 타마다 글 (1타부터). 마지막 칸 = 마무리.
@export var labels: PackedStringArray = PackedStringArray(["1타", "2타", "3타", "4타"])
## 타마다 글자 크기(px).
@export var sizes: PackedInt32Array = PackedInt32Array([44, 52, 62, 92])
## 화면 비율 자리 (글 가운데).
@export var anchor: Vector2 = Vector2(0.17, 0.36)
## 글 색 (한지)과 먹 외곽선 (피해 숫자와 같은 색, ImpactFeelData.number_color·number_outline_color), 마무리 글 색 (인주)과 외곽선 굵기.
@export var color: Color = Color(0.96, 0.93, 0.86, 1)
@export var outline: Color = Color(0.1, 0.08, 0.07, 1)
@export var finish_color: Color = Color(0.82, 0.16, 0.1, 1)
@export var outline_px: int = 10
## 글 뒤 먹 붓자국 (가로 길이 = 글 크기 × 이 값, 0이면 없음 = 기본: 회색 상자로 보여 사용자가 테두리만 골랐다)과 색.
@export var stroke_mult: float = 0.0
@export var stroke_color: Color = Color(0.09, 0.09, 0.11, 0.55)
## 뜰 때 이 배율에서 1로 (초), 마무리는 더 크게.
@export var pop_scale: float = 1.5
@export var finish_pop_scale: float = 2.0
@export var pop_time: float = 0.12
## 연타가 끊긴 뒤 (마무리는 뜬 뒤 finish_hold초) 이 시간 동안 옅어진다.
@export var fade_time: float = 0.25
@export var finish_hold: float = 0.7
## 연타가 끊겼다고 보는 시간 (마지막 타 뒤, 초). 0 이하면 영웅 kit.combo_window.
@export var break_time: float = -1.0
