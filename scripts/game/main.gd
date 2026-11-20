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
## 고를 수 있는 영웅. 둘 이상이면 앱을 켠 뒤 첫 판 전에 고르기 화면.
@export var heroes: Array[HeroData] = []
@export var hero_select: HeroSelect
## 인트로(입장 단추). 앱을 켠 뒤 한 번만.
@export var title_screen: TitleScreen
## 고를 수 있는 무대 (역사 연표 순). 둘 이상이면 영웅 다음에 고르기 화면.
@export var stages: Array[StageTheme] = []
@export var stage_select: StageSelect
## 입장 뒤 이야기 인트로 (처음 한 번).
@export var story_intro: StoryIntro
## 깨면 탕약이 나오는 물건들 (무대마다 다름).
@export var breakables: BreakableField
## 결과 화면에서 재시작 입력을 받기까지 대기(초). 연타로 바로 넘어가는 것을 막는다.
@export var restart_delay: float = 0.6

var state: GameState
## 판 전 화면 순서 (입장 → 이야기 → 영웅 → 영웅 이야기 → 판).
var flow: StartFlow
var perf := PerfStats.new()
var progress: RunProgress
var build := RunBuild.new()
var rng := RandomNumberGenerator.new()
## 정예 처치로 받을 큰 변형 고르기 대기 수 (레벨업보다 먼저 연다).
var major_pending: int = 0
var _end_time: float = 0.0
## 영웅 고르기 화면이 떠 있어 판이 아직 시작되지 않음.
var waiting_pick: bool = false


func _ready() -> void:
	# 결과 화면에서 재시작 입력을 받으려면 Main은 일시정지 중에도 돌아야 한다.
	# 게임 오브젝트는 일시정지되도록 명시한다 (INHERIT면 Main의 ALWAYS를 물려받음).
	process_mode = Node.PROCESS_MODE_ALWAYS
	flow = StartFlow.new(self)
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
	var saved := hero_by_id(GameSettings.hero_id)
	if player and saved and saved != player.hero:
		player.change_hero(saved)
	if spawner and run_config:
		spawner.elite_times = run_config.elite_times
	_apply_stage(run_config.stage if run_config else null)
	if seal_choice:
		seal_choice.chosen.connect(_on_upgrade_chosen)
	state = GameState.new(survive_time)
	state.ended.connect(_on_ended)
	if player and player.health:
		player.health.died.connect(func(_e: Node) -> void: state.player_died())
	if spawner:
		spawner.enemy_killed.connect(_on_enemy_killed)
		spawner.boss_spawned.connect(func(_b: Enemy) -> void: _switch_music(stage_music(&"boss")))
	if hud:
		hud.state = state
		hud.perf = perf
		hud.progress = progress
		hud.stage = run_config.stage if run_config else null
		hud.can_change_hero = playable_heroes().size() > 1
	_start_flow()


## 판 전 화면 순서 (StartFlow). 화면이 다 끝나면 begin_run.
func _start_flow() -> void:
	flow.next()


## 이번 판 시작: 무대 적용, 성장 준비, 멈춤 풀기, 무대 곡.
func begin_run() -> void:
	_apply_stage(stage_by_id(run_stage_id()))
	_begin_build()
	waiting_pick = false
	get_tree().paused = false
	if Feedback.instance and run_config and run_config.stage:  # 다시 시작하면 무대 곡으로 (같으면 이어서)
		Feedback.instance.play_music(stage_music(&"stage"), 0.6)


func playable_heroes() -> Array[HeroData]:
	var out: Array[HeroData] = []
	for h in heroes:
		if h and h.playable:
			out.append(h)
	return out


## 무대 바꾸기: 바닥·소품, 적 구성. 고르기 화면과 시작 때 부른다.
func _apply_stage(st: StageTheme) -> void:
	if st == null:
		return
	if run_config:
		run_config.stage = st
	var arena := get_node_or_null("Arena") as Arena
	if arena:
		arena.apply_theme(st)
		arena.clamp_camera(get_node_or_null("Player/Camera2D") as Camera2D)
		if breakables:
			breakables.obstacles = arena.obstacles
			breakables.setup(st.breakable, arena.rect.grow(-maxf(st.prop_inset, 160.0)), st.seed)
	if spawner and not st.spawn_table.is_empty():
		spawner.spawn_table = st.spawn_table
		spawner.spawn_weights = st.spawn_weights
		spawner.unlock_times = st.unlock_times
	if spawner and st.elite:
		spawner.elite_data = st.elite
	if spawner and st.boss:
		spawner.boss_data = st.boss
	if hud:
		hud.stage = st


