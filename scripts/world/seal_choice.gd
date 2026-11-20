class_name SealChoice
extends Node2D
## 레벨업 성장 고르기 (게임을 멈추지 않는다): 영웅 주변 세 방향에 먹 인장을 떨어뜨리고
## 시간을 느리게 한다. 인장으로 대시하거나 걸어 들어가면 흡수, 시간(실제 초)이 다하면 가장 가까운 것.
## 큰 변형(정예 처치 보상)은 금빛 인장으로 그린다.

signal chosen(upgrade: UpgradeDef, major: bool)

@export var player: Player
@export var fx: FxLayer
## 떨어질 때 빛기둥, 먹을 때 터짐·글자 (없으면 고리만).
@export var reward_fx: RewardFx
## 하늘에서 떨어져 바닥에 닿기까지(실제 초)와 떨어지는 높이.
@export var fall_time: float = 0.3
@export var fall_height: float = 260.0
## 인장까지 거리(px)와 인장 크기.
@export var spread: float = 160.0
@export var seal_radius: float = 46.0
## 고르는 시간(실제 초). 지나면 가장 가까운 인장.
@export var timeout: float = 3.0
## 고르는 동안 게임 시간 배율.
@export var slow_scale: float = 0.35
## 인장을 놓을 수 있는 영역 (월드 좌표). 크기 0이면 제한 없음.
@export var arena_rect: Rect2 = Rect2()

var choices: Array[UpgradeDef] = []
var positions: PackedVector2Array = PackedVector2Array()
var major: bool = false
## UpgradeDef.id → 이미 고른 횟수 (인장 아래 표시).
var stacks: Dictionary = {}
var _left: float = 0.0
var _age: float = 0.0
var _landed := false

## 인장 개수별 방향(도, 화면 기준 y 아래): 위왼쪽·위오른쪽·아래.
const ANGLES := {1: [-90.0], 2: [-150.0, -30.0], 3: [-150.0, -30.0, 90.0]}


func _ready() -> void:
	z_index = 4
	hide()


func is_open() -> bool:
	return not choices.is_empty()


func open(p_choices: Array[UpgradeDef], center: Vector2, p_major: bool, p_stacks: Dictionary) -> void:
	choices = p_choices
	major = p_major
	stacks = p_stacks
	positions = PackedVector2Array()
	var angles: Array = ANGLES.get(mini(choices.size(), 3), ANGLES[3])
	for i in choices.size():
		var a := deg_to_rad(float(angles[i % angles.size()]))
		var p := center + Vector2.from_angle(a) * spread
		if arena_rect.has_area():
			var inner := arena_rect.grow(-seal_radius)
			p = p.clamp(inner.position, inner.end)
		positions.append(p)
	_left = timeout
	_age = 0.0
	_landed = false
	show()
	GameTime.set_base(slow_scale)


func close() -> void:
	choices = []
	positions = PackedVector2Array()
	hide()
	GameTime.reset()


func time_left() -> float:
	return _left


## 이 위치에 닿은 인장 번호 (없으면 -1).
func seal_at(pos: Vector2, reach: float = 0.0) -> int:
	for i in positions.size():
		if positions[i].distance_to(pos) <= seal_radius + reach:
			return i
	return -1


