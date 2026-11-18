class_name EnemySpawner
extends Node2D
## 플레이어 주변 화면 밖 고리 영역에 적을 생성한다. 동시 최대 max_alive마리.

signal enemy_killed(enemy: Enemy)
signal boss_spawned(boss: Enemy)

@export var enemy_scene: PackedScene
@export var target: Node2D
@export var max_alive: int = 30
## 생성 간격(초). 시작 값에서 60초에 걸쳐 최소 값까지 줄어든다. 실험 값.
@export var interval_start: float = 0.6
@export var interval_min: float = 0.2
@export var ramp_time: float = 60.0
## 플레이어로부터 생성 거리 (세로 화면 밖 근처).
@export var ring_min: float = 520.0
@export var ring_max: float = 700.0
## 생성 가능 영역 (월드 좌표). 크기 0이면 제한 없음.
@export var arena_rect: Rect2 = Rect2()
@export var active: bool = true
## 적 종류와 가중치, 등장 시작 시각(초). 비어 있으면 enemy_scene 기본 데이터만.
@export var spawn_table: Array[EnemyData] = []
@export var spawn_weights: PackedFloat32Array = PackedFloat32Array()
@export var unlock_times: PackedFloat32Array = PackedFloat32Array()
## 보스와 등장 시각(초). 한 번만 나온다. null이면 보스 없음.
@export var boss_data: EnemyData
@export var boss_time: float = 40.0

var boss_spawned_once: bool = false

var elapsed: float = 0.0
var rng := RandomNumberGenerator.new()
var _cooldown: float = 0.0


func alive_count() -> int:
	var n := 0
	for c in get_children():
		if c is Enemy and not c.is_queued_for_deletion():
			n += 1
	return n


func current_interval() -> float:
	return lerpf(interval_start, interval_min, clampf(elapsed / maxf(ramp_time, 0.001), 0.0, 1.0))


## 중심에서 고리 영역의 무작위 위치. arena_rect 안으로 보정한다.
func pick_spawn_position(center: Vector2) -> Vector2:
	var angle := rng.randf_range(0.0, TAU)
	var dist := rng.randf_range(ring_min, ring_max)
	var p := center + Vector2.from_angle(angle) * dist
	if arena_rect.has_area():
		p = p.clamp(arena_rect.position, arena_rect.end)
	return p


## 지금 시각에 등장 가능한 종류 중 가중치로 하나 고른다. 표가 비면 null (씬 기본 데이터).
func pick_data() -> EnemyData:
	var total := 0.0
	var pool: Array = []
	for i in spawn_table.size():
		var unlock := unlock_times[i] if i < unlock_times.size() else 0.0
		if elapsed < unlock:
			continue
		var w := spawn_weights[i] if i < spawn_weights.size() else 1.0
		if w <= 0.0:
			continue
		pool.append([spawn_table[i], w])
		total += w
	if pool.is_empty():
		return null
	var r := rng.randf() * total
	for entry in pool:
		r -= float(entry[1])
		if r <= 0.0:
			return entry[0]
	return pool[pool.size() - 1][0]


## 생성 성공 시 적 노드, 아니면 null.
func spawn_one() -> Enemy:
	if enemy_scene == null or target == null or alive_count() >= max_alive:
		return null
	var e := enemy_scene.instantiate() as Enemy
	var picked := pick_data()
	if picked:
		e.data = picked
	e.target = target
	e.position = pick_spawn_position(target.global_position) - global_position
	e.killed.connect(func(en: Enemy) -> void: enemy_killed.emit(en))
	add_child(e)
	return e


func spawn_boss() -> Enemy:
	if boss_data == null or enemy_scene == null or target == null or boss_spawned_once:
		return null
	boss_spawned_once = true
	var e := enemy_scene.instantiate() as Enemy
	e.data = boss_data
	e.target = target
	e.position = pick_spawn_position(target.global_position) - global_position
	e.killed.connect(func(en: Enemy) -> void: enemy_killed.emit(en))
	add_child(e)
	boss_spawned.emit(e)
	return e


func tick(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	if boss_data and not boss_spawned_once and elapsed >= boss_time:
		spawn_boss()
	_cooldown -= delta
	while _cooldown <= 0.0:
		_cooldown += current_interval()
		spawn_one()


func _physics_process(delta: float) -> void:
	tick(delta)
