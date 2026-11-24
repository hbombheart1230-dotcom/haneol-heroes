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
## 숨 고르기 (물결 끝 = slowmo true, 보스 단계 바뀜 = false): Main이 쌓인 강화를 연다.
signal breather(slowmo: bool)
## 물결이 곧 시작된다 (번호 0부터, 우두머리 물결 제외): 패 고르기가 끝나 숨 고르기가 다시 흐르는 때, 적 등장 전에.
signal wave_announce(index: int, elite: bool)
var _announced: int = -1

## 물결 모드 (무대 데이터 StageTheme.waves). null이면 시간 따라 계속 나오는 지금 방식.
var waves: WaveRunner
## 예고 중인 등장 자리 수 (화면 최대에 센다).
var _warnings: int = 0
## 중간 우두머리 처치 연출이 끝나는 시각 (GameTime.now_ms, BossStaging.play_finale). 그때까지 물결이 끝나지 않아
## 숨 고르기·패 고르기가 연출 뒤에 뜬다. 판 시각이라 시뮬레이션(GameTime.clock)에서도 풀린다.
var finale_until_ms: int = 0
## true면 다음 물결을 기다린다 (강화 고르는 중, Main이 넣는다).
var hold_check: Callable
## 물결 등장 자리가 막힌 곳(벽·바위 같은 장애물)인지 묻는 함수 (p, 여유) → bool. 비면 검사 없음.
var blocked_check: Callable
## 막힌 자리면 다시 뽑는 횟수.
@export var spawn_point_tries: int = 8
## 등장 자리와 장애물 사이 여유 (px, 몸 반지름쯤).
@export var spawn_clearance: float = 24.0
## 0 이상이면 near_point가 보이는 화면(카메라 줌 반영) 안 여유 px에 들게 타원으로 줄인다 (물결 모드).
var view_margin: float = -1.0
## 물결 적 데이터에 난이도를 입힌다 (Main이 넣는다, 비면 그대로).
var data_scaler: Callable
## 장면에 정해 둔 무리 이벤트 켜짐 (물결 무대에서 물결 없는 무대로 바꾸면 되돌린다).
var _horde_default: bool = true


func _ready() -> void:
	_horde_default = horde_enabled
	AttackTokens.clear()  # 새 판: 지난 판의 공격권이 남지 않게


func alive_count() -> int:
	var n := 0
	for c in get_children():
		if c is Enemy and not c.is_queued_for_deletion() and not EnemyDeathPose.of(c):  # 쓰러진 몸은 세지 않는다
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
		BossStaging.attach(self, e)  # 박자·연출 (boss_feel이 있는 보스만)
		boss_spawned.emit(e)
	return e


## 정예 한 마리 (동시 최대 수와 상관없이 나온다).
func spawn_elite(at: Vector2 = Vector2.INF, d: EnemyData = null) -> Enemy:
	var ed := d if d else elite_data
	if ed and ed.boss_feel:  # 중간 보스: 변종 없이, 박자·연출 (BossStaging)
		var m := spawn_at(ed, at)
		if m:
			BossStaging.attach(self, m)
			elite_spawned.emit(m)
		return m
	var affixes := Enemy.ai_data().elite_affixes
	var af: EliteAffixData = affixes[rng.randi() % affixes.size()] if not affixes.is_empty() else null
	var e := spawn_at(elite_data, at, func(en: Enemy) -> void: en.affix = af) if elite_data else null
	if e:
		elite_spawned.emit(e)
	return e


func _spawn_special(d: EnemyData) -> Enemy:
	return spawn_at(d, Vector2.INF)


## at(월드 좌표)에 생성 (INF면 고리 영역 무작위). configure는 add_child 전에 적을 꾸민다 (변종·떼 배율).
## extra = true(무리·분열)면 max_alive + horde_extra_alive까지만.
func spawn_at(d: EnemyData, at: Vector2, configure: Callable = Callable(), extra: bool = false) -> Enemy:
	if enemy_scene == null or target == null:
		return null
	if extra and alive_count() >= max_alive + Enemy.ai_data().horde_extra_alive:
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
	# 분열 변종: 작은 적으로 갈라진다 (변종은 물려받지 않음). 판이 끝났으면(플레이어 사망) 갈라지지 않는다.
	var over := not active or (target is Player and (target as Player).is_dead())
	if en.affix and en.affix.split_count > 0 and not over:
		var af := en.affix
		for i in af.split_count:
			var off := Vector2.from_angle(TAU * i / af.split_count) * en.body_radius * 2.0
			_split_later.call_deferred(en.data, en.global_position + off, af)


## 분열 조각 (한 프레임 뒤). 그사이 판이 끝났으면 만들지 않는다.
func _split_later(d: EnemyData, at: Vector2, af: EliteAffixData) -> void:
	if not active or (target is Player and (target as Player).is_dead()):
		return
	spawn_at(d, at, func(s: Enemy) -> void:
		s.hp_mult = af.split_hp_mult
		s.size_mult = af.split_scale, true)


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
				n += 1 if spawn_at(basic, p, Callable(), true) else 0
		HordeDirector.Kind.WALL:
			for p in horde.wall_points(center, side):
				n += 1 if spawn_at(basic, p, func(e: Enemy) -> void: e.set_meta(&"sweep", -side), true) else 0
		_:
			for p in horde.swarm_points(center, side, rng):
				n += 1 if spawn_at(basic, p, func(e: Enemy) -> void:
					e.hp_mult = ai.swarm_hp_mult
					e.speed_mult = ai.swarm_speed_mult
					e.size_mult = ai.swarm_scale, true) else 0
	horde_started.emit(kind)
	return n


