class_name StageSim
extends BossSim
## 물결 무대 헤드리스 시뮬레이션 (tests/test_stage_sim.gd): 무대의 영웅 한 명이 StageTheme.waves를 처음부터 끝까지
## 깨고 보스가 나올 때까지. 결정성·영웅 굴리기는 BossSim 그대로 (같은 씨앗 = 같은 [stage-sim] 줄).
## 무대 지도의 장애물(map_blockers)은 등장 자리 검사(blocked_check)에 쓴다. 강화 고르기·난이도 단계는 없다 (더 어려운 쪽).
## 분열 변종 조각은 call_deferred라 한 프레임 안에서 도는 시뮬에는 나오지 않는다.
## 조작: 곧 끝나는 위험한 예고는 대시로 피하고(BossSim._dodge), 아니면 가장 가까운 적에게 붙어 탭 연타.
## 결과 사전: time (보스 등장 시각), boss (보스 나옴), lost, damage, by, cleared (물결 끝 시각들), spawned,
## max_alive (예고 자리 포함 동시 최대), stall (적·예고가 하나도 없는데 물결이 안 끝난 가장 긴 초), blocked (장애물 속 등장).

## 무대 → 영웅 (StageTheme.hero_hint), 붙는 거리, 탭 거리 (test_stage_boss_sim과 같은 값: 원거리 세종은 멀리 서서 쏜다).
const HEROES := {"순신": ["yi_sun_sin", 90.0, 170.0], "광개토": ["gwanggaeto", 110.0, 200.0],
	"세종": ["sejong", 280.0, 520.0], "사임당": ["shin_saimdang", 150.0, 240.0]}

var stage: StageTheme
var obstacles: Obstacles
## 무대 장치(StageTheme.hazards)를 켠다 (tests/test_hazard_sim.gd). 끄면 예전과 똑같다.
var use_hazards: bool = false
## 장치 예고 줄 안에 서 있으면 위아래로 비킨다 (끄면 줄을 무시하고 싸운다 = 가장 많이 맞는 쪽).
var dodge_hazards: bool = true
var hazards: StageHazards
## 판을 꾸리기 전부터 있던 시험 노드 (그 뒤에 world에 붙은 탄·기술 효과만 손으로 굴린다).
var _before: Array = []


static func hero_of(st: StageTheme) -> String:
	return "res://data/heroes/%s.tres" % HEROES.get(st.hero_hint, HEROES["순신"])[0]


## 물리 프레임 하나를 기다린 뒤 판을 꾸린다 (await 필요). 이어서 run_waves를 await 없이 부른다.
func setup_stage(st: StageTheme, s: int) -> void:
	stage = st
	var h: Array = HEROES.get(st.hero_hint, HEROES["순신"])
	use_hero(hero_of(st), h[1], h[2])
	_before = suite.get_children()
	await setup(null, s)
	obstacles = Obstacles.new()
	suite.add_child(obstacles)
	obstacles.build(st.map_blockers)
	spawner.blocked_check = obstacles.blocks
	spawner.arena_rect = Arena.new().rect if not st.background_rect.has_area() else st.background_rect.grow(-st.prop_inset)
	spawner.elite_data = st.elite
	spawner.boss_data = st.boss
	spawner.max_alive = st.waves.max_alive
	spawner.set_waves(st.waves)
	if use_hazards:
		hazards = StageHazards.new()
		suite.add_child(hazards)
		hazards.player = player
		hazards.spawner = spawner
		hazards.setup(st.hazards)


func free_all() -> void:
	for c in _effects():
		c.free()
	if is_instance_valid(obstacles):
		obstacles.free()
	if is_instance_valid(hazards):
		hazards.free()
	super.free_all()


