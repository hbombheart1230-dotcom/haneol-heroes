class_name BossStaging
extends Node
## 보스전 박자·연출 진행 (EnemyData.boss_feel이 있는 보스만, 수치는 BossFeelData).
## 보스가 나오면 EnemySpawner 아래에 붙는다 (보스가 죽어도 처치 연출을 끝까지 하려고 보스 밖에 둔다).
##   등장: intro_hold 동안 치지 않음, 보스 공격은 화면 안에서만 시작, 다음 공격은 거리·직전 종류로 고른다.
##   단계 전환(BossPhases.enter가 부름): 보스·영웅 모두 transition_hold 동안 치지도 맞지도 않음 →
##     pick_delay 뒤 강화 고르기 → summon_delay 뒤 부하 (보스 뒤, 최대 max_minions).
##   처치(Main이 BossStaging.finish로 부름): 남은 부하 흩어짐, 영웅 무적, 느린 시간·확대·한지 번짐, finale_time 뒤 승리.
##   중간 보스(boss_feel이 있는 정예, is_boss 아님): 죽으면 스스로 짧은 처치 연출 — 남은 부하·나타나는 중인 자리를 지워
##     물결이 끝나게 하고, 생성기는 멈추지 않는다 (승리 아님).

const META := &"boss_staging"

var feel: BossFeelData
var boss: Enemy
var spawner: EnemySpawner
## 예약된 일 [남은 시간(초, 게임 시간), Callable]. 단계 전환 때만 생긴다.
var _events: Array = []


## 보스에 붙인다 (boss_feel이 없으면 아무것도 하지 않음).
static func attach(sp: EnemySpawner, e: Enemy) -> BossStaging:
	if e == null or e.data == null or e.data.boss_feel == null:
		return null
	var s := BossStaging.new()
	s.name = "BossStaging"
	s.feel = e.data.boss_feel
	s.boss = e
	s.spawner = sp
	sp.add_child(s)
	e.set_meta(META, s)
	s._setup_attack()
	if not e.data.is_boss:
		e.killed.connect(func(_e: Enemy) -> void: s.play_finale(Callable(), false), CONNECT_ONE_SHOT)
	return s


static func of(e: Enemy) -> BossStaging:
	return e.get_meta(META, null) as BossStaging if e and is_instance_valid(e) else null


## 보스 처치 뒤 승리 (done). 연출이 있는 보스면 finale_time 뒤, 없으면 바로.
static func finish(e: Enemy, done: Callable) -> void:
	var s := of(e)
	if s and is_instance_valid(s) and s.is_inside_tree():
		s.play_finale(done)
	else:
		done.call()


func _setup_attack() -> void:
	var a := boss.attack
	if a == null:
		return
	a.pick_by_range = feel.pick_by_range
	if feel.onscreen_margin >= 0.0:
		a.start_check = on_screen
	if a.pick_by_range and not a.patterns.is_empty():
		a.set_patterns(a.patterns)
	a.hold(feel.intro_hold)


## 보스가 화면 안(가장자리에서 onscreen_margin 안쪽)인지. 카메라가 없으면(테스트) 늘 true.
func on_screen(pos: Vector2) -> bool:
	var half := spawner.view_half() if spawner and spawner.is_inside_tree() else Vector2.INF
	var p := spawner.target if spawner else null
	if half == Vector2.INF or p == null:
		return true
	var off := (pos - p.global_position).abs()
	return off.x <= half.x - feel.onscreen_margin and off.y <= half.y - feel.onscreen_margin


## 단계 전환: 치지도 맞지도 않는 한 박자 → 강화 → 부하.
func on_phase(ph: BossPhaseData) -> void:
	if boss.attack:
		boss.attack.hold(feel.transition_hold)
	if feel.phase_anim != &"":
		EnemySprite.show_pose(boss, feel.phase_anim, feel.transition_hold)  # 군령 외침
	boss.phase_invuln = maxf(boss.phase_invuln, ph.invuln_time)
	var p := spawner.target as Player
	if p:
		p.grant_invulnerability(feel.transition_hold)
	if feel.phase_pick:
		_events.append([feel.pick_delay, func() -> void: spawner.breather.emit(false)])
	_events.append([feel.summon_delay, summon.bind(ph.summon)])


## 부하 부르기: 보스 뒤(영웅 반대편) 부채꼴에, 이미 있는 부하·예고와 합쳐 max_minions까지.
func summon(list: Array) -> void:
	if not is_instance_valid(boss) or boss.health.is_dead():
		return
	var room := feel.max_minions - minion_count()
	var n := mini(list.size(), maxi(room, 0))
	var p := spawner.target
	var back := (boss.global_position - p.global_position).normalized() if p else Vector2.UP
	if back == Vector2.ZERO:
		back = Vector2.UP
	var spread := deg_to_rad(feel.summon_spread_deg)
	for i in n:
		var a := 0.0 if n == 1 else lerpf(-spread * 0.5, spread * 0.5, float(i) / (n - 1))
		var at := boss.global_position + back.rotated(a) * feel.summon_distance
		var r := feel.summon_distance
		spawner.warn_spawn(list[i], spawner.safe_point(at, boss.global_position, r * 0.7, r + 80.0))


## 살아 있는 부하 + 나타나는 중인 자리.
func minion_count() -> int:
	return maxi(spawner.alive_count() - (1 if is_instance_valid(boss) and not boss.health.is_dead() else 0), 0) \
		+ spawner._warnings


func _physics_process(delta: float) -> void:
	var i := 0
	while i < _events.size():
		_events[i][0] -= delta
		if _events[i][0] <= 0.0:
			var f: Callable = _events[i][1]
			_events.remove_at(i)
			f.call()
		else:
			i += 1


## 처치 연출 (실제 시간): 남은 부하·화살 정리, 영웅 무적, 느린 시간·확대·한지 번짐, finale_time 뒤 done.
## final = false(중간 보스)면 생성기를 멈추지 않고, 나타나는 중인 자리만 지운다.
func play_finale(done: Callable, final: bool = true) -> void:
	_events.clear()
	var p := spawner.target as Player
	if p:
		p.grant_invulnerability(feel.finale_time + (1.0 if final else 0.0))
	if final:
		spawner.active = false  # 나타나는 중인 부하는 나오지 않는다
	for c in spawner.get_children():
		if c is SpawnWarning and not final:
			spawner._warnings = maxi(spawner._warnings - 1, 0)
			c.queue_free()
		elif c is Enemy and c != boss and not (c as Enemy).health.is_dead():
			(c as Enemy).health.kill()
		elif c is EnemyArrow:
			c.queue_free()
	var tree := get_tree()
	GameTime.stop(tree, feel.finale_slow_time + feel.finale_slow_back, feel.finale_slow_scale, feel.finale_slow_back)
	BossFinaleFx.play(Feedback.instance, feel)
	tree.create_timer(feel.finale_time, false, false, true).timeout.connect(func() -> void:
		if done.is_valid():
			done.call()
		queue_free())
