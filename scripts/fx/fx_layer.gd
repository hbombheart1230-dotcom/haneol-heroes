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
	_fx.append({"kind": "spark", "pos": pos, "t": 0.0, "dur": 0.22, "color": color, "seed": randf() * 10.0})


## 꺾인 번개 줄기 a→b: 마디마다 옆으로 흔든 점을 한 번만 만들어 두고 (그릴 때 배열을 만들지 않음),
## 넓고 옅은 빛 + 가는 흰 심지로 그린다.
func add_bolt(from: Vector2, to: Vector2, width: float, duration: float, color: Color, segments: int = 6,
		jitter: float = 26.0) -> void:
	var pts := PackedVector2Array()
	var n := maxi(segments, 1)
	var side := (to - from).orthogonal().normalized()
	for i in n + 1:
		var k := float(i) / n
		var off := 0.0 if i == 0 or i == n else randf_range(-jitter, jitter)
		pts.append(from.lerp(to, k) + side * off)
	_fx.append({"kind": "bolt", "pts": pts, "w": width, "t": 0.0, "dur": duration, "color": color})


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
			"ring":  # 물결 먹선 (해룡참·반격)
				var r := float(f["r"]) * (0.35 + 0.65 * k)
				Ink.ring(self, f["pos"], r, 16.0 * (1.0 - k) + 3.0, Color(c.darkened(0.35), (1.0 - k) * 0.85))
				Ink.ring(self, f["pos"], r * 0.8, 6.0, Color(Ink.INK, (1.0 - k) * 0.35), 0.6, 2.0)
			"slash":  # 붓 획 검기
				Ink.stroke(self, f["a"], f["b"], float(f["w"]) * (1.0 - k * 0.6), Color(c.darkened(0.3), 1.0 - k))
				Ink.stroke(self, f["a"], f["b"], float(f["w"]) * 0.3, Color(Ink.INK, (1.0 - k) * 0.7))
			"number":
				var font := UiStyle.TITLE_FONT
				var size := 48 if f["strong"] else 34
				var p: Vector2 = f["pos"] + Vector2(-60, -50.0 * k - 30.0)
				var ink_col := Ink.SEAL if f["strong"] else Ink.INK
				draw_string_outline(font, p, str(f["n"]), HORIZONTAL_ALIGNMENT_CENTER, 120, size, 6, Color(Ink.PAPER, 1.0 - k))
				draw_string(font, p, str(f["n"]), HORIZONTAL_ALIGNMENT_CENTER, 120, size, Color(ink_col, 1.0 - k))
			"bolt":  # 꺾인 번개: 넓은 빛 + 흰 심지
				var pts: PackedVector2Array = f["pts"]
				var st := Feedback.feel_data()
				var w := float(f["w"]) * (1.0 - k * st.bolt_thin)
				draw_polyline(pts, Color(c, (1.0 - k) * st.bolt_glow_alpha), w * st.bolt_glow_width)
				draw_polyline(pts, Color(c, 1.0 - k), w * st.bolt_body_width)
				draw_polyline(pts, Color(1, 1, 1, 1.0 - k), w * st.bolt_core_width)
			"spark":  # 먹물 튀김
				var p: Vector2 = f["pos"]
				Ink.splash(self, p, 10.0 + 14.0 * k, Color(Ink.INK, (1.0 - k) * 0.8), float(f.get("seed", 0.0)))