## 이번 판 무대: 시험판에서 직접 고른 무대가 있으면 그것, 아니면 영웅의 무대 순서에서 지금 차례.
func run_stage_id() -> StringName:
	if GameSettings.stage_picked and HeroRoute.index_of(stages, GameSettings.stage_id) >= 0:
		return GameSettings.stage_id
	return HeroRoute.current(stages, player.hero if player else null, GameSettings.hero_stages)


## 이긴 뒤 "다음 전장": 이 영웅의 다음 무대를 저장하고 새 판.
func advance_stage() -> void:
	var cur := run_config.stage.id if run_config and run_config.stage else run_stage_id()
	var nxt := HeroRoute.next(stages, cur)
	if player and player.hero:
		GameSettings.hero_stages[String(player.hero.id)] = String(nxt)
	GameSettings.stage_id = nxt
	GameSettings.save_settings()


func stage_by_id(id: StringName) -> StageTheme:
	for st in stages:
		if st and st.id == id:
			return st
	return run_config.stage if run_config else null


func hero_by_id(id: StringName) -> HeroData:
	for h in playable_heroes():
		if h.id == id:
			return h
	return null


func _begin_build() -> void:
	if player:
		build.begin(player, player.get_node_or_null("SkillCaster") as SkillCaster,
			player.get_node_or_null("AutoAttack") as AutoAttack)


## 렌더 프레임 기준 성능 기록 (플레이 중에만).
func _process(delta: float) -> void:
	if waiting_pick:
		return
	if state.is_playing() and not is_choosing():  # 느린 시간 동안은 프레임 시간이 왜곡돼 제외
		perf.sample(delta, spawner.alive_count() if spawner else 0)


func _physics_process(delta: float) -> void:
	if waiting_pick:
		return
	if state.is_playing():
		state.tick(delta)
	else:
		_end_time += delta


## 무대 곡 고르기: &"stage" / &"boss" / &"victory" / &"defeat". 비어 있으면 무대 곡.
func stage_music(kind: StringName) -> AudioStream:
	var st := run_config.stage if run_config else null
	if st == null:
		return null
	var s: AudioStream = {&"boss": st.boss_music, &"victory": st.victory_music, &"defeat": st.defeat_music}.get(kind)
	return s if s else st.music


func _switch_music(stream: AudioStream) -> void:
	if Feedback.instance and stream:
		Feedback.instance.play_music(stream, 0.6)


func _on_ended(result: GameState.Result) -> void:
	_switch_music(stage_music(&"victory" if result == GameState.Result.VICTORY else &"defeat"))
	if hud and result == GameState.Result.VICTORY and run_config and run_config.stage:
		hud.next_stage = stage_by_id(HeroRoute.next(stages, run_config.stage.id))
	_end_time = 0.0
	if result == GameState.Result.VICTORY and run_config and run_config.stage:
		if GameSettings.mark_cleared(run_config.stage.id):  # 다음 무대가 열린다
			GameSettings.save_settings()
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
		if is_change_hero_area((event as InputEventScreenTouch).position):
			GameSettings.hero_picked = false  # 다음 판 전에 고르기 화면 (영웅 → 시험판이면 전장)
			GameSettings.stage_picked = false
		elif state.result == GameState.Result.VICTORY:
			advance_stage()
		restart()


## 결과 화면 아래 띠 ("영웅 바꾸기"). HUD가 같은 영역을 그린다.
func is_change_hero_area(pos: Vector2) -> bool:
	return playable_heroes().size() > 1 and pos.y >= get_viewport().get_visible_rect().size.y - Hud.CHANGE_HERO_BAND


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
	Feedback.ui()
	build.apply(u)
	if major:
		major_pending = maxi(major_pending - 1, 0)
		progress.stacks[u.id] = int(progress.stacks.get(u.id, 0)) + 1
	else:
		progress.record_choice(u)
	if state.is_playing():
		_offer_next()
