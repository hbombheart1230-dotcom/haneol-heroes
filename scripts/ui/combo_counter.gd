class_name ComboCounter
extends Control
## 연타 글씨 (사용자: "연타를 1타 2타 3타 4타 이렇게 콤보 넣는 글씨"): 손 평타가 닿을 때마다 "1타"·"2타"·"3타",
## 넷째 탭 마무리에 "4타" (SkillCaster.combo_count). 붓글씨 한지 톤, 타수가 오를수록 크게, 마무리는 인주색으로 가장 크게.
## 화면 왼쪽 가운데 위 (영웅·적·피해 숫자를 가리지 않게), 연타가 끊기면 옅어진다. 설정 "연타 글씨"로 끈다.
## 글은 데이터에 미리 있는 것을 그대로 그린다 (프레임마다 문자열·배열 할당 없음).

const DATA_PATH := "res://data/ui/combo_text.tres"
const FONT := preload("res://assets/fonts/DeogonPrincess.ttf")

@export var caster: SkillCaster
@export var data: ComboTextData

## 지금 보이는 타 (0 = 없음), 뜬 뒤 흐른 시간, 투명도, 마무리인지.
var _n: int = 0
var _age: float = 0.0
var _alpha: float = 0.0
var _finish: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if data == null:
		data = load(DATA_PATH) as ComboTextData
	bind(caster)


func bind(c: SkillCaster) -> void:
	if caster and caster.combo_count.is_connected(show_count):
		caster.combo_count.disconnect(show_count)
	caster = c
	if caster and not caster.combo_count.is_connected(show_count):
		caster.combo_count.connect(show_count)


## n타 (1부터, 마지막 칸 = 마무리).
func show_count(n: int) -> void:
	if not GameSettings.combo_text or data == null or data.labels.is_empty():
		return
	_n = clampi(n, 1, data.labels.size())
	_finish = _n == data.labels.size()
	_age = 0.0
	_alpha = 1.0
	queue_redraw()


func shown() -> int:
	return _n


func alpha() -> float:
	return _alpha


## 연타가 끊겼는지: 마무리는 finish_hold초 뒤, 그 밖은 연계가 풀리면 (TapCombo.streak 0) 또는 break_time.
func _broken() -> bool:
	if _finish:
		return _age > data.finish_hold
	if data.break_time > 0.0:
		return _age > data.break_time
	return caster == null or caster.combo.streak == 0


func _process(delta: float) -> void:
	if _n == 0:
		return
	_age += delta
	if not GameSettings.combo_text:
		_alpha = 0.0
	elif _broken():
		_alpha -= delta / maxf(data.fade_time, 0.001)
	if _alpha <= 0.0:
		_n = 0
		_alpha = 0.0
	queue_redraw()


func _draw() -> void:
	if _n == 0 or data == null:
		return
	var i := _n - 1
	var px := data.sizes[mini(i, data.sizes.size() - 1)] if not data.sizes.is_empty() else 48
	var vp := size if size.x > 0.0 else get_viewport_rect().size
	var at := vp * data.anchor
	var k := clampf(_age / maxf(data.pop_time, 0.001), 0.0, 1.0)
	var pop := lerpf(data.finish_pop_scale if _finish else data.pop_scale, 1.0, 1.0 - (1.0 - k) * (1.0 - k))
	draw_set_transform(at, 0.0, Vector2(pop, pop))
	if data.stroke_mult > 0.0:  # 글 뒤 먹 붓자국
		var half := px * data.stroke_mult * 0.5
		draw_line(Vector2(-half, -px * 0.32), Vector2(half, -px * 0.4), Color(data.stroke_color, data.stroke_color.a * _alpha), px * 0.9)
	var col := data.finish_color if _finish else data.color
	var w := px * 4.0
	UiStyle.text(self, FONT, Vector2(-w * 0.5, 0.0), data.labels[i], px, Color(col, col.a * _alpha), w,
		data.outline, data.outline_px)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
