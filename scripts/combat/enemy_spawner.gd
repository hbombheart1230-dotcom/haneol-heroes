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
## 정예와 등장 시각(초, 오름차순). 시각마다 한 마리.
@export var elite_data: EnemyData
@export var elite_times: PackedFloat32Array = PackedFloat32Array()
var _elites_spawned: int = 0
signal elite_spawned(elite: Enemy)

var elapsed: float = 0.0
var rng := RandomNumberGenerator.new()
var _cooldown: float = 0.0
## 무리 이벤트 (포위·휩쓸기·떼). horde_enabled가 false면 없음 (테스트).
@export var horde_enabled: bool = true
var horde := HordeDirector.new(Enemy.ai_data())
signal horde_started(kind: int)


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
	if boss_data == null or boss_spawned_once:
		return null
	var e := _spawn_special(boss_data)
	if e:
		boss_spawned_once = true
		boss_spawned.emit(e)
	return e


## 정예 한 마리 (동시 최대 수와 상관없이 나온다).
func spawn_elite() -> Enemy:
	var affixes := Enemy.ai_data().elite_affixes
	var af: EliteAffixData = affixes[rng.randi() % affixes.size()] if not affixes.is_empty() else null
	var e := spawn_at(elite_data, Vector2.INF, func(en: Enemy) -> void: en.affix = af) if elite_data else null
	if e:
		elite_spawned.emit(e)
	return e


func _spawn_special(d: EnemyData) -> Enemy:
	return spawn_at(d, Vector2.INF)


## at(월드 좌표)에 생성 (INF면 고리 영역 무작위). configure는 add_child 전에 적을 꾸민다 (변종·떼 배율).
func spawn_at(d: EnemyData, at: Vector2, configure: Callable = Callable()) -> Enemy:
	if enemy_scene == null or target == null:
		return null
	var e := enemy_scene.instantiate() as Enemy
	e.data = d
	e.target = target
	var p := pick_spawn_position(target.global_position) if at == Vector2.INF else at
	if arena_rect.has_area():
		p = p.clamp(arena_rect.position, arena_rect.end)
	e.position = p - global_position
	if configure.is_valid():
		configure.call(e)
	e.killed.connect(_on_killed)
	add_child(e)
	return e


func _on_killed(en: Enemy) -> void:
	enemy_killed.emit(en)
	# 분열 변종: 작은 적으로 갈라진다 (변종은 물려받지 않음).
	if en.affix and en.affix.split_count > 0:
		var af := en.affix
		for i in af.split_count:
			var off := Vector2.from_angle(TAU * i / af.split_count) * en.body_radius * 2.0
			spawn_at.call_deferred(en.data, en.global_position + off, func(s: Enemy) -> void:
				s.hp_mult = af.split_hp_mult
				s.size_mult = af.split_scale)


## 무리 이벤트 하나를 연다 (종류는 HordeDirector.Kind). 생성한 수를 돌려준다.
func start_horde(kind: int) -> int:
	if spawn_table.is_empty() or target == null:
		return 0
	var ai := Enemy.ai_data()
	var basic: EnemyData = spawn_table[0]
	var center := target.global_position
	var side := Vector2.from_angle(rng.randf_range(0.0, TAU))
	var n := 0
	match kind:
		HordeDirector.Kind.RING:
			for p in horde.ring_points(center):
				n += 1 if spawn_at(basic, p) else 0
		HordeDirector.Kind.WALL:
			for p in horde.wall_points(center, side):
				n += 1 if spawn_at(basic, p, func(e: Enemy) -> void: e.set_meta(&"sweep", -side)) else 0
		_:
			for p in horde.swarm_points(center, side, rng):
				n += 1 if spawn_at(basic, p, func(e: Enemy) -> void:
					e.hp_mult = ai.swarm_hp_mult
					e.speed_mult = ai.swarm_speed_mult
					e.size_mult = ai.swarm_scale) else 0
	horde_started.emit(kind)
	return n


func tick(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	if boss_data and not boss_spawned_once and elapsed >= boss_time:
		spawn_boss()
	while _elites_spawned < elite_times.size() and elapsed >= elite_times[_elites_spawned]:
		_elites_spawned += 1
		spawn_elite()
	if horde_enabled:
		var k := horde.tick(elapsed)
		if k >= 0:
			start_horde(k)
	_cooldown -= delta
	while _cooldown <= 0.0:
		_cooldown += current_interval()
		spawn_one()


func _physics_process(delta: float) -> void:
	tick(delta)
