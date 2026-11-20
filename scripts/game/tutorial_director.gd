class_name TutorialDirector
extends RefCounted
## 첫 판 조작 안내를 판에 붙인다 (Main에서 분리): 적을 멈추고, 걸음·대시·기술을 받아 단계를 넘기고,
## 끝나면(또는 건너뛰면) 저장하고 적을 푼다. 진행 규칙은 TutorialProgress, 그림은 TutorialOverlay.

var main: Node
var run: TutorialProgress
var _last_pos: Vector2


func _init(m: Node) -> void:
	main = m


func running() -> bool:
	return run != null and not run.is_done()


func start(data: TutorialData) -> void:
	run = TutorialProgress.new(data)
	run.finished.connect(_on_finished, CONNECT_ONE_SHOT)
	if main.spawner:
		main.spawner.active = false
	var player: Player = main.player
	if player:
		_last_pos = player.global_position
		player.dash_started.connect(func(_d: Vector2) -> void: run.notify(&"dash"))
		var sc := player.get_node_or_null("SkillCaster") as SkillCaster
		if sc:
			sc.skill_cast.connect(_on_skill)
	if main.tutorial_overlay:
		main.tutorial_overlay.open(run)


## 기술 칸 → 안내 단계 이름.
static func skill_event(slot: SkillCaster.Slot) -> StringName:
	return {SkillCaster.Slot.TAP: &"skill_tap", SkillCaster.Slot.DASH: &"skill_dash",
		SkillCaster.Slot.CHARGE: &"skill_charge"}.get(slot, &"")


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


func _on_finished() -> void:
	GameSettings.tutorial_done = true
	GameSettings.save_settings()
	if main.spawner and main.state.is_playing():
		main.spawner.active = true
