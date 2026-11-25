class_name BossSim
extends RefCounted
## 보스전 헤드리스 시뮬레이션 (영웅·보스는 아무나, 기본은 한산 순신) (tests/test_boss_sim.gd 가 쓴다, test_measured_sim 방식).
## 결정적으로 (같은 씨앗 = 프로세스·실행 순서와 상관없이 같은 [boss-sim] 줄):
##  - 한 물리 프레임 안에서 고정 틱(DT)으로 끝까지 돈다 (move_and_slide가 물리 프레임 밖에서는 실제 프레임 delta를 씀).
##  - 시계는 시뮬 시간 (EnemyAttack.clock · DashStyleRunner.clock), 기술 멈춤 끔, Engine.time_scale 1 고정.
##  - 적 버릇 씨앗(ai_seed)은 나온 차례, 생성기 난수·전역 난수는 씨앗으로. 전역 상태는 판 앞뒤로 비운다.
##  - 영웅·보스 데이터는 디스크에서 새로 읽는다 (다른 시험이 바꿔 둔 공유 리소스 영향 제거).
## 영웅 한 명과 보스(+ 단계 부하)를 실제 노드로 굴린다. 영웅 탄(Projectile)은 물리 없이 손으로 맞춘다. 영웅 조작은 세 가지:
##   IDLE   : 제자리, 손을 안 댄다 (자동 공격만)
##   TAP    : 보스에게 붙어 탭 연타만 (피하지 않음)
##   DODGE  : 예고 동안 제자리에서 치다가 끝 무렵(REACT) 대시로 빠지고, 틈에 다시 붙어 탭 연타
## 결과 사전: time, won, lost, damage, by (공격 종류별 받은 피해), boss_hp, phase, windups (보스 예고 시작 [시각, 종류]),
## strikes (실제로 친 공격 종류 차례), struck (그 공격 데이터, 이어치기 확인용), gaps (보스 타격 → 다음 예고 간격), max_minions (동시 부하 최대).

enum Bot { IDLE, TAP, DODGE }

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
## 다른 시험이 같은 리소스를 바꿔 놓아도 영향받지 않게 매번 디스크에서 새로 읽는다.
const YI_PATH := "res://data/heroes/yi_sun_sin.tres"
const DT := 1.0 / 60.0
const TAP_GAP := 0.2
## 사람 반응: 예고가 이만큼 남았을 때 대시 (예고 0.8~1.0초 중 앞 0.5초는 보고 판단하는 시간).
const REACT := 0.32
## 영웅 접촉 감지 반경 (main.tscn ContactSensor).
const SENSOR := 30.0

var suite: Node
var player: Player
var atk: AutoAttack
var caster: SkillCaster
var spawner: EnemySpawner
var boss: Enemy
## 함께 싸우는 다른 우두머리 (중간 우두머리 무리). boss가 쓰러지면 다음 살아 있는 하나가 boss가 되고, 모두 쓰러지면 이김.
var group: Array = []
## 시뮬 시간(초)과 나온 적 수 (ai_seed).
var _t: float = 0.0
var _spawned: int = 0
## false면 접촉 피해를 세지 않는다 (예고 공격만의 박자를 볼 때).
var contact := true
## DODGE가 놓치는 예고 비율 (0 = 다 피함, 0.3 = 셋에 하나는 못 봄: 서툰 사람). 예고마다 한 번 정한다.
var miss_rate := 0.0
var _missed := {}
## 영웅 데이터 경로, 붙는 거리(px), 탭을 시작하는 보스 거리(px). 원거리 영웅은 멀리 선다 (use_hero).
var hero_path := YI_PATH
## 있으면 hero_path 대신 이 영웅 데이터 (판 안에서 성장한 영웅 사본, tests/grown_heroes.gd).
var hero_override: HeroData
var want := 90.0
var tap_range := 170.0
## true면 모으기 기술을 쿨타임마다 다 모아 우두머리 쪽으로 쓴다 (보고용, 기본은 탭만: 기존 균형 시험은 그대로).
var use_charge := false
## 탄이 이미 맞힌 적 (관통 탄은 같은 적을 한 번만).
var _proj_hits := {}
## 판 전부터 있던 suite 자식 (판이 끝나면 그 밖의 것은 다 지운다: 탄·기술 노드가 지운 생성기를 부르지 않게).
var _kept := {}


