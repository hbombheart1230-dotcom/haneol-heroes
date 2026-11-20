class_name KillFx
extends Node2D
## 처치·타격 이펙트: 날아가는 시체, 땅에 남는 먹 자국, 먹물 방울, 군대별 죽음 모양 (연기·조각난 종이).
## 한 노드의 _draw로 모두 그린다 (노드를 만들지 않아 모바일에서 가볍다). 개수 상한은 CombatFeelData.

const SMOKE := Color(0.35, 0.55, 0.85)

var feel: CombatFeelData
## {flight, tex, scale, offset, tint, t, style, finisher}
var _corpses: Array[Dictionary] = []
## {pos, vel, t, life, r, color}
var _drops: Array[Dictionary] = []
## 연기 덩이·종이 조각·먹 자국: {kind, pos, vel, t, life, r, seed, rot, spin, color}
var _bits: Array[Dictionary] = []


func _init(p_feel: CombatFeelData = null) -> void:
	feel = p_feel if p_feel else CombatFeelData.new()


func corpse_count() -> int:
	return _corpses.size()


func drop_count() -> int:
	return _drops.size()


func bit_count() -> int:
	return _bits.size()


## 시체 날리기. tex가 없으면(코드 그림 적) 바로 죽음 모양만 터뜨린다.
func launch(pos: Vector2, dir: Vector2, last_damage: int, tex: Texture2D, sprite_scale: float,
		sprite_offset: Vector2, tint: Color, style: StringName, launch_scale: float = 1.0, finisher: bool = false) -> void:
	if tex == null:
		death_burst(pos, style, finisher)
		return
	var flight := CorpseFlight.new(pos, dir, feel.launch_distance(last_damage, launch_scale), feel.launch_height,
		feel.launch_time, feel.launch_spins)
	_corpses.append({"flight": flight, "tex": tex, "scale": sprite_scale, "offset": sprite_offset, "tint": tint,
		"t": 0.0, "style": style, "finisher": finisher})
	while _corpses.size() > maxi(feel.max_corpses, 1):
		var old: Dictionary = _corpses.pop_front()
		var f: CorpseFlight = old["flight"]
		death_burst(f.ground(old["t"]), old["style"], false)


## 먹물 방울: dir 쪽으로 부채꼴로 튄다.
func drops(pos: Vector2, dir: Vector2, n: int, color: Color = Ink.INK) -> void:
	var base := dir.normalized() if dir.length_squared() > 0.0001 else Vector2.UP
	for i in n:
		var v := base.rotated(randf_range(-0.9, 0.9)) * randf_range(120.0, 320.0)
		_drops.append({"pos": pos + Vector2(0, -16), "vel": v, "t": 0.0, "life": randf_range(0.3, 0.5),
			"r": randf_range(3.0, 6.5), "color": color})
	while _drops.size() > maxi(feel.max_drops, 0):
		_drops.pop_front()


## 군대별 죽음 모양 + 먹 자국.
func death_burst(pos: Vector2, style: StringName, finisher: bool = false) -> void:
	_bits.append({"kind": "mark", "pos": pos, "t": 0.0, "life": feel.mark_time, "r": 26.0 if not finisher else 48.0,
		"seed": randf() * 10.0})
	var n := feel.kill_drops * (2 if finisher else 1)
	if style == &"paper":
		drops(pos, Vector2.UP, n / 2)
		for i in 6 if not finisher else 12:
			_bits.append({"kind": "paper", "pos": pos + Vector2(randf_range(-14, 14), -20), "t": 0.0,
				"vel": Vector2(randf_range(-160, 160), randf_range(-220, -80)), "life": randf_range(0.5, 0.8),
				"r": randf_range(6.0, 11.0), "rot": randf() * TAU, "spin": randf_range(-9.0, 9.0)})
	else:
		drops(pos, Vector2.UP, n / 2, SMOKE.darkened(0.4))
		for i in 5 if not finisher else 10:
			_bits.append({"kind": "smoke", "pos": pos + Vector2(randf_range(-16, 16), randf_range(-30, 0)), "t": 0.0,
				"vel": Vector2(randf_range(-40, 40), randf_range(-90, -40)), "life": randf_range(0.45, 0.7),
				"r": randf_range(10.0, 18.0), "seed": randf() * 10.0})
	if finisher:
		_bits.append({"kind": "ring", "pos": pos, "t": 0.0, "life": 0.5, "r": 140.0})