func run_waves(limit: float = 300.0) -> Dictionary:
	var res := {"time": 0.0, "boss": false, "lost": false, "damage": 0, "by": {}, "cleared": [], "spawned": 0,
		"max_alive": 0, "stall": 0.0, "blocked": 0, "mid_at": -1.0, "mid_time": -1.0, "hz_strikes": 0, "hz_enemy_hits": 0,
		"hz_hero_hits": 0}
	var t0 := _t
	spawner.breather.connect(func(_slow: bool) -> void: res["cleared"].append(snappedf(_t - t0, 0.1)))
	spawner.child_entered_tree.connect(func(n: Node) -> void:
		if n is SpawnWarning and obstacles.blocks(spawner.global_position + (n as Node2D).position, 0.0):
			res["blocked"] += 1)
	spawner.elite_spawned.connect(func(e: Enemy) -> void:  # 중간 보스(정예) 등장 시각과 싸운 시간
		res["mid_at"] = snappedf(_t - t0, 0.1)
		e.killed.connect(func(_e: Enemy) -> void: res["mid_time"] = snappedf(_t - t0 - res["mid_at"], 0.1)))
	var tap_t := 0.0
	var stall := 0.0
	while _t - t0 < limit and not player.is_dead() and not spawner.boss_spawned_once:
		_t += DT
		Engine.time_scale = 1.0
		for c in spawner.get_children():
			c.set_physics_process(false)
		var list := enemies()
		var near := _nearest(list)
		if not _dodge(list) and not _dodge_hazard():
			_approach(near)
		player._physics_process(DT)
		caster.tick(DT, _t)
		tap_t -= DT
		if near and tap_t <= 0.0 and player.global_position.distance_to(near.global_position) <= tap_range:
			tap_t = TAP_GAP
			caster.combo_tap()
		atk.tick(DT, list)
		_tick_shots(list)  # 영웅 탄은 BossSim이 손으로 맞춘다
		_tick_world(list, res)
		_sample(list)
		for c in _effects():  # 기술 효과 (글자 고리, 붓 자국 …): 한 프레임 안이라 손으로
			c.set_physics_process(false)
			c._physics_process(DT)
		_tick_hazards(res)
		spawner.tick(DT)
		var alive := spawner.alive_count() + spawner._warnings
		res["max_alive"] = maxi(res["max_alive"], alive)
		stall = stall + DT if alive == 0 and spawner.waves.phase == WaveRunner.Phase.RUN else 0.0
		res["stall"] = maxf(res["stall"], stall)
	res["time"] = snappedf(_t - t0, 0.1)
	res["boss"] = spawner.boss_spawned_once
	res["lost"] = player.is_dead()
	res["damage"] = player.health.max - player.health.current
	res["spawned"] = _spawned
	return res


## 무대 장치를 한 틀 굴리고 포격 결과를 센다.
func _tick_hazards(res: Dictionary) -> void:
	if hazards == null:
		return
	for lane in hazards.get_children():
		lane.set_physics_process(false)
		var before: int = lane.get(&"strikes")
		lane._physics_process(DT)
		if lane.get(&"strikes") != before:
			res["hz_strikes"] += 1
			res["hz_enemy_hits"] += lane.get(&"last_enemy_hits")
			res["hz_hero_hits"] += 1 if lane.get(&"last_hero_hit") else 0


## 예고 중인 줄 안이면 가까운 쪽(위·아래)으로 비킨다.
func _dodge_hazard() -> bool:
	if hazards == null or not dodge_hazards:
		return false
	for lane in hazards.get_children():
		var ls := lane as LaneStrike
		if ls and ls.clock.warning() and ls.row >= 0:
			var r := ls.data.rows[ls.row]
			if LanePlan.in_lane(r, ls.data.half_width + 30.0, player.global_position, player.body_radius):
				player.set_move_input(LanePlan.push_dir(r.x, player.global_position))
				return true
	return false


## world(시험 노드)에 새로 붙은 기술 효과 (판 노드·영웅 탄 빼고, 지운 것 빼고).
func _effects() -> Array:
	var own := [player, spawner, caster, obstacles]
	return suite.get_children().filter(func(c: Node) -> bool:
		return not _before.has(c) and not own.has(c) and not (c is Projectile) and not c.is_queued_for_deletion() \
			and c.has_method("_physics_process"))


func _nearest(list: Array) -> Enemy:
	var best: Enemy = null
	for e: Enemy in list:
		if best == null or e.global_position.distance_squared_to(player.global_position) \
				< best.global_position.distance_squared_to(player.global_position):
			best = e
	return best


func _approach(e: Enemy) -> void:
	if e == null:
		player.set_move_input(Vector2.ZERO)
		return
	var to := e.global_position - player.global_position
	if to.length() > want:
		player.set_move_input(to.normalized())
	else:
		player.set_move_input(Vector2.ZERO)
		player.facing = to.normalized()


## 결과 한 줄 (로그용).
static func stage_line(name: String, r: Dictionary) -> String:
	return "[stage-sim] %s: %s at %.1fs, cleared %s, damage %d, spawned %d, alive max %d, stall %.1fs, blocked %d, elite at %.1fs for %.1fs, by %s" % [
		name, "BOSS" if r["boss"] else ("LOSE" if r["lost"] else "TIMEOUT"), r["time"], str(r["cleared"]), r["damage"],
		r["spawned"], r["max_alive"], r["stall"], r["blocked"], r["mid_at"], r["mid_time"], str(r["by"])]
