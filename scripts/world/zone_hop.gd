class_name ZoneHop
extends Node
## 구역 건너뛰기 (StageTheme.zones, 하데스의 섬 건너뛰기): 구역의 마지막 물결을 깨면 다음 물결·우두머리를 붙잡아 두고
## (spawner.hold_check), 강화 고르기가 끝나면 다음 구역 쪽 화살·안내를 띄운다. 그쪽으로 내닫으면 내닫기가 끝난 뒤
## 뛰어오름 → 먹 덮기 → 구역 바꾸기(색·걸을 곳·내려앉을 자리, 남은 탄 지움) → 내려앉기 → 이어서 물결. 조작은 늘리지 않는다.
## 붙이기: ZoneHop.attach(main) (main이 hold_check를 정한 뒤). 구역이 둘 미만인 무대에서는 아무것도 하지 않는다.

signal hopped(zone_index: int)
## 먹이 다 덮인 사이 새 구역으로 바뀐 순간 (영웅 걸을 곳·자리가 바뀐 뒤, 화면은 가려짐): 같이 싸우는 영웅 등이 따라 옮긴다.
signal entered(zone: ZoneData)

enum State { FIGHT, AWAIT, HOP }

const DEFAULT_FEEL := preload("res://data/stages/zones/zone_hop_feel.tres")

var main: Node
var plan := ZonePlan.new()
var feel: ZoneHopFeel = DEFAULT_FEEL
var state: State = State.FIGHT
var view: ZoneHopView
var _stage: StageTheme
var _wants_hop := false
var _tween: Tween
## 넘어가는 동안 멈춰 둔 조작 노드와 원래 process_mode (터치·기술·부르기 단추: 공중에서 치거나 부르지 않게).
var _frozen := {}


static func attach(m: Node) -> ZoneHop:
	var z := ZoneHop.new()
	z.main = m
	m.add_child(z)
	var sp: EnemySpawner = m.spawner
	if sp:
		var prev: Callable = sp.hold_check
		sp.hold_check = func() -> bool: return (prev.is_valid() and bool(prev.call())) or z.holding()
	return z


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	view = ZoneHopView.new()
	main.add_child(view)
	var p := _player()
	if p:
		p.dash_started.connect(_on_dash_started)
		p.dash_ended.connect(_on_dash_ended)


## 다음 물결을 붙잡아 두는 중 (화살을 기다림·넘어가는 중). 구역 끝 물결을 깬 바로 그 프레임부터 (생성기가 먼저 돌아도
## 다음 물결 알림이 새지 않게 상태를 기다리지 않고 바로 본다).
func holding() -> bool:
	return plan.active() and (state != State.FIGHT or _zone_cleared())


func _zone_cleared() -> bool:
	var sp: EnemySpawner = main.spawner
	var w := sp.waves if sp else null
	return w != null and w.index >= 0 and (w.phase == WaveRunner.Phase.GAP or w.phase == WaveRunner.Phase.BOSS_WAIT) 		and plan.ends_zone(w.index)


func _physics_process(_delta: float) -> void:
	var st: StageTheme = main.run_config.stage if main.run_config else null
	if st != _stage:
		_reset(st)
	if not plan.active():
		return
	var sp: EnemySpawner = main.spawner
	var w := sp.waves if sp else null
	if state == State.FIGHT and w and w.index >= 0 and (w.phase == WaveRunner.Phase.GAP or w.phase == WaveRunner.Phase.BOSS_WAIT) \
			and plan.ends_zone(w.index):
		state = State.AWAIT
	var p := _player()
	var show: bool = state == State.AWAIT and p != null and not main.is_choosing() and main.state.is_playing()
	view.show_arrow(show, p.global_position if p else Vector2.ZERO, _exit_dir(p.global_position) if p else Vector2.UP,
		plan.prompt(), feel)


## 영웅에서 넘어갈 쪽 (가까운 난간 자리, 없으면 구역 exit_dir).
func _exit_dir(from: Vector2) -> Vector2:
	var e := plan.nearest_exit(from)
	if e == Vector2.INF or from.distance_squared_to(e) < 1.0:
		return plan.zone().exit_dir.normalized() if plan.zone() else Vector2.UP
	return (e - from).normalized()


func _reset(st: StageTheme) -> void:
	_stage = st
	var list: Array[ZoneData] = st.zones if st else []
	plan = ZonePlan.new(list)
	feel = st.zone_hop if st and st.zone_hop else DEFAULT_FEEL
	state = State.FIGHT
	if plan.active():
		_apply(plan.zone(), false)


func _on_dash_started(dir: Vector2) -> void:
	if state != State.AWAIT or main.is_choosing() or plan.zone() == null:
		return
	var p := _player()
	if p and plan.is_hop_dash(p.global_position, dir, feel.dash_angle):  # 난간 자리 가까이서 그쪽으로 (ZonePlan)
		_wants_hop = true  # 내닫기가 끝나면 뛰어오른다 (내닫기 자세·거리는 그대로)


func _on_dash_ended() -> void:
	if _wants_hop and state == State.AWAIT:
		_wants_hop = false
		_hop()


