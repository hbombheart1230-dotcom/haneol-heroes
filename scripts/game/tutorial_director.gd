class_name TutorialDirector
extends RefCounted
## 첫 판 조작 안내를 판에 붙인다 (Main에서 분리): 적을 멈추고, 걸음·연타·대시·기술·회피를 받아 단계를 넘기고,
## 끝나면(또는 건너뛰면) 저장하고 적을 푼다. 진행 규칙은 TutorialProgress, 그림은 TutorialOverlay,
## 연습 상대는 TutorialSparring. 그 영웅이 할 수 없는 단계(연타·반격 없음, 고를 강화 없음)는 바로 넘긴다.

## 기술 단계 → 기술 칸.
const SKILL_SLOTS := {&"skill_tap": SkillCaster.Slot.TAP, &"skill_dash": SkillCaster.Slot.DASH,
	&"skill_charge": SkillCaster.Slot.CHARGE, &"skill_counter": SkillCaster.Slot.COUNTER}

var main: Node
var run: TutorialProgress
var _last_pos: Vector2
## 회피·반격 단계의 연습 상대.
var sparring: TutorialSparring


func _init(m: Node) -> void:
	main = m


func running() -> bool:
	return run != null and not run.is_done()


func start(data: TutorialData) -> void:
	run = TutorialProgress.new(data)
	run.finished.connect(_on_finished, CONNECT_ONE_SHOT)
	sparring = TutorialSparring.new(main, data)
	run.advanced.connect(func(_i: int) -> void: _on_step_changed())
	run.advanced.connect(func(_i: int) -> void: _maybe_offer_practice())
	if main.seal_choice:
		main.seal_choice.chosen.connect(_on_seal_chosen)
	if main.spawner:
		main.spawner.active = false
	if main.hud:
		main.hud.hold_stage_title = true
	var player: Player = main.player
	if player:
		_last_pos = player.global_position
		player.dash_started.connect(func(_d: Vector2) -> void: run.notify(&"dash"))
		player.evaded.connect(func() -> void: run.notify(&"evade"))
		var sc := player.get_node_or_null("SkillCaster") as SkillCaster
		if sc:
			sc.skill_cast.connect(_on_skill)
	if main.tutorial_overlay:
		main.tutorial_overlay.hero_id = player.hero.id if player and player.hero else &""
		main.tutorial_overlay.waves = _waves()
		main.tutorial_overlay.open(run)
	_on_step_changed()


## 기술 칸 → 안내 단계 이름.
static func skill_event(slot: SkillCaster.Slot) -> StringName:
	return {SkillCaster.Slot.TAP: &"skill_tap", SkillCaster.Slot.DASH: &"skill_dash",
		SkillCaster.Slot.CHARGE: &"skill_charge", SkillCaster.Slot.COUNTER: &"skill_counter"}.get(slot, &"")


func _on_skill(slot: SkillCaster.Slot, _hits: int) -> void:
	var ev := skill_event(slot)
	if ev != &"" and run:
		run.notify(ev)


## 물리 틱마다: 걸은 거리와 흐른 시간을 알린다.
func tick(delta: float) -> void:
	var player: Player = main.player
	if player:
		run.notify(&"move", player.global_position.distance_to(_last_pos))
		_last_pos = player.global_position
	run.notify(&"wait", delta)
	var sc := _caster()
	if sc and sc.kit and sc.combo.streak >= sc.kit.combo_hits:  # 손으로 연계를 끝까지 이었다
		run.notify(&"combo")
	sparring.tick(delta)


## 단계가 바뀌면: 연습 상대를 세우거나 치우고, 반격이 없는 영웅은 반격 단계를 넘긴다 (막히지 않게).
func _on_step_changed() -> void:
	var s := run.current() if run else null
	sparring.sync(s)
	if s and not can_do(s.event):
		run.notify(s.event, s.amount)
		return
	var sc := _caster()
	if s and sc and SKILL_SLOTS.has(s.event):
		sc.reset_cooldown(SKILL_SLOTS[s.event])  # 앞서 써서 쿨타임이면 기다리지 않게


## 이 영웅이 이 단계를 할 수 있는지 (없는 기술 단계에서 막히지 않게).
func can_do(ev: StringName) -> bool:
	var sc := _caster()
	match ev:
		&"combo":
			return sc != null and sc.kit != null and sc.kit.tap_combo and sc.auto_attack() != null
		&"skill_tap", &"skill_dash", &"skill_charge", &"skill_counter":
			return sc != null and sc.def_of(SKILL_SLOTS[ev]) != null
	return true


func _caster() -> SkillCaster:
	return main.player.get_node_or_null("SkillCaster") as SkillCaster if main.player else null


## 물결 모드 무대인지 (강화는 숨 고르기마다 한 번, 설명도 다르다).
func _waves() -> bool:
	return main.spawner != null and main.spawner.waves != null


## 강화 고르기 단계가 되면 연습 강화 카드 셋을 띄운다 (실제 강화를 얻는다).
func _maybe_offer_practice() -> void:
	var s := run.current() if run else null
	if s == null or s.event != &"upgrade" or main.seal_choice == null or main.seal_choice.is_open():
		return
	main.progress.pending += 1
	main.break_picks = maxi(main.break_picks, 1)  # 물결 모드는 숨 고르기 몫이 있어야 카드를 연다
	main._offer_next()
	if not main.seal_choice.is_open():  # 고를 강화가 없는 영웅: 막히지 않게 이 단계를 넘긴다
		run.notify(&"upgrade")


func _on_seal_chosen(_u: UpgradeDef, _major: bool) -> void:
	if run:
		run.notify(&"upgrade")


func _on_finished() -> void:
	sparring.clear()  # 연습 상대가 선 채로 건너뛰어도 치운다
	if main.hud:
		main.hud.hold_stage_title = false
	GameSettings.tutorial_done = true
	GameSettings.save_settings()
	if main.spawner and main.state.is_playing():
		main.spawner.active = true
