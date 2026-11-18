class_name SkillCaster
extends Node2D
## 상황 반응형 단일 스킬 버튼 (무공 연계) — 영웅 공통.
## 어떤 기술을 쓸지는 플레이어 상태로 정하고, 기술 내용은 SkillKit(영웅 데이터)이 정한다.
##   대시 중 / 대시 직후 누름  → kit.dash   (누르는 즉시)
##   짧게 눌렀다 뗌            → kit.tap
##   길게 눌러 충전 후 뗌      → kit.charge (이동하며 충전 가능)

signal skill_cast(slot: Slot, hits: int)

enum Slot { NONE, TAP, DASH, CHARGE }

@export var player: Player
## 비어 있으면 player.hero.kit을 쓴다.
@export var kit: SkillKit
@export var projectile_scene: PackedScene
## 투사체·이펙트를 붙일 월드 노드. 비어 있으면 플레이어의 부모.
@export var world: Node
@export var fx: FxLayer

var input := SkillInput.new()
## 적 목록 공급자. 테스트에서 교체할 수 있다.
var enemy_source: Callable = func() -> Array: return get_tree().get_nodes_in_group(Enemy.GROUP)

var _cd := {Slot.TAP: 0.0, Slot.DASH: 0.0, Slot.CHARGE: 0.0}
## 진행 중인 기술: [[slot, SkillRun], ...]
var _runs: Array = []


func _ready() -> void:
	if kit == null and player and player.hero:
		kit = player.hero.kit
	if kit:
		input.hold_threshold = kit.hold_threshold
		input.full_charge_time = kit.full_charge_time


func def_of(slot: Slot) -> SkillDef:
	if kit == null:
		return null
	match slot:
		Slot.TAP:
			return kit.tap
		Slot.DASH:
			return kit.dash
		Slot.CHARGE:
			return kit.charge
	return null


func display_name(slot: Slot) -> String:
	var d := def_of(slot)
	return d.display_name if d else ""


func is_ready(slot: Slot) -> bool:
	return def_of(slot) != null and float(_cd[slot]) <= 0.0


## 0~1, 남은 쿨타임 비율.
func cooldown_ratio(slot: Slot) -> float:
	var d := def_of(slot)
	if d == null:
		return 0.0
	return clampf(float(_cd[slot]) / maxf(d.cooldown, 0.001), 0.0, 1.0)


func _dash_link() -> bool:
	return player != null and kit != null and player.in_dash_link(kit.dash_link_window)


## 지금 버튼을 누르거나 떼면 발동할 기술 (버튼 표시용).
func preview_slot() -> Slot:
	if input.state == SkillInput.State.CHARGING:
		return Slot.CHARGE
	if _dash_link() and is_ready(Slot.DASH):
		return Slot.DASH
	return Slot.TAP


## 스킬 버튼 누름. 반환: 이 터치를 스킬 손가락으로 받았으면 true.
func on_press(index: int, time: float) -> bool:
	# 버튼이 우선: 아직 판정 전인 제스처 누름은 버린다.
	if input.is_from(SkillInput.Source.GESTURE) and input.state == SkillInput.State.PRESSED:
		input.reset()
	if player == null or kit == null or player.is_dead() or not input.press(index, time):
		return false
	if _dash_link() and is_ready(Slot.DASH):
		input.consume()
		cast(Slot.DASH)
	return true


func on_release(index: int, time: float) -> Slot:
	var r := input.release(index, time)
	match r["kind"]:
		"tap":
			# 누른 뒤 탭 판정 전에 대시가 나갔다면 dash 기술 (선입력).
			if _dash_link() and is_ready(Slot.DASH):
				cast(Slot.DASH)
				return Slot.DASH
			if is_ready(Slot.TAP):
				cast(Slot.TAP)
				return Slot.TAP
		"charge":
			if is_ready(Slot.CHARGE):
				cast(Slot.CHARGE, float(r["charge"]))
				return Slot.CHARGE
	return Slot.NONE


func cancel_input() -> void:
	input.reset()


# --- 한 손 제스처 (이동 손가락) ---
#   제자리 짧게 탭            → tap (대시 직후면 dash 기술)
#   제자리 꾹 누르기 → 충전   → 그대로 드래그해 이동 가능 → 떼면 charge
#   tap_slop 이상 움직이면 그 누름은 이동이므로 스킬 없음

var _gesture_origin: Vector2 = Vector2.ZERO


func gesture_down(index: int, pos: Vector2, time: float) -> bool:
	if player == null or kit == null or player.is_dead():
		return false
	if not input.press(index, time, SkillInput.Source.GESTURE, kit.gesture_hold_threshold):
		return false
	_gesture_origin = pos
	return true


func gesture_move(index: int, pos: Vector2, time: float) -> void:
	if not input.is_from(SkillInput.Source.GESTURE) or input.index != index:
		return
	input.update(time)
	if input.state == SkillInput.State.PRESSED and pos.distance_to(_gesture_origin) > kit.gesture_tap_slop:
		input.reset()


func gesture_up(index: int, time: float) -> Slot:
	if not input.is_from(SkillInput.Source.GESTURE) or input.index != index:
		return Slot.NONE
	return on_release(index, time)


## 플릭(대시) 등으로 이 제스처를 스킬 없이 끝낸다.
func gesture_cancel(index: int) -> void:
	if input.is_from(SkillInput.Source.GESTURE) and input.index == index:
		input.reset()


func is_gesture_charging() -> bool:
	return input.is_from(SkillInput.Source.GESTURE) and input.state == SkillInput.State.CHARGING


## 쿨타임을 걸고 기술을 발동한다. 반환: 진행 상태.
func cast(slot: Slot, charge: float = 0.0) -> SkillRun:
	var d := def_of(slot)
	if d == null:
		return null
	_cd[slot] = d.cooldown
	var run := d.cast(_context(), charge)
	if run.finished:
		skill_cast.emit(slot, run.hits)
	else:
		_runs.append([slot, run])
	return run


func tick(delta: float, time: float) -> void:
	for k in _cd.keys():
		_cd[k] = maxf(float(_cd[k]) - delta, 0.0)
	# 선입력: 버튼을 누른 채(탭 판정 전) 대시가 시작되면 dash 기술로 바꾼다.
	if input.is_from(SkillInput.Source.BUTTON) and input.state == SkillInput.State.PRESSED \
			and player and player.is_dashing() and is_ready(Slot.DASH):
		input.consume()
		cast(Slot.DASH)
	input.update(time)
	for entry in _runs.duplicate():
		var run: SkillRun = entry[1]
		if run.tick(delta):
			_runs.erase(entry)
			skill_cast.emit(entry[0], run.hits)


func _context() -> SkillContext:
	var ctx := SkillContext.new()
	ctx.player = player
	ctx.world = world
	ctx.fx = fx
	ctx.projectile_scene = projectile_scene
	ctx.enemy_source = enemy_source
	return ctx


func _physics_process(delta: float) -> void:
	tick(delta, Time.get_ticks_usec() / 1_000_000.0)
	queue_redraw()


func _draw() -> void:
	# 충전 중 표시: 플레이어 발밑 고리
	if input.state != SkillInput.State.CHARGING:
		return
	var c := input.charge_ratio(Time.get_ticks_usec() / 1_000_000.0)
	draw_arc(Vector2.ZERO, 36.0 + 20.0 * c, -PI / 2, -PI / 2 + TAU * maxf(c, 0.02), 32, Color(0.4, 0.8, 1.0, 0.9), 5.0)
