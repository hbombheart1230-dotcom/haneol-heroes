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
## 입장 뒤 이야기 인트로 (처음 한 번).
@export var story_intro: StoryIntro
## 설정 화면 (톱니 단추). 바뀌면 스킬 단추 등을 바로 반영.
@export var settings: SettingsScreen
## 앱을 켜면 입장 화면 앞에 한 번 나오는 오프닝 영상.
@export var opening_video: OpeningVideo
## 첫 판 조작 안내 (끝내기 전엔 적이 나오지 않고 시간도 가지 않는다).
@export var tutorial: TutorialData
@export var tutorial_overlay: TutorialOverlay
## 난이도 곡선: 영웅이 이긴 전장 수만큼 적이 강해진다.
@export var difficulty: DifficultyCurve
var _base_spawn := {}
var tutorial_director: TutorialDirector
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
	if settings:
		settings.changed.connect(_on_settings_changed)
		settings.closed.connect(_on_settings_closed)
		settings.opened.connect(func() -> void: settings.exit_mode = flow.exit_mode())
		settings.exit_confirmed.connect(func(mode: StringName) -> void: flow.exit(mode))
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
		spawner.boss_spawned.connect(func(_b: Enemy) -> void: music_cue(&"boss"))
		spawner.hold_check = is_choosing  # 물결 모드: 강화 고르는 동안 다음 물결을 기다린다
		spawner.breather.connect(_on_breather)
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
	music_cue(&"stage")  # 다시 시작하면 무대 곡으로 (같으면 이어서)
	if tutorial and GameSettings.tutorial_enabled and not GameSettings.tutorial_done:
		tutorial_director = TutorialDirector.new(self)
		tutorial_director.start(tutorial)


func _on_settings_changed() -> void:
	var tc := get_node_or_null("TouchController") as TouchController
	if tc:
		tc.skill_button_enabled = GameSettings.skill_button_enabled


## 설정을 닫으면 그 사이 놓친 손가락 떼기를 잊는다 (멈춘 동안 눌린 채로 남지 않게).
func _on_settings_closed() -> void:
	var tc := get_node_or_null("TouchController") as TouchController
	if tc:
		tc.cancel_all()


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
		if spawner and arena.obstacles:
			spawner.blocked_check = arena.obstacles.blocks
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
	if spawner:
		spawner.set_waves(st.waves)  # 하데스 슬라이스: 물결 모드 (데이터가 없으면 지금 방식)
	_apply_difficulty(st)
	if hud:
		hud.stage = st


## 이번 판 무대: 영웅의 무대 순서에서 지금 차례 (GameSettings.stage_picked는 테스트·디버그용 강제 지정).
func run_stage_id() -> StringName:
	if GameSettings.stage_picked and HeroRoute.index_of(stages, GameSettings.stage_id) >= 0:
		return GameSettings.stage_id
	return HeroRoute.current(stages, player.hero if player else null, GameSettings.hero_stages)


## 이긴 뒤 "다음 전장": 이 영웅의 다음 무대를 저장하고 새 판.
func advance_stage() -> void:
	var cur := run_config.stage.id if run_config and run_config.stage else run_stage_id()
	var nxt := HeroRoute.next(stages, cur)
	if player and player.hero:
		var hid := String(player.hero.id)
		GameSettings.hero_stages[hid] = String(nxt)
		GameSettings.hero_clears[hid] = int(GameSettings.hero_clears.get(hid, 0)) + 1
	GameSettings.stage_id = nxt
	GameSettings.save_settings()


## 이 영웅의 난이도 단계 = 이 영웅이 이긴 전장 수.
func difficulty_tier() -> int:
	var hid := String(player.hero.id) if player and player.hero else ""
	return int(GameSettings.hero_clears.get(hid, 0))


## 무대 적 구성에 난이도를 입힌다 (적 데이터 사본, 나오는 간격·최대 수). 여러 번 불러도 겹치지 않게 원래 값에서.
func _apply_difficulty(st: StageTheme) -> void:
	if spawner == null or difficulty == null:
		return
	if _base_spawn.is_empty():
		_base_spawn = {"start": spawner.interval_start, "min": spawner.interval_min, "alive": spawner.max_alive}
	var tier := difficulty_tier()
	var table: Array[EnemyData] = []
	for e in (st.spawn_table if not st.spawn_table.is_empty() else spawner.spawn_table):
		table.append(difficulty.scaled(e, tier))
	spawner.spawn_table = table
	spawner.elite_data = difficulty.scaled(st.elite if st.elite else spawner.elite_data, tier)
	spawner.boss_data = difficulty.scaled(st.boss if st.boss else spawner.boss_data, tier)
	spawner.interval_start = _base_spawn["start"] * difficulty.interval(tier)
	spawner.interval_min = _base_spawn["min"] * difficulty.interval(tier)
	spawner.max_alive = (st.waves.max_alive if st.waves else _base_spawn["alive"]) + difficulty.alive_add(tier)
	spawner.data_scaler = func(e: EnemyData) -> EnemyData: return difficulty.scaled(e, tier)


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
	if tutorial_director and tutorial_director.running():
		tutorial_director.tick(delta)
		return
	if state.is_playing():
		state.tick(delta)
	else:
		_end_time += delta


## 음악 (RunMusic): 영웅 노래 구간 넘나들기·메뉴 곡·승패 곡. 곡 칸은 장면에서 정한다.
## 입장·공통 이야기·영웅 고르기 곡 (비우면 첫 무대 노래의 전주).
@export var menu_track: AudioStream
## 판이 끝났을 때 한 번 트는 짧은 곡 (모든 무대 공용). 비우면 노래의 후주·전주.
@export var victory_track: AudioStream
@export var defeat_track: AudioStream
const SONG_SECTION := RunMusic.SONG_SECTION
var music := RunMusic.new(self)


func music_cue(kind: StringName) -> void:
	music.cue(kind)


func menu_music() -> void:
	music.menu()


func hero_music(hero: HeroData) -> void:
	music.hero(hero)


func stage_music(kind: StringName) -> AudioStream:
	return music.stage_track(kind)


func _on_ended(result: GameState.Result) -> void:
	music_cue(&"victory" if result == GameState.Result.VICTORY else &"defeat")
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
	progress.add_xp(roundi(e.data.xp * (spawner.xp_mult() if spawner else 1.0)))
	if not is_choosing() and (spawner == null or spawner.can_offer()):  # 물결 싸움 중엔 물결 끝까지 쌓아 둔다
		_offer_next()


## 숨 고르기 (물결 끝·보스 단계): 물결 끝이면 마지막 처치 슬로모션, 그리고 쌓인 강화.
func _on_breather(slowmo: bool) -> void:
	if slowmo and is_inside_tree():
		var f := Feedback.feel_data()
		GameTime.stop(get_tree(), f.wave_end_slow_time, f.wave_end_slow_scale)
	if state.is_playing() and not is_choosing():
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
		var choices: Array[UpgradeDef] = []  # 빈 배열 리터럴은 타입이 없어 삼항식에 쓰면 오류
		if pool:
			choices = pool.roll(rng, progress.stacks, count)
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
