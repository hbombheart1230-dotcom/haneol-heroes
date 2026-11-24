class_name ComboTextData
extends Resource
## 연타 글씨 ("1타", "2타"… ComboCounter): 붓글씨 한지 톤, 타수가 오를수록 크게 (상한 있음), 마무리는 인주색으로 크게.
## 자리는 화면 비율 (영웅·적·피해 숫자를 가리지 않는 왼쪽 가운데 위), 연타가 끊기면 사라진다.

## 글 모양 (%d = 타수). 칼·내닫기 타격·기술 어느 것이든 적을 맞히면 하나씩 오른다 (5타, 6타…).
@export var label_format: String = "%d타"
## 글자 크기(px): 1타 size_base에서 타마다 size_step씩, size_max까지 (다단 기술로 수십 타가 돼도 화면을 덮지 않게).
## 마무리(넷째 탭 기술)가 맞힌 동안은 finish_size.
@export var size_base: int = 44
@export var size_step: int = 6
@export var size_max: int = 72
@export var finish_size: int = 84
## 화면 비율 자리 (글 가운데).
@export var anchor: Vector2 = Vector2(0.17, 0.36)
## 글 색 (한지)과 먹 외곽선 (피해 숫자와 같은 색, ImpactFeelData.number_color·number_outline_color), 마무리 글 색 (인주)과 외곽선 굵기.
@export var color: Color = Color(0.96, 0.93, 0.86, 1)
@export var outline: Color = Color(0.1, 0.08, 0.07, 1)
@export var finish_color: Color = Color(0.92, 0.72, 0.22, 1)  # 금빛 (붉은 인주는 적 위험 전용)
@export var outline_px: int = 10
## 글 뒤 먹 붓자국 (가로 길이 = 글 크기 × 이 값, 0이면 없음 = 기본: 회색 상자로 보여 사용자가 테두리만 골랐다)과 색.
@export var stroke_mult: float = 0.0
@export var stroke_color: Color = Color(0.09, 0.09, 0.11, 0.55)
## 뜰 때 이 배율에서 1로 (초), 마무리는 더 크게. pop_min_gap초 안에 또 맞으면 숫자만 바꾸고 다시 튀지 않는다 (다단 타격).
@export var pop_scale: float = 1.5
@export var finish_pop_scale: float = 2.0
@export var pop_time: float = 0.12
@export var pop_min_gap: float = 0.15
## 연타가 끊긴 뒤 이 시간 동안 옅어진다 (숫자는 끊기는 순간 0). 마무리 색은 finish_hold초 동안.
@export var fade_time: float = 0.25
@export var finish_hold: float = 0.7
## 연타가 끊겼다고 보는 시간 (마지막으로 맞힌 뒤, 초). 0 이하면 영웅 kit.combo_window (연타 유지 시간).
@export var break_time: float = -1.0