func _hop() -> void:
	var p := _player()
	var nxt := plan.next_zone()
	if p == null or nxt == null:
		return
	state = State.HOP
	view.show_arrow(false, Vector2.ZERO, Vector2.UP, "", feel)
	var exit := _exit_dir(p.global_position)
	var rail := plan.nearest_exit(p.global_position)  # 난간을 넘어 바다 위로: 난간 자리를 지나 exit 쪽으로
	p.grant_invulnerability(feel.rise_time + feel.cover_time + feel.land_time + 0.6)
	p.set_physics_process(false)
	p.velocity = Vector2.ZERO
	_freeze_input(true)
	var art := p.get_node_or_null("PlayerView") as Node2D
	var pv := art as PlayerView
	if pv and pv.has_anim(String(feel.leap_anim)):  # 달려 멀리뛰기 (넘어가는 내내, 내려앉으면 on_land)
		pv.play_oneshot(String(feel.leap_anim), feel.rise_time + feel.cover_time + feel.land_time, feel.leap_from)
	var from := p.global_position
	var to := (rail if rail != Vector2.INF else from) + exit * feel.rise_dist
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(func(t: float) -> void:
		p.global_position = from.lerp(to, t)
		if art:
			art.position.y = -sin(t * PI * 0.5) * feel.rise_height
		view.cover = clampf((t - feel.cover_from) / maxf(1.0 - feel.cover_from, 0.01), 0.0, 1.0), 0.0, 1.0, feel.rise_time)
	_tween.tween_callback(func() -> void: _enter(p, exit))
	_tween.tween_interval(feel.cover_time)
	_tween.tween_method(func(t: float) -> void:
		var land := plan.zone().entry
		p.global_position = land - exit * feel.land_dist * (1.0 - t)
		if art:
			art.position.y = -cos(t * PI * 0.5) * feel.land_height
		view.cover = clampf(1.0 - t / maxf(feel.uncover_by, 0.01), 0.0, 1.0), 0.0, 1.0, feel.land_time)
	_tween.tween_callback(func() -> void: _landed(p, art))


## 먹이 다 덮인 사이: 구역을 바꾸고 영웅을 내려앉을 자리 뒤 하늘로.
func _enter(p: Player, exit: Vector2) -> void:
	var z := plan.advance()
	if z == null:
		return
	_apply(z, true)
	p.global_position = z.entry - exit * feel.land_dist
	for c in p.get_tree().get_nodes_in_group(CritterSkill.GROUP):  # 사임당 풀벌레는 영웅을 따라 넘어온다
		if c is Node2D:
			(c as Node2D).global_position = z.entry + Vector2(randf_range(-60, 60), randf_range(-40, 40))
	var cam := p.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.reset_smoothing()
	view.title(z.title, feel.title_time)
	entered.emit(z)


func _landed(p: Player, art: Node2D) -> void:
	if art:
		art.position.y = 0.0
	p.set_physics_process(true)
	_freeze_input(false)
	var pv := art as PlayerView
	if pv:
		pv.on_land()
	view.cover = 0.0
	state = State.FIGHT
	hopped.emit(plan.current)


## 구역 입히기: 배경 색, 걸을 수 있는 곳, (넘어올 때) 남은 탄 지우기.
func _apply(z: ZoneData, clear_shots: bool) -> void:
	var arena := main.get_node_or_null("Arena") as Arena
	ZoneLook.apply(arena, z, _stage)  # 구역 배 그림·소품·막는 것·빛
	if arena and arena.map:
		_wash_layer(arena).show_wash(z.wash, arena.map.rect)
	var area: PackedVector2Array = z.walk_area if z.walk_area.size() >= 3 else (_stage.walk_area if _stage else PackedVector2Array())
	var p := _player()
	if p:
		p.walk_area = area
	if main.spawner:
		main.spawner.walk_area = area
		main.spawner.boss_point = z.boss_at if z.has_boss_at else Vector2.INF  # 우두머리 자리 (한산 대장선 누각 계단 위)
	if clear_shots:
		for n in main.find_children("*", "Area2D", true, false):  # 날아가던 탄 (영웅·적 모두)
			if n is Projectile:
				n.queue_free()
		if arena and arena.hazards and _stage:  # 무대 장치 새로 (예고 중이던 포격선이 새 구역에서 터지지 않게)
			arena.hazards.setup(_stage.hazards)


## 배경 지도 바로 위 색 덮개 (지도 셰이더가 modulate를 쓰지 않아 따로 그린다): 소품·빛·적 아래.
func _wash_layer(arena: Arena) -> ZoneWash:
	var w := arena.get_node_or_null("ZoneWash") as ZoneWash
	if w == null:
		w = ZoneWash.new()
		w.name = "ZoneWash"
		arena.add_child(w)
		arena.move_child(w, arena.edge.get_index() + 1 if arena.edge else arena.map.get_index() + 1)
	return w


func _freeze_input(on: bool) -> void:
	if not on:
		for n: Node in _frozen:
			if is_instance_valid(n):
				n.process_mode = _frozen[n]
		_frozen.clear()
		return
	var list: Array = [main.get_node_or_null("TouchController"), main.get_node_or_null("Player/SkillCaster")]
	if main.hud:
		list.append_array(main.hud.find_children("*", "Control", true, false).filter(func(n: Node) -> bool: return n is HomeSummonButton))
	for n in list:
		if n:
			_frozen[n] = n.process_mode
			n.process_mode = Node.PROCESS_MODE_DISABLED


func _player() -> Player:
	return main.get("player") as Player if main else null
