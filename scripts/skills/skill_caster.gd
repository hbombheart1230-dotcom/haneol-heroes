class_name SkillCaster
extends Node2D
## 상황 반응형 단일 스킬 버튼 (무공 연계) — 영웅 공통.
## 어떤 기술을 쓸지는 플레이어 상태로 정하고, 기술 내용은 SkillKit(영웅 데이터)이 정한다.
##   대시 중 / 대시 직후 누름  → kit.dash   (누르는 즉시)
##   짧게 눌렀다 뗌            → kit.tap
##   길게 눌러 충전 후 뗌      → kit.charge (이동하며 충전 가능)
##   회피 성공 후 counter_window 안 누름 → kit.counter (최우선, 기획서 §6.3)
## 탭 연타 (kit.tap_combo, 한 손 제스처만): 제자리 탭 = 평타 한 타, combo_hits타 뒤 탭 = kit.tap 마무리 (TapCombo).

signal skill_cast(slot: Slot, hits: int)
## 누르는 순간 (여러 프레임 기술도 시작할 때 한 번): 영웅 시전 동작용. def = 실제로 쓰인 기술.
signal skill_started(slot: Slot, def: SkillDef)
## 손 연타가 이어진 타 수 (평타가 적에 닿을 때 1·2·3, 원거리 평타는 쏠 때, 마무리 = combo_hits + 1): 연타 글씨용.
signal combo_count(n: int)

enum Slot { NONE, TAP, DASH, CHARGE, COUNTER }

@export var player: Player
## 비어 있으면 player.hero.kit을 쓴다.
@export var kit: SkillKit
@export var projectile_scene: PackedScene
## 투사체·이펙트를 붙일 월드 노드. 비어 있으면 플레이어의 부모.
@export var world: Node
@export var fx: FxLayer
## 반격 등 강한 타격의 짧은 멈춤(히트스톱). 테스트에서 끌 수 있다.
@export var hit_stop_enabled: bool = true

var input := SkillInput.new()
var _charge_marker: ChargeMarker
## 충전 조준 (charge_aim 기술): 모으는 동안 잡은 방향과 바닥 길 표시.
var aim := ChargeAim.new()
## 적 목록 공급자. 테스트에서 교체할 수 있다.
var enemy_source: Callable = func() -> Array: return get_tree().get_nodes_in_group(Enemy.GROUP)

var _cd := {Slot.TAP: 0.0, Slot.DASH: 0.0, Slot.CHARGE: 0.0, Slot.COUNTER: 0.0}
## 회피 성공 후 남은 반격 가능 시간(초).
var _counter_left: float = 0.0
## 진행 중인 기술: [[slot, SkillRun], ...]
var _runs: Array = []
## 탭 연타 상태와 손 평타를 낼 자동 공격 (영웅의 AutoAttack).
var combo := TapCombo.new()
var _attack: AutoAttack


func _ready() -> void:
	show_behind_parent = true  # 충전 표시는 바닥 (영웅 그림 아래)
	if kit == null and player and player.hero:
		kit = player.hero.kit
	apply_kit(kit)
	if player and not player.evaded.is_connected(on_evade):
		player.evaded.connect(on_evade)


## 기술 구성을 바꾸거나 수치가 바뀐 뒤 부른다 (입력 판정 시간을 다시 읽는다. 런 성장 등).
func apply_kit(k: SkillKit) -> void:
	kit = k
	if kit:
		input.hold_threshold = kit.hold_threshold
		input.full_charge_time = kit.full_charge_time


## 회피 성공 (Player.evaded). 반격 시간을 연다.
func on_evade() -> void:
	if kit and kit.counter:
		_counter_left = kit.counter_window


func counter_time_left() -> float:
	return _counter_left


func is_counter_open() -> bool:
	return _counter_left > 0.0 and is_ready(Slot.COUNTER)


## 누르는 즉시 나가는 상황 기술: 반격 > 대시 연계. 없으면 NONE.
func _instant_slot() -> Slot:
	if is_counter_open():
		return Slot.COUNTER
	if _dash_link() and is_ready(Slot.DASH):
		return Slot.DASH
	return Slot.NONE


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
		Slot.COUNTER:
			return kit.counter
	return null


func display_name(slot: Slot) -> String:
	var d := def_of(slot)
	return d.display_name if d else ""


