class_name FxLayer
extends Node2D
## 임시 전투 이펙트 (월드 좌표, _draw 기반). 정식 그래픽 아님.
## 링(해룡참 물결), 선(파도격 검기 잔상), 타격 불꽃을 짧게 그린다.

var _fx: Array[Dictionary] = []


func add_ring(pos: Vector2, radius: float, duration: float, color: Color) -> void:
	_fx.append({"kind": "ring", "pos": pos, "r": radius, "t": 0.0, "dur": duration, "color": color})


func add_slash(from: Vector2, to: Vector2, width: float, duration: float, color: Color) -> void:
	_fx.append({"kind": "slash", "a": from, "b": to, "w": width, "t": 0.0, "dur": duration, "color": color})


func add_spark(pos: Vector2, color: Color = Color(1, 1, 1)) -> void:
	_fx.append({"kind": "spark", "pos": pos, "t": 0.0, "dur": 0.15, "color": color})


## 데미지 숫자: 위로 떠오르며 사라진다. strong이면 크고 노랗게.
func add_number(pos: Vector2, amount: int, strong: bool = false) -> void:
	var jitter := Vector2(randf_range(-10, 10), 0)
	_fx.append({"kind": "number", "pos": pos + jitter, "n": amount, "strong": strong, "t": 0.0, "dur": 0.6,
		"color": Color(1, 0.85, 0.3) if strong else Color(1, 1, 1)})


func count() -> int:
	return _fx.size()


func _process(delta: float) -> void:
	for f in _fx:
		f["t"] = float(f["t"]) + delta
	_fx = _fx.filter(func(f: Dictionary) -> bool: return float(f["t"]) < float(f["dur"]))
	queue_redraw()


func _draw() -> void:
	for f in _fx:
		var k := float(f["t"]) / float(f["dur"])
		var c: Color = f["color"]
		match f["kind"]:
			"ring":
				var r := float(f["r"]) * (0.35 + 0.65 * k)
				draw_arc(f["pos"], r, 0, TAU, 48, Color(c, (1.0 - k) * 0.9), 14.0 * (1.0 - k) + 2.0)
				draw_arc(f["pos"], r * 0.8, 0, TAU, 48, Color(c, (1.0 - k) * 0.4), 6.0)
			"slash":
				draw_line(f["a"], f["b"], Color(c, (1.0 - k)), float(f["w"]) * (1.0 - k * 0.7))
				draw_line(f["a"], f["b"], Color(1, 1, 1, (1.0 - k) * 0.8), float(f["w"]) * 0.25)
			"number":
				var font := ThemeDB.fallback_font
				var size := 48 if f["strong"] else 34
				var p: Vector2 = f["pos"] + Vector2(-60, -50.0 * k - 30.0)
				draw_string_outline(font, p, str(f["n"]), HORIZONTAL_ALIGNMENT_CENTER, 120, size, 6, Color(0, 0, 0, 1.0 - k))
				draw_string(font, p, str(f["n"]), HORIZONTAL_ALIGNMENT_CENTER, 120, size, Color(c, 1.0 - k))
			"spark":
				var p: Vector2 = f["pos"]
				var s := 14.0 * (1.0 - k) + 4.0
				draw_line(p - Vector2(s, 0), p + Vector2(s, 0), Color(c, 1.0 - k), 3.0)
				draw_line(p - Vector2(0, s), p + Vector2(0, s), Color(c, 1.0 - k), 3.0)
