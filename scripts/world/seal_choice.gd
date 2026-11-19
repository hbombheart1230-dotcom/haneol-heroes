class_name SealChoice
extends Node2D
## 레벨업 성장 고르기 (게임을 멈추지 않는다): 영웅 주변 세 방향에 먹 인장을 떨어뜨리고
## 시간을 느리게 한다. 인장으로 대시하거나 걸어 들어가면 흡수, 시간(실제 초)이 다하면 가장 가까운 것.
## 큰 변형(정예 처치 보상)은 금빛 인장으로 그린다.

signal chosen(upgrade: UpgradeDef, major: bool)

@export var player: Player
@export var fx: FxLayer
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
	chosen.emit(u, was_major)


## 실제 시간(초)으로 진행한다. 테스트에서 직접 부른다.
func step(real_delta: float) -> void:
	if not is_open():
		return
	_age += real_delta
	_left -= real_delta
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
	var font := ThemeDB.fallback_font
	var grow := clampf(_age / 0.15, 0.0, 1.0)
	var r := seal_radius * grow
	for i in choices.size():
		var u := choices[i]
		var c := to_local(positions[i])
		Ink.blob(self, c, r * 1.15, Color(Ink.INK, 0.25), float(i) + 3.0)
		draw_circle(c, r, Ink.PAPER)
		var ring := Ink.GOLD if major else u.color
		draw_arc(c, r, 0.0, TAU, 40, ring, 5.0)
		if major:
			draw_arc(c, r + 8.0, 0.0, TAU, 40, Color(Ink.GOLD, 0.6), 2.0)
		if u.icon:
			var s := r * 1.4
			draw_texture_rect(u.icon, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		else:
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
