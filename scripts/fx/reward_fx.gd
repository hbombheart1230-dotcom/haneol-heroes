class_name RewardFx
extends Node2D
## 보상 연출 (인장 고르기·탕약): 바닥에 떨어질 때 하늘에서 빛기둥 + 착지 고리,
## 먹을 때 금빛 고리 두 겹 + 사방으로 튀는 빛줄기 + 위로 떠오르는 큰 글자.
## 시간은 실제 초로 흐른다 (고르는 동안 느려진 시간·타격 멈춤과 상관없이 똑같이 보이게).

## 먹을 때: 고리·빛줄기 시간, 글자 시간(초), 빛줄기 수, 글자 크기, 고리 최대 반지름.
@export var burst_time: float = 0.8
@export var text_time: float = 1.5
@export var rays: int = 12
@export var text_px: int = 44
@export var burst_radius: float = 170.0
## 떨어질 때: 빛기둥 높이·폭, 시간.
@export var pillar_height: float = 420.0
@export var pillar_width: float = 46.0
@export var land_time: float = 0.6

var _fx: Array[Dictionary] = []


func _ready() -> void:
	z_index = 7
	process_mode = Node.PROCESS_MODE_ALWAYS


## 먹었다: pos에서 터지고 title(크게)·sub(작게)가 떠오른다.
func pickup(pos: Vector2, color: Color, title: String, sub: String = "") -> void:
	_fx.append({"kind": "burst", "pos": pos, "color": color, "t": 0.0, "dur": maxf(burst_time, text_time),
		"title": title, "sub": sub})


## 바닥에 떨어졌다: 빛기둥이 내려꽂히고 착지 고리가 퍼진다.
func land(pos: Vector2, color: Color) -> void:
	_fx.append({"kind": "land", "pos": pos, "color": color, "t": 0.0, "dur": land_time})


func count() -> int:
	return _fx.size()


func step(real_delta: float) -> void:
	for i in range(_fx.size() - 1, -1, -1):
		_fx[i].t += real_delta
		if _fx[i].t >= _fx[i].dur:
			_fx.remove_at(i)


func _process(delta: float) -> void:
	if _fx.is_empty():
		return
	step(delta / maxf(Engine.time_scale, 0.001))
	queue_redraw()


func _draw() -> void:
	for f in _fx:
		if f.kind == "burst":
			_draw_burst(f)
		else:
			_draw_land(f)


func _draw_burst(f: Dictionary) -> void:
	var c := to_local(f.pos)
	var col: Color = f.color
	var k := clampf(f.t / burst_time, 0.0, 1.0)
	if k < 1.0:
		var ease := 1.0 - pow(1.0 - k, 3.0)
		if k < 0.2:  # 처음 번쩍
			draw_circle(c, 60.0 * (1.0 + k * 3.0), Color(1, 1, 0.9, 0.7 * (1.0 - k / 0.2)))
		draw_arc(c, burst_radius * ease, 0.0, TAU, 48, Color(col, 1.0 - k), 10.0 * (1.0 - k) + 2.0)
		var k2 := clampf((f.t - 0.12) / burst_time, 0.0, 1.0)
		if k2 > 0.0:
			draw_arc(c, burst_radius * 0.7 * (1.0 - pow(1.0 - k2, 3.0)), 0.0, TAU, 40, Color(Ink.GOLD, 1.0 - k2), 4.0)
		for i in rays:
			var d := Vector2.from_angle(TAU * i / rays + 0.3)
			var a := c + d * (30.0 + burst_radius * 0.9 * ease)
			var b := c + d * (30.0 + burst_radius * 1.25 * ease)
			draw_line(a, b, Color(Color(1, 0.95, 0.7).lerp(col, 0.4), 1.0 - k), 5.0 * (1.0 - k) + 1.0)
	var tk := clampf(f.t / text_time, 0.0, 1.0)
	if tk < 1.0 and f.title != "":
		var rise := -70.0 - 90.0 * (1.0 - pow(1.0 - tk, 2.0))
		var pop := 1.0 + 0.5 * maxf(0.0, 1.0 - f.t / 0.15)
		var alpha := clampf((1.0 - tk) / 0.3, 0.0, 1.0)
		draw_set_transform(c + Vector2(0, rise), 0.0, Vector2.ONE * pop)
		UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(-220, 0), f.title, text_px, Color(Ink.GOLD, alpha), 440.0,
			Color(0, 0, 0, 0.85 * alpha), 8)
		if f.sub != "":
			UiStyle.text(self, UiStyle.BODY_FONT, Vector2(-220, text_px * 0.8), f.sub, int(text_px * 0.55),
				Color(UiStyle.PAPER, alpha), 440.0, Color(0, 0, 0, 0.8 * alpha), 6)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_land(f: Dictionary) -> void:
	var c := to_local(f.pos)
	var col: Color = f.color
	var k := clampf(f.t / land_time, 0.0, 1.0)
	var a := 1.0 - k
	var w := pillar_width * (1.0 - 0.6 * k)
	var top := c - Vector2(0, pillar_height)
	draw_polygon(PackedVector2Array([top - Vector2(w * 0.3, 0), top + Vector2(w * 0.3, 0), c + Vector2(w, 0), c - Vector2(w, 0)]),
		PackedColorArray([Color(col, 0.0), Color(col, 0.0), Color(1, 1, 0.9, 0.85 * a), Color(1, 1, 0.9, 0.85 * a)]))
	draw_set_transform(c, 0.0, Vector2(1.0, 0.4))  # 바닥에 납작하게 퍼지는 고리
	draw_arc(Vector2.ZERO, 30.0 + 110.0 * k, 0.0, TAU, 40, Color(col, a), 6.0 * a + 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
