class_name BossSim
extends RefCounted
## 한산 보스전 헤드리스 시뮬레이션 (tests/test_boss_sim.gd 가 쓴다, test_measured_sim 방식: 물리 프레임 안 고정 틱, 씨앗 고정).
## 순신 한 명과 보스(+ 단계 부하)를 실제 노드로 굴린다. 영웅 조작은 세 가지:
##   IDLE   : 제자리, 손을 안 댄다 (자동 공격만)
##   TAP    : 보스에게 붙어 탭 연타만 (피하지 않음)
##   DODGE  : 예고를 보고 대시로 빠지고, 보스가 치지 않는 틈에 붙어 탭 연타
## 결과 사전: time, won, lost, damage, by (공격 종류별 받은 피해), boss_hp, phase, windups (보스 예고 시작 [시각, 종류]),
## strikes (실제로 친 공격 종류 차례), gaps (보스 타격 → 다음 예고 간격), max_minions (동시 부하 최대).

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
## false면 접촉 피해를 세지 않는다 (예고 공격만의 박자를 볼 때).
var contact := true
## DODGE가 놓치는 예고 비율 (0 = 다 피함, 0.3 = 셋에 하나는 못 봄: 서툰 사람). 예고마다 한 번 정한다.
var miss_rate := 0.0
var _missed := {}


func _init(p_suite: Node) -> void:
	suite = p_suite


func setup(boss_data: EnemyData, boss_at: Vector2 = Vector2(0, -300)) -> void:
	EnemyAttack.active_windups = 0
	var yi := ResourceLoader.load(YI_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as HeroData
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
	caster.enemy_source = func() -> Array: return enemies()
	suite.add_child(caster)
	caster.set_physics_process(false)
	spawner = EnemySpawner.new()
	spawner.enemy_scene = ENEMY_SCENE
	spawner.target = player
	spawner.horde_enabled = false
	suite.add_child(spawner)
	spawner.set_physics_process(false)
	spawner.boss_data = boss_data
	boss = spawner.spawn_boss()  # 박자·연출(BossStaging)도 붙는다
	boss.global_position = boss_at


func free_all() -> void:
	for n in [spawner, caster, player]:
		if is_instance_valid(n):
			n.free()
	EnemyAttack.active_windups = 0


func enemies() -> Array:
	var out: Array = []
	for c in spawner.get_children():
		if c is Enemy and is_instance_valid(c) and not (c as Enemy).health.is_dead():
			out.append(c)
	return out


## limit초 동안 (또는 승패까지) 굴린다.
func run(bot: Bot, limit: float = 150.0) -> Dictionary:
	var res := {"time": 0.0, "won": false, "lost": false, "damage": 0, "by": {}, "boss_hp": 0, "phase": 0,
		"windups": [], "strikes": [], "gaps": [], "max_minions": 0, "max_threats": 0}
	var t := 0.0
	var tap_t := 0.0
	var boss_state := EnemyAttack.State.READY
	var last_strike := -1.0
	while t < limit and not player.is_dead() and is_instance_valid(boss) and not boss.health.is_dead():
		t += DT
		for c in spawner.get_children():  # 새로 나온 부하·예고·화살도 손으로 굴린다
			c.set_physics_process(false)
		var list := enemies()
		if bot != Bot.IDLE:
			_steer(bot, list)
		player._physics_process(DT)
		caster.tick(DT, t)
		tap_t -= DT
		if bot != Bot.IDLE and tap_t <= 0.0 and player.global_position.distance_to(boss.global_position) <= 170.0:
			tap_t = TAP_GAP
			caster.combo_tap()
		atk.tick(DT, list)
		_tick_world(list, res)
		if not is_instance_valid(boss) or boss.health.is_dead():
			break
		var st := boss.attack.state
		if st == EnemyAttack.State.WINDUP and boss_state != EnemyAttack.State.WINDUP:
			res["windups"].append([snappedf(t, 0.01), boss.attack.data.kind])
			if last_strike >= 0.0:
				res["gaps"].append(snappedf(t - last_strike, 0.01))
		if st == EnemyAttack.State.RECOVER and boss_state == EnemyAttack.State.WINDUP:
			last_strike = t
			res["strikes"].append(boss.attack.data.kind)
		boss_state = st
		var minions := list.size() - 1
		res["max_minions"] = maxi(res["max_minions"], minions)
		res["max_threats"] = maxi(res["max_threats"], EnemyAttack.active_windups)
	res["time"] = snappedf(t, 0.1)
	res["lost"] = player.is_dead()
	res["won"] = not is_instance_valid(boss) or boss.health.is_dead()
	res["damage"] = player.health.max - player.health.current
	res["boss_hp"] = boss.health.current if is_instance_valid(boss) else 0
	res["phase"] = boss.phase_index if is_instance_valid(boss) else -1
	return res


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
	if bot == Bot.DODGE and not player.is_dashing():
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
					return
			elif a.contains(p):
				player.request_dash(escape_dir(a, p))
				return
	var to_boss := boss.global_position - p
	var want := 90.0
	var busy := boss.attack.state == EnemyAttack.State.WINDUP and not bool(_missed.get(boss.attack, false))  # 못 본 예고는 없는 셈
	if bot == Bot.DODGE and busy and boss.attack.contains(p):
		player.set_move_input(-to_boss.normalized())  # 예고 안: 일단 물러난다 (대시는 위에서)
	elif bot == Bot.DODGE and busy:
		player.set_move_input(Vector2.ZERO)  # 보스가 치는 중엔 붙지 않는다
	elif to_boss.length() > want:
		player.set_move_input(to_boss.normalized())
	else:
		player.set_move_input(Vector2.ZERO)
		player.facing = to_boss.normalized()


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