func is_ready(slot: Slot) -> bool:
	return def_of(slot) != null and float(_cd[slot]) <= 0.0


## 쿨타임을 바로 끝낸다 (조작 안내가 그 기술 단계를 열 때: 앞서 쓴 쿨타임에 막혀 기다리지 않게).
func reset_cooldown(slot: Slot) -> void:
	_cd[slot] = 0.0


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
	var instant := _instant_slot()
	return instant if instant != Slot.NONE else Slot.TAP


## 스킬 버튼 누름. 반환: 이 터치를 스킬 손가락으로 받았으면 true.
func on_press(index: int, time: float) -> bool:
	# 버튼이 우선: 아직 판정 전인 제스처 누름은 버린다.
	if input.is_from(SkillInput.Source.GESTURE) and input.state == SkillInput.State.PRESSED:
		input.reset()
	if player == null or kit == null or player.is_dead() or not input.press(index, time):
		return false
	var instant := _instant_slot()
	if instant != Slot.NONE:
		input.consume()
		cast(instant)
	return true


func on_release(index: int, time: float) -> Slot:
	# 죽은 뒤에는 누르고 있던 입력을 떼도 발동하지 않는다 (Codex edeb579 지적).
	if player == null or player.is_dead():
		input.reset()
		return Slot.NONE
	var src := input.source
	var r := input.release(index, time)
	match r["kind"]:
		"tap":
			# 반격 시간이거나, 누른 뒤 탭 판정 전에 대시가 나갔다면 그 기술 (선입력).
			var instant := _instant_slot()
			if instant != Slot.NONE:
				cast(instant)
				return instant
			if src == SkillInput.Source.GESTURE and kit.tap_combo and auto_attack() != null:  # 평타가 없으면 예전대로
				return combo_tap()
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


## 이동 손가락을 뗄 때 대시 중·직후면 dash 기술, 반격 시간이면 반격
## (실기기 피드백: 튕기고 탭은 너무 안 나옴). 반환: 발동했으면 true.
func try_dash_release() -> bool:
	if player == null or player.is_dead():
		return false
	var slot := Slot.COUNTER if is_counter_open() and _dash_link() else Slot.NONE
	if slot == Slot.NONE and _dash_link() and is_ready(Slot.DASH):
		slot = Slot.DASH
	if slot == Slot.NONE:
		return false
	cast(slot)
	# 판정 전인 버튼 누름은 이 파도격에 합쳐진다 (손 뗄 때 해룡참 추가 발동 방지, Codex dc73e07 지적).
	if input.is_from(SkillInput.Source.BUTTON) and input.state == SkillInput.State.PRESSED:
		input.consume()
	return true


## 플릭(대시) 등으로 이 제스처를 스킬 없이 끝낸다.
func gesture_cancel(index: int) -> void:
	if input.is_from(SkillInput.Source.GESTURE) and input.index == index:
		input.reset()


func is_gesture_charging() -> bool:
	return input.is_from(SkillInput.Source.GESTURE) and input.state == SkillInput.State.CHARGING


# --- 탭 연타 (A안) ---

## 제자리 탭 하나 (TapChain): 평타 한 타, 연계가 찼으면 tap 기술 마무리, 너무 빠르면 잠깐 기억.
func combo_tap() -> Slot:
	return TapChain.tap(self)


## 손 평타 최소 간격(초) (TapChain).
func tap_gap() -> float:
	return TapChain.gap(self)


func auto_attack() -> AutoAttack:
	if _attack == null and player:
		_attack = player.get_node_or_null("AutoAttack") as AutoAttack
		if _attack:  # 자동 평타를 연계 수에 넣을지는 kit.combo_auto_counts
			_attack.melee_windup.connect(func(_d: Vector2) -> void: _on_auto_swing())
			_attack.ranged_windup.connect(func(_d: Vector2) -> void: _on_auto_swing())
			_attack.melee_swung.connect(func(_d: Vector2, hits: int) -> void: _on_manual_land(hits > 0 and _attack.swing_manual))
			_attack.projectile_fired.connect(func(_p: Projectile) -> void: _on_manual_land(_attack.shot_manual))
			player.dash_started.connect(func(_d: Vector2) -> void: ComboSteps.cancel_swing(_attack))
	return _attack


