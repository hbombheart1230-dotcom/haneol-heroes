class_name AnswerCueLayer
extends Node2D
## 정답 표 글자 ("통!"·"튕김") 그리는 층: 큰 기술 그림(FxLayer 자식들) 위에 보이게 절대 z (AnswerCueData.layer_z).
## Feedback.fx 밑에 하나만 붙는다 (AnswerCue.layer). 글자는 떠오르며 흐려진다.

var data: AnswerCueData
var _items: Array[Dictionary] = []


func _init(d: AnswerCueData) -> void:
	data = d
	z_as_relative = false
	z_index = d.layer_z


func add(pos: Vector2, text: String, color: Color, size_mult: float) -> void:
	_items.append({"pos": pos, "text": text, "color": color, "size": int(data.label_size * size_mult), "t": 0.0})
	queue_redraw()


func _process(delta: float) -> void:
	if _items.is_empty():
		return
	for f in _items:
		f["t"] = float(f["t"]) + delta
	_items = _items.filter(func(f: Dictionary) -> bool: return float(f["t"]) < data.label_time)
	queue_redraw()


func _draw() -> void:
	for f in _items:
		var k := float(f["t"]) / maxf(data.label_time, 0.01)
		var pop := 1.0 + 0.3 * maxf(1.0 - float(f["t"]) / 0.08, 0.0)  # 막 뜬 순간 톡
		var p: Vector2 = (f["pos"] as Vector2) + Vector2(0, -data.label_rise * k)
		draw_set_transform(p, 0.0, Vector2.ONE * pop)
		draw_string_outline(UiStyle.TITLE_FONT, Vector2(-100, 0), f["text"], HORIZONTAL_ALIGNMENT_CENTER, 200, f["size"],
			data.outline_px, Color(data.outline_color, 1.0 - k))
		draw_string(UiStyle.TITLE_FONT, Vector2(-100, 0), f["text"], HORIZONTAL_ALIGNMENT_CENTER, 200, f["size"],
			Color(f["color"], 1.0 - k))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
