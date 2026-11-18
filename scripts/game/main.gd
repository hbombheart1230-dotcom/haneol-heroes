extends Node2D
## P0 전투 씬 연결: 60초 생존, 처치 수, 게임오버·생존 성공, 탭하여 재시작.

@export var player: Player
@export var spawner: EnemySpawner
@export var hud: Hud
@export var survive_time: float = 60.0
## 결과 화면에서 재시작 입력을 받기까지 대기(초). 연타로 바로 넘어가는 것을 막는다.
@export var restart_delay: float = 0.6

var state: GameState
var perf := PerfStats.new()
var _end_time: float = 0.0


func _ready() -> void:
	# 결과 화면에서 재시작 입력을 받으려면 Main은 일시정지 중에도 돌아야 한다.
	# 게임 오브젝트는 일시정지되도록 명시한다 (INHERIT면 Main의 ALWAYS를 물려받음).
	process_mode = Node.PROCESS_MODE_ALWAYS
	for c in get_children():
		if not (c is CanvasLayer):
			c.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().paused = false
	state = GameState.new(survive_time)
	state.ended.connect(_on_ended)
	if player and player.health:
		player.health.died.connect(func(_e: Node) -> void: state.player_died())
	if spawner:
		spawner.enemy_killed.connect(func(_e: Enemy) -> void: state.add_kill())
	if hud:
		hud.state = state
		hud.perf = perf


## 렌더 프레임 기준 성능 기록 (플레이 중에만).
func _process(delta: float) -> void:
	if state.is_playing():
		perf.sample(delta, spawner.alive_count() if spawner else 0)


func _physics_process(delta: float) -> void:
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