## 물결 모드 켜기·끄기 (새 판마다 처음부터).
func set_waves(d: WaveSetData) -> void:
	waves = WaveRunner.new(d) if d else null
	view_margin = d.spawn_screen_margin if d else -1.0
	_warnings = 0
	finale_until_ms = 0
	horde_enabled = false if d else _horde_default


## 중간 우두머리 처치 연출 중인지.
func finale_playing() -> bool:
	return GameTime.now_ms() < finale_until_ms


## 물결 모드에서 처치 경험치 배율 (아니면 1).
func xp_mult() -> float:
	return waves.data.xp_mult if waves else 1.0


## 지금 강화를 열어도 되는지 (물결 싸움 중·보스전 중에는 숨 고르기까지 쌓아 둔다).
func can_offer() -> bool:
	return waves == null or waves.phase == WaveRunner.Phase.GAP or waves.phase == WaveRunner.Phase.BOSS_WAIT


func _tick_waves(delta: float) -> void:
	var hold := hold_check.is_valid() and bool(hold_check.call())
	if waves.phase == WaveRunner.Phase.GAP and not hold:
		var nxt := waves.index + 1
		if nxt != _announced and nxt < waves.data.waves.size():
			_announced = nxt
			wave_announce.emit(nxt, WaveTrack.kinds(waves.data)[nxt] == WaveTrack.Kind.ELITE)
	match waves.tick(delta, alive_count() + _warnings + (1 if finale_playing() else 0), hold):
		WaveRunner.Event.CLEARED:
			breather.emit(true)
		WaveRunner.Event.BOSS:
			spawn_boss()
	while true:
		var r := waves.next_spawn(alive_count() + _warnings, max_alive)
		if r.is_empty():
			break
		var d: EnemyData = r[0]
		var group := waves.elite_group() if d == null else []
		for g: EnemyData in group:  # 중간 우두머리 무리: 한꺼번에 (각자 다른 자리)
			warn_spawn(g, near_point(target.global_position, waves.data.spawn_min, waves.data.spawn_max), true)
		if group.is_empty():
			warn_spawn(d if d else elite_data, near_point(target.global_position, waves.data.spawn_min, waves.data.spawn_max),
				d == null)


## 화면 안 등장 자리: center에서 min~max px (전장 안).
func near_point(center: Vector2, dmin: float, dmax: float) -> Vector2:
	var p := center
	var tries := maxi(spawn_point_tries, 1)
	for i in tries * 3:  # 장애물 속이면 다시 뽑는다 (Codex e423e86 지적); 한 바퀴 다 막히면 둘레를 넓혀 두 바퀴 더 (벽 많은 경복궁)
		var far := dmax * (1.0 + 0.5 * float(i / tries))
		p = center + fit_view(Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(dmin, far), far)
		if arena_rect.has_area():
			p = p.clamp(arena_rect.position, arena_rect.end)
		if not blocked_check.is_valid() or not bool(blocked_check.call(p, spawn_clearance)):
			break
	return p


## 화면 안에 들게 줄인 등장 오프셋: 가로·세로를 각각 (보이는 반폭·반높이 − 여유) ÷ dmax 배까지 (줄일 때만).
func fit_view(off: Vector2, dmax: float) -> Vector2:
	if view_margin < 0.0 or not is_inside_tree():
		return off
	var half := view_half()
	if half == Vector2.INF:
		return off
	return Vector2(off.x * clampf((half.x - view_margin) / maxf(dmax, 1.0), 0.2, 1.0),
		off.y * clampf((half.y - view_margin) / maxf(dmax, 1.0), 0.2, 1.0))


## 보이는 화면의 반폭·반높이 (월드 px, 카메라 줌 반영). 카메라가 없으면 INF.
func view_half() -> Vector2:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return Vector2.INF
	return get_viewport().get_visible_rect().size / cam.zoom * 0.5


## at이 장애물 속이거나 전장 밖이면 around 둘레에서 다시 뽑은 자리 (보스 부하 소환).
func safe_point(at: Vector2, around: Vector2, dmin: float, dmax: float) -> Vector2:
	var p := at.clamp(arena_rect.position, arena_rect.end) if arena_rect.has_area() else at
	if blocked_check.is_valid() and bool(blocked_check.call(p, spawn_clearance)):
		return near_point(around, dmin, dmax)
	return p


## 먹 번짐 예고 뒤 등장 (물결·보스 부하). 예고 중에도 화면 최대에 센다.
## 무리 정예(WaveData.elite_group)에 입힐 배율 (영웅 보스 배율 × 난이도 단계, StageApply가 넣는다). 없으면 data_scaler.
var elite_scaler: Callable


func warn_spawn(d: EnemyData, at: Vector2, elite: bool = false) -> void:
	if d == null:
		return
	var w := SpawnWarning.new()
	w.time = waves.data.warn_time if waves else 0.6
	w.position = at - global_position
	_warnings += 1
	w.done = func() -> void:
		_warnings = maxi(_warnings - 1, 0)
		if not active:
			return
		var dd: EnemyData = data_scaler.call(d) if data_scaler.is_valid() else d
		if elite:
			spawn_elite(at, null if d == elite_data else (elite_scaler.call(d) if elite_scaler.is_valid() else dd))
		else:
			spawn_at(dd, at)
	add_child(w)


func tick(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	if waves:
		_tick_waves(delta)
		return
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