func nearest_to(pos: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in positions.size():
		var d := positions[i].distance_to(pos)
		if d < best_d:
			best_d = d
			best = i
	return best


func pick(i: int) -> void:
	if i < 0 or i >= choices.size():
		return
	var u := choices[i]
	var where := positions[i]
	var was_major := major
	close()
	if fx:
		fx.add_ring(where, seal_radius * 2.2, 0.35, Ink.GOLD if was_major else u.color)
	if reward_fx:
		reward_fx.pickup(where, Ink.GOLD if was_major else u.color, u.title, u.description.split("
")[0])
	if Feedback.instance:
		Feedback.instance.play(&"magic")
		Feedback.instance.haptic(60, 0.8)
	chosen.emit(u, was_major)


## 실제 시간(초)으로 진행한다. 테스트에서 직접 부른다.
func step(real_delta: float) -> void:
	if not is_open():
		return
	_age += real_delta
	_left -= real_delta
	if not _landed and _age >= fall_time:
		_landed = true
		for i in positions.size():
			if reward_fx:
				reward_fx.land(positions[i], Ink.GOLD if major else choices[i].color)
	if player:
		var hit := seal_at(player.global_position, player.body_radius * 0.5)
		if hit >= 0:
			pick(hit)
			return
	if _left <= 0.0:
		pick(nearest_to(player.global_position) if player else 0)


func _physics_process(delta: float) -> void:
	if is_open():
		step(delta / maxf(Engine.time_scale, 0.001))
		queue_redraw()


func _draw() -> void:
	if not is_open():
		return
	var font := UiStyle.BODY_FONT
	var grow := clampf(_age / 0.15, 0.0, 1.0)
	var r := seal_radius * grow
	var fall := clampf(_age / maxf(fall_time, 0.01), 0.0, 1.0)
	var drop := -fall_height * (1.0 - fall * fall)  # 하늘에서 빨라지며 떨어진다
	var glow := 0.55 + 0.25 * sin(_age * 6.0)
	for i in choices.size():
		var u := choices[i]
		var ground := to_local(positions[i])
		var ring_col := Ink.GOLD if major else u.color
		_draw_beam(ground, ring_col, glow if fall >= 1.0 else 0.9)
		var c := ground + Vector2(0, drop)
		Ink.blob(self, c, r * 1.15, Color(Ink.INK, 0.25), float(i) + 3.0)
		draw_circle(c, r, Ink.PAPER)
		var ring := Ink.GOLD if major else u.color
		draw_arc(c, r, 0.0, TAU, 40, ring, 5.0)
		if major:
			draw_arc(c, r + 8.0, 0.0, TAU, 40, Color(Ink.GOLD, 0.6), 2.0)
		if u.icon:
			var s := r * 1.4
			draw_texture_rect(u.icon, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		elif r >= 8.0:  # 떨어지는 첫 순간(크기 0)에는 글자를 그리지 않는다 (글꼴 크기 0 오류)
			draw_string(font, c + Vector2(-r, r * 0.35), u.title.left(1), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0,
				int(r * 0.95), u.color)
		var label := Vector2(-120, r + 32)
		draw_string_outline(font, c + label, u.title, HORIZONTAL_ALIGNMENT_CENTER, 240, 24, 6, Color(Ink.PAPER, 0.95))
		draw_string(font, c + label, u.title, HORIZONTAL_ALIGNMENT_CENTER, 240, 24, Ink.INK)
		var desc := u.description.split("\n")[0]
		draw_string_outline(font, c + label + Vector2(0, 26), desc, HORIZONTAL_ALIGNMENT_CENTER, 240, 19, 5,
			Color(Ink.PAPER, 0.9))
		draw_string(font, c + label + Vector2(0, 26), desc, HORIZONTAL_ALIGNMENT_CENTER, 240, 19, Color(Ink.INK, 0.85))
	# 남은 시간: 영웅 둘레 먹 고리가 줄어든다
	if player:
		var pc := to_local(player.global_position)
		var k := clampf(_left / maxf(timeout, 0.001), 0.0, 1.0)
		draw_arc(pc, 70.0, -PI * 0.5, -PI * 0.5 + TAU * k, 48, Color(Ink.INK, 0.6), 4.0)


## 바닥에 놓인 보상 위로 서는 빛기둥과 발밑 빛무리 (멀리서도 보이게).
func _draw_beam(ground: Vector2, col: Color, a: float) -> void:
	var w := seal_radius * 0.9
	var top := ground - Vector2(0, 300)
	draw_polygon(PackedVector2Array([top - Vector2(w * 0.4, 0), top + Vector2(w * 0.4, 0), ground + Vector2(w, 0), ground - Vector2(w, 0)]),
		PackedColorArray([Color(col, 0.0), Color(col, 0.0), Color(col, 0.45 * a), Color(col, 0.45 * a)]))
	draw_set_transform(ground + Vector2(0, seal_radius * 0.6), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, seal_radius * 1.6, Color(col, 0.3 * a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
