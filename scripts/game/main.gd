extends Node2D
## 전투 씬 연결: 한 판(런) 진행, 처치·경험치·레벨업 선택, 보스 처치 승리, 게임오버, 탭하여 재시작.

@export var player: Player
@export var spawner: EnemySpawner
@export var hud: Hud
@export var survive_time: float = 60.0
## 런 규칙 (경험치·보스 시각). 있으면 survive_time 등을 이 값으로 덮어쓴다.
@export var run_config: RunConfig
## 레벨업·정예 보상 고르기 (전장에 인장, 게임은 멈추지 않고 느려진다).
@export var seal_choice: SealChoice
## 결과 화면에서 재시작 입력을 받기까지 대기(초). 연타로 바로 넘어가는 것을 막는다.
@export var restart_delay: float = 0.6

var state: GameState
var perf := PerfStats.new()
var progress: RunProgress
var build := RunBuild.new()
var rng := RandomNumberGenerator.new()
## 정예 처치로 받을 큰 변형 고르기 대기 수 (레벨업보다 먼저 연다).
var major_pending: int = 0
var _end_time: float = 0.0


func _ready() -> void:
	# 결과 화면에서 재시작 입력을 받으려면 Main은 일시정지 중에도 돌아야 한다.
	# 게임 오브젝트는 일시정지되도록 명시한다 (INHERIT면 Main의 ALWAYS를 물려받음).
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 이전 판의 히트스톱·예고 공격 슬롯이 남지 않게 초기화.
	GameTime.reset()
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
	if spawner and run_config:
		spawner.elite_times = run_config.elite_times
	if seal_choice:
		seal_choice.chosen.connect(_on_upgrade_chosen)
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
	if state.is_playing() and not is_choosing():  # 느린 시간 동안은 프레임 시간이 왜곡돼 제외
		perf.sample(delta, spawner.alive_count() if spawner else 0)


func _physics_process(delta: float) -> void:
	if state.is_playing():
		state.tick(delta)
	else:
		_end_time += delta


func _on_ended(_result: GameState.Result) -> void:
	_end_time = 0.0
	if seal_choice:
		seal_choice.close()
	GameTime.reset()
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
	if e.data == null or not state.is_playing():
		return
	if e.data.is_elite:
		major_pending += 1
	progress.add_xp(e.data.xp)
	if not is_choosing():
		_offer_next()


func is_choosing() -> bool:
	return seal_choice != null and seal_choice.is_open()


## 대기 중인 고르기를 연다: 큰 변형(정예) → 레벨업 순. 고를 것이 없으면 그 대기를 버린다.
func _offer_next() -> void:
	if seal_choice == null or player == null or build.hero == null:
		return
	var count := run_config.choice_count if run_config else 3
	if major_pending > 0:
		var majors := build.hero.major_pool.roll(rng, progress.stacks, count) if build.hero.major_pool else []
		if not majors.is_empty():
			seal_choice.open(majors, player.global_position, true, progress.stacks)
			return
		major_pending = 0
	if progress.pending > 0:
		var pool := build.hero.upgrade_pool
		var choices: Array[UpgradeDef] = pool.roll(rng, progress.stacks, count) if pool else []
		if not choices.is_empty():
			seal_choice.open(choices, player.global_position, false, progress.stacks)
			return
		progress.pending = 0


func _on_upgrade_chosen(u: UpgradeDef, major: bool) -> void:
	build.apply(u)
	if major:
		major_pending = maxi(major_pending - 1, 0)
		progress.stacks[u.id] = int(progress.stacks.get(u.id, 0)) + 1
	else:
		progress.record_choice(u)
	if state.is_playing():
		_offer_next()
