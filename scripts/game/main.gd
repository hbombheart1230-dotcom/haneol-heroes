extends Node2D
## 전투 씬 연결: 한 판(런) 진행, 처치·경험치·레벨업 선택, 보스 처치 승리, 게임오버, 탭하여 재시작.

@export var player: Player
@export var spawner: EnemySpawner
@export var hud: Hud
@export var survive_time: float = 60.0
## 런 규칙 (경험치·보스 시각). 있으면 survive_time 등을 이 값으로 덮어쓴다.
@export var run_config: RunConfig
@export var level_up_panel: LevelUpPanel
@export var touch_controller: TouchController
## 결과 화면에서 재시작 입력을 받기까지 대기(초). 연타로 바로 넘어가는 것을 막는다.
@export var restart_delay: float = 0.6

var state: GameState
var perf := PerfStats.new()
var progress: RunProgress
var build := RunBuild.new()
var rng := RandomNumberGenerator.new()
var _end_time: float = 0.0


func _ready() -> void:
	# 결과 화면에서 재시작 입력을 받으려면 Main은 일시정지 중에도 돌아야 한다.
	# 게임 오브젝트는 일시정지되도록 명시한다 (INHERIT면 Main의 ALWAYS를 물려받음).
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 이전 판의 히트스톱·예고 공격 슬롯이 남지 않게 초기화.
	Engine.time_scale = 1.0
	EnemyAttack.active_windups = 0
	for c in get_children():
		if not (c is CanvasLayer):
			c.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().paused = false
	if run_config:
		survive_time = run_config.survive_time
		if spawner:
			spawner.boss_time = run_config.boss_time
			spawner.ramp_time = run_config.ramp_time
	progress = RunProgress.new(run_config)
	if player:
		build.begin(player, player.get_node_or_null("SkillCaster") as SkillCaster,
			player.get_node_or_null("AutoAttack") as AutoAttack)
	if level_up_panel:
		level_up_panel.chosen.connect(_on_upgrade_chosen)
		if run_config:
			level_up_panel.input_delay = run_config.choice_input_delay
	state = GameState.new(survive_time)
	state.ended.connect(_on_ended)
	if player and player.health:
		player.health.died.connect(func(_e: Node) -> void: state.player_died())
	if spawner:
		spawner.enemy_killed.connect(_on_enemy_killed)
	if hud:
		hud.state = state
		hud.perf = perf
		hud.progress = progress


## 렌더 프레임 기준 성능 기록 (플레이 중에만).
func _process(delta: float) -> void:
	if state.is_playing() and not is_choosing():
		perf.sample(delta, spawner.alive_count() if spawner else 0)


func _physics_process(delta: float) -> void:
	if is_choosing():
		return  # 선택 화면 동안 시간이 흐르지 않는다 (Main은 일시정지 중에도 돈다)
	if state.is_playing():
		state.tick(delta)
	else:
		_end_time += delta


func _on_ended(_result: GameState.Result) -> void:
	_end_time = 0.0
	# adb logcat으로도 확인할 수 있게 남긴다.
	print("[HH perf] %s · %.1fs" % [perf.summary(), state.elapsed])
	if spawner:
		spawner.active = false
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if state.is_playing() or _end_time < restart_delay:
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		restart()


func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_enemy_killed(e: Enemy) -> void:
	state.add_kill()
	if e.data and e.data.is_boss:
		state.boss_defeated()
	if e.data and state.is_playing():
		progress.add_xp(e.data.xp)
		if progress.pending > 0 and not is_choosing():
			_offer_choice()


func is_choosing() -> bool:
	return level_up_panel != null and level_up_panel.is_open()


## 레벨업 선택지를 띄우고 게임을 멈춘다. 고를 것이 없으면 대기 레벨업을 버린다.
func _offer_choice() -> void:
	var pool := build.hero.upgrade_pool if build.hero else null
	var count := run_config.choice_count if run_config else 3
	var choices: Array[UpgradeDef] = pool.roll(rng, progress.stacks, count) if pool else []
	if choices.is_empty() or level_up_panel == null:
		progress.pending = 0
		return
	get_tree().paused = true
	if touch_controller:
		touch_controller.cancel_all()
	level_up_panel.open(choices, progress.level, progress.stacks)


func _on_upgrade_chosen(u: UpgradeDef) -> void:
	build.apply(u)
	progress.record_choice(u)
	if progress.pending > 0 and state.is_playing():
		_offer_choice()
	elif state.is_playing():
		get_tree().paused = false
