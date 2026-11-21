class_name TutorialDirector
extends RefCounted
## 첫 판 조작 안내를 판에 붙인다 (Main에서 분리): 적을 멈추고, 걸음·대시·기술을 받아 단계를 넘기고,
## 끝나면(또는 건너뛰면) 저장하고 적을 푼다. 진행 규칙은 TutorialProgress, 그림은 TutorialOverlay.

var main: Node
var run: TutorialProgress
var _last_pos: Vector2
var _seal_timeout := -1.0  # 연습 인장 동안 바꿔 둔 SealChoice.timeout (원래 값)
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
	var player: Player = main.player
	if player:
		_last_pos = player.global_position
		player.dash_started.connect(func(_d: Vector2) -> void: run.notify(&"dash"))
		player.evaded.connect(func() -> void: run.notify(&"evade"))
		var sc := player.get_node_or_null("SkillCaster") as SkillCaster
		if sc:
			sc.skill_cast.connect(_on_skill)
	if main.tutorial_overlay:
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
	sparring.tick(delta)


## 단계가 바뀌면: 연습 상대를 세우거나 치우고, 반격이 없는 영웅은 반격 단계를 넘긴다 (막히지 않게).
func _on_step_changed() -> void:
	var s := run.current() if run else null
	sparring.sync(s)
	if s and s.event == &"skill_counter" and not _has_counter():
		run.notify(&"skill_counter")


func _has_counter() -> bool:
	if main.player == null:
		return false
	var sc := main.player.get_node_or_null("SkillCaster") as SkillCaster
	return sc != null and sc.kit != null and sc.kit.counter != null


## 강화 고르기 단계가 되면 연습 인장 셋을 떨어뜨린다 (실제 강화를 얻는다). 고르는 시간은 넉넉히.
func _maybe_offer_practice() -> void:
	var s := run.current() if run else null
	if s == null or s.event != &"upgrade" or main.seal_choice == null or main.seal_choice.is_open():
		return
	_seal_timeout = main.seal_choice.timeout
	main.seal_choice.timeout = run.data.upgrade_timeout
	main.progress.pending += 1
	main._offer_next()
	if not main.seal_choice.is_open():  # 고를 강화가 없는 영웅: 막히지 않게 이 단계를 넘긴다
		_restore_timeout()
		run.notify(&"upgrade")


func _on_seal_chosen(_u: UpgradeDef, _major: bool) -> void:
	_restore_timeout()
	if run:
		run.notify(&"upgrade")


func _restore_timeout() -> void:
	if _seal_timeout >= 0.0 and main.seal_choice:
		main.seal_choice.timeout = _seal_timeout
	_seal_timeout = -1.0


func _on_finished() -> void:
	_restore_timeout()  # 연습 인장이 떠 있는 채로 건너뛰어도 원래 고르는 시간으로
	sparring.clear()  # 연습 상대가 선 채로 건너뛰어도 치운다
	GameSettings.tutorial_done = true
	GameSettings.save_settings()
	if main.spawner and main.state.is_playing():
		main.spawner.active = true
