class_name FxLayer
extends Node2D
## 임시 전투 이펙트 (월드 좌표, _draw 기반). 정식 그래픽 아님.
## 링(해룡참 물결), 선(파도격 검기 잔상), 타격 불꽃을 짧게 그린다.

var _fx: Array[Dictionary] = []


func add_ring(pos: Vector2, radius: float, duration: float, color: Color) -> void:
	_fx.append({"kind": "ring", "pos": pos, "r": radius, "t": 0.0, "dur": duration, "color": color, "seed": randf() * TAU})


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


## 하늘에서 떨어지는 그림 (유성): from → to를 duration초 동안 점점 빠르게. angle_deg = 그림이 원래 날아가는 방향.
func add_fall(tex: Texture2D, from: Vector2, to: Vector2, duration: float, size: float, angle_deg: float = 0.0) -> void:
	if tex == null:
		return
	_fx.append({"kind": "fall", "tex": tex, "a": from, "b": to, "t": 0.0, "dur": maxf(duration, 0.01), "size": size,
		"rot": (to - from).angle() - deg_to_rad(angle_deg), "color": Color.WHITE})


## 데미지 숫자: 위로 떠오르며 사라진다. strong이면 크고 노랗게.
func add_number(pos: Vector2, amount: int, strong: bool = false) -> void:
	var jitter := Vector2(randf_range(-10, 10), 0)
	_fx.append({"kind": "number", "pos": pos + jitter, "n": amount, "strong": strong, "t": 0.0, "dur": 0.6,
		"color": Color(1, 0.85, 0.3) if strong else Color(1, 1, 1)})


## 붓 그림 하나를 가운데 맞춰 돌려 그린다. 그림이 없으면 false (코드 그림으로 대신).
func _tex_draw(tex: Texture2D, pos: Vector2, size: float, rot: float, col: Color) -> bool:
	if tex == null:
		return false
	draw_set_transform(pos, rot, Vector2.ONE)
	draw_texture_rect(tex, Rect2(-size * 0.5, -size * 0.5, size, size), false, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


func count() -> int:
	return _fx.size()


func _process(delta: float) -> void:
	for f in _fx:
		f["t"] = float(f["t"]) + delta
	_fx = _fx.filter(func(f: Dictionary) -> bool: return float(f["t"]) < float(f["dur"]))
	queue_redraw()


func _draw() -> void:
	var feel := Feedback.feel_data()
	for f in _fx:
		var k := float(f["t"]) / float(f["dur"])
		var c: Color = f["color"]
		match f["kind"]:
			"ring":  # 범위·예고: 붓으로 그린 고리 그림을 기술 색으로 (그림이 없으면 먹선)
				var r := float(f["r"]) * (0.35 + 0.65 * k)
				if not _tex_draw(feel.ring_art, f["pos"], r * 2.3, float(f.get("seed", 0.0)) + k, Color(c, 1.0 - k)):
					Ink.ring(self, f["pos"], r, 16.0 * (1.0 - k) + 3.0, Color(c.darkened(0.35), (1.0 - k) * 0.85))
			"slash":  # 붓 획 검기
				var a2: Vector2 = f["a"]
				var d2: Vector2 = (f["b"] as Vector2) - a2
				var w2 := float(f["w"]) * (1.0 - k * 0.6) * 2.4
				if feel.stroke_art:
					draw_set_transform(a2, d2.angle(), Vector2.ONE)
					draw_texture_rect(feel.stroke_art, Rect2(0.0, -w2 * 0.5, d2.length(), w2), false, Color(c, 1.0 - k))
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				else:
					Ink.stroke(self, a2, f["b"], float(f["w"]) * (1.0 - k * 0.6), Color(c.darkened(0.3), 1.0 - k))
			"fall":  # 떨어지는 유성: 가속하며 내려온다
				var tex: Texture2D = f["tex"]
				var p: Vector2 = (f["a"] as Vector2).lerp(f["b"], k * k)
				var s := float(f["size"])
				draw_set_transform(p, float(f["rot"]), Vector2.ONE)
				draw_texture_rect(tex, Rect2(-s * 0.5, -s * 0.5, s, s), false)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"bolt":  # 꺾인 번개: 넓은 빛 + 흰 심지
				var pts: PackedVector2Array = f["pts"]
				var st := Feedback.feel_data()
				var w := float(f["w"]) * (1.0 - k * st.bolt_thin)
				draw_polyline(pts, Color(c, (1.0 - k) * st.bolt_glow_alpha), w * st.bolt_glow_width)
				draw_polyline(pts, Color(c, 1.0 - k), w * st.bolt_body_width)
				draw_polyline(pts, Color(1, 1, 1, 1.0 - k), w * st.bolt_core_width)
			"spark":  # 타격 튐: 물보라 붓 그림
				var p3: Vector2 = f["pos"]
				if not _tex_draw(feel.splat_art, p3, 36.0 + 30.0 * k, float(f.get("seed", 0.0)), Color(c, (1.0 - k) * 0.9)):
					Ink.splash(self, p3, 10.0 + 14.0 * k, Color(Ink.INK, (1.0 - k) * 0.8), float(f.get("seed", 0.0)))
