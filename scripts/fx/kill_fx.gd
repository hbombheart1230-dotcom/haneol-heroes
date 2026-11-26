class_name KillFx
extends Node2D
## 처치·타격 이펙트: 날아가는 시체, 땅에 남는 먹 자국, 먹물 방울, 군대별 죽음 모양 (연기·조각난 종이).
## 한 노드의 _draw로 모두 그린다 (노드를 만들지 않아 모바일에서 가볍다). 개수 상한은 CombatFeelData.

var feel: CombatFeelData
var _b: InkBurstData
## 종이 조각 그리기용 꼭짓점 버퍼 (매 프레임 새 배열을 만들지 않게).
var _quad := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _outline := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
const PAPER_SHAPE := [Vector2(-1.0, -0.6), Vector2(0.8, -0.8), Vector2(1.0, 0.5), Vector2(-0.6, 0.7)]
## {flight, tex, scale, offset, tint, t, style, finisher}
var _corpses: Array[Dictionary] = []
## {pos, vel, t, life, r, color}
var _drops: Array[Dictionary] = []
## 연기 덩이·종이 조각·먹 자국: {kind, pos, vel, t, life, r, seed, rot, spin, color}
var _bits: Array[Dictionary] = []


func _init(p_feel: CombatFeelData = null) -> void:
	feel = p_feel if p_feel else CombatFeelData.new()
	_b = feel.burst_data()


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
		var v := base.rotated(randf_range(-_b.drop_spread, _b.drop_spread)) * _rand(_b.drop_speed)
		_drops.append({"pos": pos + Vector2(0, -_b.drop_lift), "vel": v, "t": 0.0, "life": _rand(_b.drop_life),
			"r": _rand(_b.drop_radius), "color": color})
	while _drops.size() > maxi(feel.max_drops, 0):
		_drops.pop_front()


## 군대별 죽음 모양 + 먹 자국.
func death_burst(pos: Vector2, style: StringName, finisher: bool = false) -> void:
	var mul := maxi(_b.finisher_scale, 1) if finisher else 1
	_bits.append({"kind": "mark", "pos": pos, "t": 0.0, "life": feel.mark_time,
		"r": _b.mark_radius_finisher if finisher else _b.mark_radius, "seed": randf() * 10.0})
	var n := feel.kill_drops * mul
	if style == &"paper":
		drops(pos, Vector2.UP, n / 2)
		for i in _b.paper_count * mul:
			_bits.append({"kind": "paper", "pos": pos + _jitter(), "t": 0.0,
				"vel": Vector2(randf_range(-_b.paper_speed_x, _b.paper_speed_x), _rand(_b.paper_speed_y)),
				"life": _rand(_b.paper_life), "r": _rand(_b.paper_size), "rot": randf() * TAU,
				"spin": randf_range(-_b.paper_spin, _b.paper_spin)})
	elif style != &"none":  # none = 속성 모습(DeathFx)이 대신함
		drops(pos, Vector2.UP, n / 2, _b.smoke_color.darkened(0.4))
		for i in _b.smoke_count * mul:
			_bits.append({"kind": "smoke", "pos": pos + _jitter(), "t": 0.0,
				"vel": Vector2(randf_range(-_b.smoke_drift_x, _b.smoke_drift_x), _rand(_b.smoke_rise)),
				"life": _rand(_b.smoke_life), "r": _rand(_b.smoke_size), "seed": randf() * 10.0})
	if finisher:
		_bits.append({"kind": "ring", "pos": pos, "t": 0.0, "life": _b.ring_time, "r": _b.ring_radius})


func _jitter() -> Vector2:
	return Vector2(randf_range(-_b.spawn_jitter.x, _b.spawn_jitter.x), -randf() * _b.spawn_jitter.y)


func _rand(range_v: Vector2) -> float:
	return randf_range(range_v.x, range_v.y)


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
			d["vel"] = (d["vel"] as Vector2) * maxf(1.0 - _b.drop_damping * delta, 0.0)
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
				b["vel"] = (b["vel"] as Vector2) + Vector2(0, _b.paper_gravity) * delta
				b["rot"] = float(b["rot"]) + float(b["spin"]) * delta
		i -= 1


## 단색 도형(먹 자국·그림자·방울·연기·종이)을 모아 한 번에 (InkBatch). 그림(시체)·선(종이 테·고리) 앞에서 비워 차례 그대로.
var _ib := InkBatch.new()


func _draw() -> void:
	for b in _bits:
		if b["kind"] == "mark":
			var k := float(b["t"]) / float(b["life"])
			_ib.splash(b["pos"], float(b["r"]), Color(Ink.INK, _b.mark_alpha * (1.0 - k)), float(b["seed"]))
	for c in _corpses:
		var f: CorpseFlight = c["flight"]
		var t := float(c["t"])
		var tex: Texture2D = c["tex"]
		var g := f.ground(t)
		_ib.blob(g, _b.corpse_shadow * (1.0 - f.lift(t) / maxf(f.height * 2.0, 1.0)), Color(Ink.INK, 0.18), 1.3, 0.08, 0.4)  # Ink.shadow와 같다
		_ib.flush(self)  # 그림 (시체) 앞
		var center := g + (c["offset"] as Vector2) * float(c["scale"]) + Vector2(0, -f.lift(t))
		var col: Color = c["tint"]
		col.a = 1.0 - _b.corpse_fade * f.progress(t)
		draw_set_transform(center, f.angle(t), Vector2.ONE * float(c["scale"]))
		draw_texture(tex, -tex.get_size() * 0.5, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for d in _drops:
		var k := float(d["t"]) / float(d["life"])
		var col: Color = d["color"]
		_ib.circle(d["pos"], float(d["r"]) * (1.0 - _b.drop_shrink * k), Color(col, _b.drop_alpha * (1.0 - k)))
	for b in _bits:
		var k := float(b["t"]) / float(b["life"])
		match b["kind"]:
			"smoke":
				_ib.blob(b["pos"], float(b["r"]) * (1.0 + _b.smoke_grow * k), Color(_b.smoke_color, _b.smoke_alpha * (1.0 - k)),
					float(b["seed"]))
			"paper":
				var r := float(b["r"])
				var rot := float(b["rot"])
				for i in 4:
					_quad[i] = (b["pos"] as Vector2) + (PAPER_SHAPE[i] as Vector2).rotated(rot) * r
					_outline[i] = _quad[i]
				_outline[4] = _quad[0]
				_ib.quad(_quad, Color(Ink.PAPER, 1.0 - k))
				_ib.flush(self)  # 선 앞
				draw_polyline(_outline, Color(Ink.INK, _b.paper_edge_alpha * (1.0 - k)), _b.paper_edge_width)
			"ring":
				_ib.flush(self)  # 선 앞
				Ink.ring(self, b["pos"], float(b["r"]) * lerpf(_b.ring_start_scale, 1.0, k),
					lerpf(_b.ring_width, _b.ring_width_min, k), Color(Ink.GOLD, 1.0 - k))
	_ib.flush(self)
