class_name FxLayer
extends Node2D
## 임시 전투 이펙트 (월드 좌표, _draw 기반). 정식 그래픽 아님.
## 링(해룡참 물결), 선(파도격 검기 잔상), 타격 불꽃을 짧게 그린다.

var _fx: Array[Dictionary] = []
## 0이 아니면 다음 피해 숫자를 이 열쇠(적 id)의 숫자에 더한다 (WaveRake가 타 직전에 넣고 바로 지운다: 다다닥 쌓이는 합산 숫자).
static var stack_key: int = 0
## 패 고르기 화면이 떠 있는 동안 피해 숫자·글자를 그리지 않는다 (SealChoice).
static var numbers_hidden: bool = false
## 쌓인 숫자는 타마다 이만큼 커진다 (최대 STACK_GROW_MAX배, 글꼴 크기는 그대로 늘려 그림).
const STACK_GROW := 0.07
const STACK_GROW_MAX := 1.6


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


## 피해 숫자 (B6): 위로 떠오르며 사라진다. style 0 = 보통 먹색, 1 = 큰 피해 인장색, 2 = 3타째 강타 금빛·가장 크게.
func add_number(pos: Vector2, amount: int, style: int = 0) -> void:
	var d := Feedback.feel_data().impact_data()
	if stack_key != 0 and _stack(stack_key, amount):
		return
	if number_count() >= d.max_numbers:
		return  # 떼거리에서 숫자가 화면을 덮지 않게
	var col := d.number_color_heavy if style == 2 else (d.number_color_big if style == 1 else d.number_color)
	var size := d.number_size_heavy if style == 2 else (d.number_size_big if style == 1 else d.number_size)
	_fx.append({"kind": "number", "pos": pos + Vector2(randf_range(-10, 10), 0), "text": str(amount), "size": size,
		"t": 0.0, "dur": d.number_time, "color": col})


## 같은 열쇠의 숫자에 더한다 (살아 있으면). 반환: 더했으면 true.
func _stack(key: int, amount: int) -> bool:
	for f in _fx:
		if f["kind"] == "number" and int(f.get("key", 0)) == key and float(f["t"]) < float(f["dur"]):
			f["total"] = int(f.get("total", int(f["text"]))) + amount
			f["text"] = str(f["total"])
			f["hits"] = int(f.get("hits", 1)) + 1
			f["t"] = 0.0
			return true
	return false


## 방금 생긴 숫자(pos 근처)에 열쇠를 붙인다: 이어지는 타가 이 숫자에 쌓인다 (물결 첫 타는 HitBox가 넣어 열쇠가 없다).
static func tag_last_number(key: int, pos: Vector2) -> void:
	var fb := Feedback.instance
	var l: FxLayer = fb.fx if fb else null
	if l == null:
		return
	for i in range(l._fx.size() - 1, -1, -1):
		var f := l._fx[i]
		if f["kind"] == "number" and float(f["t"]) < 0.05 and (f["pos"] as Vector2).distance_to(pos) < 60.0:
			f["key"] = key
			return


## 반격·뒤치기 글자: 숫자보다 조금 위에서 떠오른다.
func add_label(pos: Vector2, text: String, color: Color) -> void:
	var d := Feedback.feel_data().impact_data()
	_fx.append({"kind": "number", "pos": pos + Vector2(0, -34), "text": text, "size": d.label_size, "t": 0.0,
		"dur": d.number_time * 1.3, "color": color})


## 붓 그림 하나를 가운데 맞춰 돌려 그린다. 그림이 없으면 false (코드 그림으로 대신).
func _tex_draw(tex: Texture2D, pos: Vector2, size: float, rot: float, col: Color) -> bool:
	if tex == null:
		return false
	draw_set_transform(pos, rot, Vector2.ONE)
	var feel := Feedback.feel_data()
	if feel.fx_ink_outline > 0.0:  # 먹 외곽선: 같은 그림을 조금 크게 먹색으로 먼저 (밝은 바닥에서 테두리)
		var o := size * feel.fx_ink_outline_scale
		draw_texture_rect(tex, Rect2(-o * 0.5, -o * 0.5, o, o), false, Color(Ink.INK, col.a * feel.fx_ink_outline))
	draw_texture_rect(tex, Rect2(-size * 0.5, -size * 0.5, size, size), false, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


func count() -> int:
	return _fx.size()


func number_count() -> int:
	var n := 0
	for f in _fx:
		if f["kind"] == "number":
			n += 1
	return n


func _process(delta: float) -> void:
	for f in _fx:
		f["t"] = float(f["t"]) + delta
	_fx = _fx.filter(func(f: Dictionary) -> bool: return float(f["t"]) < float(f["dur"]))
	queue_redraw()


func _draw() -> void:
	var feel := Feedback.feel_data()
	for f in _fx:
		if numbers_hidden and f["kind"] == "number":
			continue
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
			"number":  # 피해 숫자·글자: 종이색 테두리 + 먹·인장색 글씨, 떠오르며 흐려짐
				var im := feel.impact_data()
				var np: Vector2 = (f["pos"] as Vector2) + Vector2(-80, -im.number_rise * k - 30.0)
				var fs := int(f["size"])
				if f.has("key"):  # 쌓이는 숫자: 타마다 커지고, 막 더해진 순간 톡 튄다 (늘려 그림)
					var grow := minf(1.0 + STACK_GROW * (int(f.get("hits", 1)) - 1), STACK_GROW_MAX)
					grow *= 1.0 + 0.25 * maxf(1.0 - float(f["t"]) / 0.1, 0.0)
					draw_set_transform(np + Vector2(80, 0), 0.0, Vector2.ONE * grow)
					np = Vector2(-80, 0)
				draw_string_outline(UiStyle.TITLE_FONT, np, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 160, fs,
					im.number_outline, Color(im.number_outline_color, 1.0 - k))
				draw_string(UiStyle.TITLE_FONT, np, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 160, fs, Color(c, 1.0 - k))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"spark":  # 타격 튐: 물보라 붓 그림
				var p3: Vector2 = f["pos"]
				if not _tex_draw(feel.splat_art, p3, 36.0 + 30.0 * k, float(f.get("seed", 0.0)), Color(c, (1.0 - k) * 0.9)):
					Ink.splash(self, p3, 10.0 + 14.0 * k, Color(Ink.INK, (1.0 - k) * 0.8), float(f.get("seed", 0.0)))