func _process(delta: float) -> void:
	step(delta)
	queue_redraw()


## 시간 진행 (테스트에서 직접 부른다). 배열을 새로 만들지 않고 제자리에서 지운다 (모바일 GC 부담 줄이기).
func step(delta: float) -> void:
	var i := _corpses.size() - 1
	while i >= 0:
		var c := _corpses[i]
		c["t"] = float(c["t"]) + delta
		var f: CorpseFlight = c["flight"]
		if f.landed(c["t"]):
			_corpses.remove_at(i)
			death_burst(f.to, c["style"], c["finisher"])
		i -= 1
	i = _drops.size() - 1
	while i >= 0:
		var d := _drops[i]
		d["t"] = float(d["t"]) + delta
		if float(d["t"]) >= float(d["life"]):
			_drops.remove_at(i)
		else:
			d["pos"] = (d["pos"] as Vector2) + (d["vel"] as Vector2) * delta
			d["vel"] = (d["vel"] as Vector2) * maxf(1.0 - 7.0 * delta, 0.0)
		i -= 1
	i = _bits.size() - 1
	while i >= 0:
		var b := _bits[i]
		b["t"] = float(b["t"]) + delta
		if float(b["t"]) >= float(b["life"]):
			_bits.remove_at(i)
		elif b.has("vel"):
			b["pos"] = (b["pos"] as Vector2) + (b["vel"] as Vector2) * delta
			if b["kind"] == "paper":  # 종이는 떨어진다
				b["vel"] = (b["vel"] as Vector2) + Vector2(0, 520.0) * delta
				b["rot"] = float(b["rot"]) + float(b["spin"]) * delta
		i -= 1


func _draw() -> void:
	for b in _bits:
		if b["kind"] == "mark":
			var k := float(b["t"]) / float(b["life"])
			Ink.splash(self, b["pos"], float(b["r"]), Color(Ink.INK, 0.45 * (1.0 - k)), float(b["seed"]))
	for c in _corpses:
		var f: CorpseFlight = c["flight"]
		var t := float(c["t"])
		var tex: Texture2D = c["tex"]
		var g := f.ground(t)
		Ink.shadow(self, g, 18.0 * (1.0 - f.lift(t) / maxf(f.height * 2.0, 1.0)))
		var center := g + (c["offset"] as Vector2) * float(c["scale"]) + Vector2(0, -f.lift(t))
		var col: Color = c["tint"]
		col.a = 1.0 - 0.4 * f.progress(t)
		draw_set_transform(center, f.angle(t), Vector2.ONE * float(c["scale"]))
		draw_texture(tex, -tex.get_size() * 0.5, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for d in _drops:
		var k := float(d["t"]) / float(d["life"])
		var col: Color = d["color"]
		draw_circle(d["pos"], float(d["r"]) * (1.0 - 0.5 * k), Color(col, 0.85 * (1.0 - k)))
	for b in _bits:
		var k := float(b["t"]) / float(b["life"])
		match b["kind"]:
			"smoke":
				Ink.blob(self, b["pos"], float(b["r"]) * (1.0 + 1.2 * k), Color(SMOKE, 0.5 * (1.0 - k)), float(b["seed"]))
			"paper":
				var r := float(b["r"])
				var pts := PackedVector2Array([Vector2(-r, -r * 0.6), Vector2(r * 0.8, -r * 0.8), Vector2(r, r * 0.5),
					Vector2(-r * 0.6, r * 0.7)])
				var rot := float(b["rot"])
				for i in pts.size():
					pts[i] = (b["pos"] as Vector2) + pts[i].rotated(rot)
				draw_colored_polygon(pts, Color(Ink.PAPER, 1.0 - k))
				pts.append(pts[0])
				draw_polyline(pts, Color(Ink.INK, 0.7 * (1.0 - k)), 1.5)
			"ring":
				Ink.ring(self, b["pos"], float(b["r"]) * (0.3 + 0.7 * k), 10.0 * (1.0 - k) + 2.0, Color(Ink.GOLD, 1.0 - k))