func _init(p_suite: Node) -> void:
	suite = p_suite


## 전역 상태 비우기 (판 앞뒤, after_test).
static func reset_globals() -> void:
	EnemyAttack.active_windups = 0
	EnemyAttack.clock = Callable()
	GameTime.clock = Callable()
	DashStyleRunner.clock = Callable()
	AttackTokens.clear()
	SkillHitStop.reset()
	GameTime.reset()
	Engine.time_scale = 1.0
	GrowthApply.reset()  # 판 밖 성장 0 기준


## 물리 프레임 하나를 기다린 뒤 (await 필요) 그 프레임 안에서 판을 꾸린다. 이어서 run을 await 없이 부른다.
func setup(boss_data: EnemyData, s: int, boss_at: Vector2 = Vector2(0, -300)) -> void:
	reset_globals()
	await suite.get_tree().physics_frame
	seed(s)
	_t = 0.0
	_spawned = 0
	EnemyAttack.clock = func() -> float: return _t
	GameTime.clock = func() -> int: return int(_t * 1000.0)  # 멈춤도 판 시각으로 (실제 시각이면 같은 씨앗이 다른 판)
	DashStyleRunner.clock = func() -> float: return _t
	_proj_hits.clear()
	_kept.clear()
	for c in suite.get_children():
		_kept[c] = true
	var yi := hero_override if hero_override else ResourceLoader.load(hero_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as HeroData
	player = Player.new()
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	player.hero = yi
	suite.add_child(player)
	player.global_position = Vector2.ZERO
	player.set_physics_process(false)
	atk = AutoAttack.new()
	atk.name = "AutoAttack"
	atk.player = player
	atk.data = yi.attack
	atk.projectile_scene = PROJECTILE_SCENE
	atk.projectile_parent = suite
	player.add_child(atk)
	atk.set_physics_process(false)
	caster = SkillCaster.new()
	caster.player = player
	caster.kit = yi.kit
	caster.projectile_scene = PROJECTILE_SCENE
	caster.world = suite
	caster.hit_stop_enabled = false  # 실제 시간으로 풀리는 멈춤은 끈다
	caster.enemy_source = func() -> Array: return enemies()
	suite.add_child(caster)
	caster.set_physics_process(false)
	spawner = EnemySpawner.new()
	spawner.enemy_scene = ENEMY_SCENE
	spawner.target = player
	spawner.horde_enabled = false
	spawner.rng.seed = s
	spawner.child_entered_tree.connect(_on_spawned)  # _ready 전에 버릇 씨앗
	suite.add_child(spawner)
	spawner.set_physics_process(false)
	spawner.boss_data = boss_data
	if boss_data == null:  # 물결 무대 (StageSim): 보스는 마지막 물결 뒤
		return
	boss = spawner.spawn_boss()  # 박자·연출(BossStaging)도 붙는다
	boss.global_position = boss_at


func _on_spawned(n: Node) -> void:
	if n is Enemy:
		_spawned += 1
		(n as Enemy).ai_seed = _spawned


## 영웅 바꾸기 (setup 전에): 경로, 붙는 거리, 탭 거리.
func use_hero(path: String, p_want: float, p_tap: float) -> void:
	hero_path = path
	want = p_want
	tap_range = p_tap


func free_all() -> void:
	for c in suite.get_children():
		if not _kept.has(c) and c != spawner and c != caster and c != player:
			c.free()
	for n in [spawner, caster, player]:
		if is_instance_valid(n):
			n.free()
	reset_globals()


func enemies() -> Array:
	var out: Array = []
	if not is_instance_valid(spawner):  # 판이 끝난 뒤 남은 기술 타이머가 부를 때
		return out
	for c in spawner.get_children():
		if c is Enemy and is_instance_valid(c) and not (c as Enemy).health.is_dead():
			out.append(c)
	return out


## limit초 동안 (또는 승패까지) 굴린다.
func run(bot: Bot, limit: float = 150.0) -> Dictionary:
	var res := {"time": 0.0, "won": false, "lost": false, "damage": 0, "by": {}, "boss_hp": 0, "phase": 0,
		"windups": [], "strikes": [], "struck": [], "hits": {}, "boss_stun": 0.0, "boss_windup": 0.0,
		"boss_recover": 0.0, "boss_idle": 0.0, "dist": 0.0, "gaps": [], "max_minions": 0, "max_threats": 0}
	var tap_t := 0.0
	var boss_state := EnemyAttack.State.READY
	var last_strike := -1.0
	var t0 := _t
	while _t - t0 < limit and not player.is_dead() and is_instance_valid(boss) and not boss.health.is_dead():
		_t += DT
		var t := _t - t0
		Engine.time_scale = 1.0
		for c in spawner.get_children():  # 새로 나온 부하·예고·화살도 손으로 굴린다
			c.set_physics_process(false)
		var list := enemies()
		if bot != Bot.IDLE and not _extra_dodge():  # 무대 장치(포격 줄)부터 비킨다 (StageSim)
			_steer(bot, list)
		player._physics_process(DT)
		caster.tick(DT, _t)
		tap_t -= DT
		if bot != Bot.IDLE and tap_t <= 0.0 and player.global_position.distance_to(boss.global_position) <= tap_range:
			tap_t = TAP_GAP
			caster.combo_tap()
		if use_charge and bot != Bot.IDLE and caster.is_ready(SkillCaster.Slot.CHARGE) 				and player.global_position.distance_to(boss.global_position) <= tap_range:
			player.facing = (boss.global_position - player.global_position).normalized()
			caster.cast(SkillCaster.Slot.CHARGE, 1.0)
		atk.tick(DT, list)
		_tick_shots(list)
		_tick_rakes()  # 기술 박자 타격 (WaveRake: 낙뢰·화폭·해일검기·쿵-쿵-쾅·꽃잎)
		_tick_world(list, res)
		_sample(list)
		_tick_extra(res)
		if not is_instance_valid(boss) or boss.health.is_dead():
			var nxt := _next_alive()
			if nxt == null:
				break
			boss = nxt
			boss_state = EnemyAttack.State.READY
		var st := boss.attack.state if boss.attack else EnemyAttack.State.READY
		if st == EnemyAttack.State.WINDUP and boss_state != EnemyAttack.State.WINDUP:
			res["windups"].append([snappedf(t, 0.01), boss.attack.data.kind])
			if last_strike >= 0.0:
				res["gaps"].append(snappedf(t - last_strike, 0.01))
		if st == EnemyAttack.State.RECOVER and boss_state == EnemyAttack.State.WINDUP:
			last_strike = t
			res["strikes"].append(boss.attack.data.kind)
			res["struck"].append(boss.attack.data)
		boss_state = st
		# 패턴 보고 (tests/test_boss_pattern_report.gd): 보스가 휘청·멈춤/예고/회복/쉼에 쓴 시간, 영웅과 거리
		if boss.is_stunned():
			res["boss_stun"] += DT
		elif st == EnemyAttack.State.WINDUP:
			res["boss_windup"] += DT
		elif st == EnemyAttack.State.RECOVER:
			res["boss_recover"] += DT
		else:
			res["boss_idle"] += DT
		res["dist"] += player.global_position.distance_to(boss.global_position) * DT
		var minions := list.filter(func(e: Enemy) -> bool: return not (e.data.aura and e.data.move_speed <= 0.0)).size() - 1  # 깃발은 부하가 아니다
		res["max_minions"] = maxi(res["max_minions"], minions)
		res["minion_sum"] = float(res.get("minion_sum", 0.0)) + maxi(minions, 0) * DT  # 평균 부하 수 (주기 소환 비교)
		res["max_threats"] = maxi(res["max_threats"], EnemyAttack.active_windups)
	res["time"] = snappedf(_t - t0, 0.1)
	res["lost"] = player.is_dead()
	res["won"] = (not is_instance_valid(boss) or boss.health.is_dead()) and _next_alive() == null
	res["damage"] = player.health.max - player.health.current
	res["boss_hp"] = boss.health.current if is_instance_valid(boss) else 0
	res["phase"] = boss.phase_index if is_instance_valid(boss) else -1
	return res


## 기술 박자 타격 한 틱 (WaveRake): 손으로 굴리는 동안 물리 틱이 돌지 않아, 예전엔 첫 타 뒤 타들이 시뮬에서 빠졌다.
func _tick_rakes() -> void:
	for c in suite.get_children():
		if c is WaveRake and not c.is_queued_for_deletion():
			c.set_physics_process(false)
			(c as WaveRake)._physics_process(DT)


## 영웅 탄 한 틱: 움직이고, 적 피격 원(22px)에 닿으면 HitBox2D가 하듯 피해를 준다 (손으로 굴리면 영역 겹침이 갱신되지 않음).
const HURT_R := 22.0


func _tick_shots(list: Array) -> void:
	for c in suite.get_children():
		if not (c is Projectile) or c.is_queued_for_deletion():
			continue
		var pr := c as Projectile
		pr._physics_process(DT)
		if pr.is_queued_for_deletion() or pr.ignore_collisions:
			continue
		var seen: Dictionary = _proj_hits.get_or_add(pr.get_instance_id(), {})
		for e in list:
			if is_instance_valid(e) and not seen.has(e) and not e.health.is_dead() \
					and pr.hit_reach(e.global_position) <= HURT_R:  # 판정 원·캡슐 (Projectile.hit_reach)
				seen[e] = true
				pr._on_area_entered(e.get_node("HurtBox2D"))
				if pr.ignore_collisions:
					break


## 우두머리전에도 무대 장치를 굴리고(포격) 그 줄을 비킨다 (StageSim이 덮어쓴다). 기본은 없음.
func _tick_extra(_res: Dictionary) -> void:
	pass


func _extra_dodge() -> bool:
	return false


## 매 틱 재기 (RunSim이 덮어써 잡몹 경직·공격 시작을 센다). 기본은 아무것도 안 한다.
func _sample(_list: Array) -> void:
	pass


## 적·예고·화살 한 틱. 받은 피해를 공격 종류별로 센다.
func _tick_world(list: Array, res: Dictionary) -> void:
	for c in spawner.get_children():
		if c.is_queued_for_deletion():  # 손으로 굴리는 동안은 프레임이 끝나지 않아 지운 노드가 남아 있다
			continue
		var before := player.health.current
		var key := ""
		if c is Enemy and is_instance_valid(c) and not (c as Enemy).health.is_dead():
			var e := c as Enemy
			var kind: int = e.attack.data.kind if e.attack else -1
			e._physics_process(DT)
			key = ("boss_" if e == boss else "minion_") + str(kind)
		elif c is SpawnWarning or c is BossStaging:
			c._physics_process(DT)
		elif c is EnemyArrow:
			if (c as EnemyArrow).step(DT):
				c.free()
			key = "arrow"
		if player.health.current < before:
			res["by"][key] = int(res["by"].get(key, 0)) + before - player.health.current
			if res.has("hits"):  # 패턴 보고용 (물결 시뮬 결과에는 없다)
				res["hits"][key] = int(res["hits"].get(key, 0)) + 1
	# 접촉 피해 (시뮬레이션 영웅에는 감지 영역이 없어 손으로 잰다)
	var touch := 0
	for e in (list if contact else []):
		if is_instance_valid(e) and not e.health.is_dead() \
				and e.global_position.distance_to(player.global_position) <= SENSOR + e.body_radius * e.size_mult:
			touch = maxi(touch, e.contact_damage)
	var hp := player.health.current
	player.apply_contact_damage(0.0, touch)
	if player.health.current < hp:
		res["by"]["contact"] = int(res["by"].get("contact", 0)) + hp - player.health.current


## 영웅 조작: 위험한 예고가 곧 끝나면 대시로 빠지고, 아니면 보스에게 붙는다 (DODGE는 보스가 칠 때 붙지 않는다).
func _steer(bot: Bot, list: Array) -> void:
	var p := player.global_position
	if bot == Bot.DODGE and _dodge(list):
		return
	var to_boss := boss.global_position - p
	var busy := boss.attack != null and boss.attack.state == EnemyAttack.State.WINDUP and not bool(_missed.get(boss.attack, false))  # 못 본 예고는 없는 셈
	if bot == Bot.DODGE and busy:
		player.set_move_input(Vector2.ZERO)  # 예고 중엔 그 자리에서 계속 치다가 끝 무렵 대시 (위)
	elif to_boss.length() > want:
		player.set_move_input(to_boss.normalized())
	else:
		player.set_move_input(Vector2.ZERO)
		player.facing = to_boss.normalized()


## 곧 끝나는 위험한 예고가 있으면 그 밖으로 대시하고 true (DODGE·StageSim이 같이 쓴다).
func _dodge(list: Array) -> bool:
	if player.is_dashing():
		return false
	var p := player.global_position
	for e in list:
		var a: EnemyAttack = e.attack
		if a == null or a.state != EnemyAttack.State.WINDUP:
			_missed.erase(a)
			continue
		if not _missed.has(a):
			_missed[a] = randf() < miss_rate
		if _missed[a] or a.windup_left() > REACT:
			continue
		if a.is_shoot():
			var off := p - a.aim_origin
			if absf(off.dot(a.aim_dir.orthogonal())) < 50.0 and off.dot(a.aim_dir) > 0.0:
				player.request_dash(_side(a.aim_dir, off))
				return true
		elif a.contains(p):
			player.request_dash(escape_dir(a, p))
			return true
	return false


## 예고 영역 밖으로 나가는 대시 방향.
static func escape_dir(a: EnemyAttack, p: Vector2) -> Vector2:
	match a.data.kind:
		EnemyAttackData.Kind.CHARGE, EnemyAttackData.Kind.THRUST, EnemyAttackData.Kind.PULL:
			return _side(a.aim_dir, p - a.aim_origin)
		EnemyAttackData.Kind.SLAM:
			var o := p - a.target_point
			return o.normalized() if o.length_squared() > 1.0 else Vector2.RIGHT
	var off := p - a.aim_origin
	return off.normalized() if off.length_squared() > 1.0 else a.aim_dir.orthogonal()


static func _side(dir: Vector2, off: Vector2) -> Vector2:
	var n := dir.orthogonal()
	return n if off.dot(n) >= 0.0 else -n


## 결과 한 줄 (로그용).
static func line(name: String, r: Dictionary) -> String:
	return "[boss-sim] %s: %s in %.1fs, damage %d, boss hp %d, phase %d, minions max %d, by %s, gaps %s" % [
		name, "WIN" if r["won"] else ("LOSE" if r["lost"] else "TIMEOUT"), r["time"], r["damage"], r["boss_hp"],
		r["phase"], r["max_minions"], str(r["by"]), str(r["gaps"].slice(0, 12))]


## 무리 가운데 아직 살아 있는 다음 우두머리 (없으면 null).
func _next_alive() -> Enemy:
	for e in group:
		if is_instance_valid(e) and not (e as Enemy).health.is_dead():
			return e
	return null