## 손 평타가 닿았다 (원거리는 쏘았다): 연타 글씨.
func _on_manual_land(landed: bool) -> void:
	if landed and combo.streak > 0:
		combo_count.emit(combo.streak)


func _on_auto_swing() -> void:
	if kit and kit.combo_auto_counts and _attack and not _attack.last_manual:
		combo.on_auto_hit(kit.combo_hits)


## 쿨타임을 걸고 기술을 발동한다. 반환: 진행 상태.
## damage_scale: 피해 배율 (탭 연타 마무리), cd: 0 이상이면 이 쿨타임.
func cast(slot: Slot, charge: float = 0.0, damage_scale: float = 1.0, cd: float = -1.0) -> SkillRun:
	var d := def_of(slot)
	if d == null or player == null or player.is_dead():
		return null
	_cd[slot] = cd if cd >= 0.0 else d.cooldown
	d = TapCombo.scaled_def(d, damage_scale)
	if slot == Slot.COUNTER:
		_counter_left = 0.0
	skill_started.emit(slot, d)
	var ctx := _context()
	ctx.skill = d
	if slot == Slot.CHARGE:
		ctx.aim_dir = aim.aim_dir()
	if d.vfx_cast:
		Feedback.vfx_burst(d.vfx_cast, d.cast_point(ctx), player.facing, d.vfx_level)  # 세종 정음진은 겨눈 적 자리
	SkillStageFx.on_cast(get_tree() if is_inside_tree() else null, d, player.hero)  # 컷인 + 소리 층
	var run := d.cast(ctx, charge)
	if run.finished:
		skill_cast.emit(slot, run.hits if run.announce_hits < 0 else run.announce_hits)
	else:
		if run.announce_hits >= 0:
			skill_cast.emit(slot, run.announce_hits)
		_runs.append([slot, run])
	return run


func tick(delta: float, time: float) -> void:
	for k in _cd.keys():
		_cd[k] = maxf(float(_cd[k]) - delta, 0.0)
	_counter_left = maxf(_counter_left - delta, 0.0)
	if kit:
		combo.tick(delta, kit.combo_window)
		TapChain.flush(self)
	# 선입력: 버튼을 누른 채(탭 판정 전) 대시가 시작되거나 반격 시간이 열리면 그 기술로 (반격 우선, Codex e593772 지적).
	if input.is_from(SkillInput.Source.BUTTON) and input.state == SkillInput.State.PRESSED \
			and player and (player.is_dashing() or is_counter_open()):
		var instant := _instant_slot()
		if instant != Slot.NONE:
			input.consume()
			cast(instant)
	input.update(time)
	for entry in _runs.duplicate():
		var run: SkillRun = entry[1]
		if run.tick(delta):
			_runs.erase(entry)
			if run.announce_hits < 0:
				skill_cast.emit(entry[0], run.hits)


func _context() -> SkillContext:
	var ctx := SkillContext.new()
	ctx.player = player
	ctx.world = world
	ctx.fx = fx
	ctx.projectile_scene = projectile_scene
	ctx.enemy_source = enemy_source
	ctx.hit_stop_enabled = hit_stop_enabled
	return ctx


## 충전 중인지 (영웅 모으는 자세용).
func is_charging() -> bool:
	return _is_charging_alive()


## 살아서 모으는 중인지 (죽으면 손을 떼기 전이라도 표시·입자·번쩍임 없음).
func is_charging_alive() -> bool:
	return _is_charging_alive()


func _is_charging_alive() -> bool:
	return input.state == SkillInput.State.CHARGING and player != null and not player.is_dead()


## 영웅별 충전 표시 (영웅이 바뀌면 다시 만든다).
func _marker() -> ChargeMarker:
	var d := player.hero.charge_marker if player and player.hero else null
	if _charge_marker == null or _charge_marker.data != d:
		var m := ChargeMarker.new(d)
		m.carry_from(_charge_marker)
		_charge_marker = m
	return _charge_marker


func _physics_process(delta: float) -> void:
	tick(delta, Time.get_ticks_usec() / 1_000_000.0)
	ChargeView.tick(self, delta)
	queue_redraw()


func _draw() -> void:
	ChargeView.draw(self)  # 충전 중 표시: 플레이어 발밑 (show_behind_parent로 영웅 그림 아래)
