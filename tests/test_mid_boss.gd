extends GdUnitTestSuite
## 중간 보스 (boss_feel이 있는 정예, 한산 왜군 정예부터): 2물결에서 잡몹이 줄어든 뒤 등장 → 이름·체력 띠 →
## 살아 있는 동안 일반 보충 없음, 잡몹은 소환으로만 (강화 고르기 없음) → 죽으면 짧은 처치 연출, 남은 부하를 지워 물결 끝.
## 최종 보스 구조(BossStaging·BossPhases)를 데이터로 다시 쓴다: is_boss가 아니면 중간 보스.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const ELITE_PATH := "res://data/enemies/waegun_elite.tres"
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const COMMANDER := preload("res://data/enemies/waegun_commander.tres")
const DT := 1.0 / 60.0

var player: Player
var sp: EnemySpawner


func before_test() -> void:
	BossSim.reset_globals()
	player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	add_child(player)
	player.set_physics_process(false)
	sp = auto_free(EnemySpawner.new())
	sp.enemy_scene = ENEMY_SCENE
	sp.target = player
	sp.horde_enabled = false
	add_child(sp)
	sp.set_physics_process(false)
	sp.elite_data = _elite()


func after_test() -> void:
	BossSim.reset_globals()


func _elite() -> EnemyData:
	return ResourceLoader.load(ELITE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EnemyData


func _step(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		t += DT
		for c in sp.get_children():
			if c.is_queued_for_deletion():
				continue
			if c is Enemy and not (c as Enemy).health.is_dead():
				(c as Enemy)._physics_process(DT)
			elif c is SpawnWarning or c is BossStaging:
				c._physics_process(DT)


func _wave_set(when_left: int) -> WaveSetData:
	var w := WaveData.new()
	var list: Array[EnemyData] = [SOLDIER, SOLDIER, SOLDIER, SOLDIER]
	w.enemies = list
	w.first_count = 4
	w.elite_last = true
	w.elite_when_left = when_left
	var s := WaveSetData.new()
	var waves: Array[WaveData] = [w]
	s.waves = waves
	s.refill_each = true
	s.max_alive = 8
	s.spawn_stagger = 0.0
	return s


func test_mid_boss_data_rules() -> void:
	var d := _elite()
	assert_bool(d.is_elite).is_true()
	assert_bool(d.is_boss).is_false()  # 처치해도 승리 아님
	assert_object(d.boss_feel).is_not_null()
	assert_int(d.contact_damage).is_equal(0)  # 모든 피해는 예고로
	assert_float(d.launch_scale).is_less(1.0)  # 정예처럼 날아가지 않음
	assert_bool(d.boss_feel.phase_pick).is_false()
	assert_float(d.boss_feel.finale_time).is_less(COMMANDER.boss_feel.finale_time)  # 처치 연출은 보스보다 짧게
	assert_int(d.max_hp).is_less(COMMANDER.max_hp)
	var rage := 0
	for ph: BossPhaseData in d.phases:
		assert_int(ph.summon.size()).is_less_equal(d.boss_feel.max_minions)
		rage += 1 if not ph.patterns.is_empty() else 0
	assert_int(rage).is_less_equal(1)  # 강화는 한 번까지
	var all: Array = d.patterns.duplicate()
	for ph: BossPhaseData in d.phases:
		all.append_array(ph.patterns)
	var kinds := {}
	var i := 0
	while i < all.size():  # 이어치기까지
		var a: EnemyAttackData = all[i]
		i += 1
		kinds[a.kind] = true
		if a.follow_up and not all.has(a.follow_up):
			all.append(a.follow_up)
		assert_float(a.windup).is_greater_equal(0.8)
		assert_bool(d.sprite_sheet.has_anim(a.anim)).override_failure_message("no clip %s" % a.anim).is_true()
	assert_int(kinds.size()).is_between(2, 3)  # 예고 공격 2~3가지


func test_wave_holds_mid_boss_until_few_left_then_no_refill() -> void:
	var r := WaveRunner.new(_wave_set(2), 0.0)
	r.tick(DT, 0, false)
	var out: Array = []
	for i in 6:
		out.append_array(r.next_spawn(out.size(), 8))
	assert_int(out.size()).is_equal(4)  # 잡몹 넷만, 정예는 기다린다
	assert_bool(out.has(null)).is_false()
	assert_array(r.next_spawn(3, 8)).is_empty()  # 셋 남음 (> 2)
	var e := r.next_spawn(2, 8)
	assert_int(e.size()).is_equal(1)
	assert_object(e[0]).is_null()  # 둘 이하 → 중간 보스
	assert_array(r.next_spawn(0, 8)).is_empty()  # 그 뒤 일반 보충 없음
	assert_int(r.tick(DT, 1, false)).is_equal(WaveRunner.Event.NONE)  # 중간 보스가 살아 있으면 물결 계속
	assert_int(r.tick(DT, 0, false)).is_equal(WaveRunner.Event.CLEARED)


func test_old_elite_wave_still_spawns_elite_last_at_once() -> void:
	var r := WaveRunner.new(_wave_set(-1), 0.0)
	r.tick(DT, 0, false)
	var out: Array = []
	for i in 6:
		out.append_array(r.next_spawn(out.size(), 8))
	assert_int(out.size()).is_equal(5)
	assert_object(out.back()).is_null()


func test_spawn_as_mid_boss_gets_staging_bar_and_no_affix() -> void:
	var seen: Array = []
	sp.elite_spawned.connect(func(e: Enemy) -> void: seen.append(e))
	var m := sp.spawn_elite(Vector2(0, -150))
	assert_object(m).is_not_null()
	assert_object(m.affix).is_null()
	assert_object(BossStaging.of(m)).is_not_null()
	assert_bool(m.is_in_group(Enemy.BOSS_GROUP)).is_true()  # 화면 위 이름·체력 띠
	assert_int(seen.size()).is_equal(1)
	assert_float(m.attack.hold_left).is_greater(0.0)  # 등장 동안 치지 않음
	assert_bool(m.attack.pick_by_range).is_true()


func test_phase_summons_without_upgrade_pick() -> void:
	var picks := [0]
	sp.breather.connect(func(_s: bool) -> void: picks[0] += 1)
	var m := sp.spawn_elite(Vector2(0, -150))
	m.health.damage(roundi(m.health.max * 0.35))
	assert_int(m.phase_index).is_equal(1)
	_step(1.5)
	assert_int(picks[0]).is_equal(0)
	assert_int(sp.alive_count() + sp._warnings - 1).is_between(1, m.data.boss_feel.max_minions)


func test_mid_boss_death_clears_minions_but_keeps_spawner_and_no_victory() -> void:
	var m := sp.spawn_elite(Vector2(0, -150))
	sp.spawn_at(SOLDIER, Vector2(150, 0))
	sp.warn_spawn(SOLDIER, Vector2(-150, 0))
	assert_int(sp._warnings).is_equal(1)
	m.health.kill()
	assert_bool(sp.active).is_true()  # 최종 보스와 달리 생성기는 그대로
	assert_int(sp._warnings).is_equal(0)  # 나타나는 중인 부하도 지움
	await get_tree().process_frame
	assert_int(sp.alive_count()).is_equal(0)  # 물결이 끝날 수 있다


func test_hero_boss_hp_mult_applies_to_mid_boss() -> void:
	var gw: HeroData = load("res://data/heroes/gwanggaeto.tres")
	var d := _elite()
	assert_int(BossHpScale.for_hero(d, gw).max_hp).is_equal(roundi(d.max_hp * gw.boss_hp_mult))
	var plain := SOLDIER
	assert_object(BossHpScale.for_hero(plain, gw)).is_same(plain)


## 결정적 시뮬레이션: 순신이 피하며 치면 15~25초 안에 잡고 (등장 대기·소환 포함), 막힘 없이, 같은 공격 연속 없이.
func test_mid_boss_fight_length_with_yi() -> void:
	for s in [11, 23, 37]:
		var sim := BossSim.new(self)
		await sim.setup(_elite(), s)
		var r := sim.run(BossSim.Bot.DODGE, 60.0)
		print(BossSim.line("mid-boss yi seed %d" % s, r))
		sim.free_all()
		assert_bool(r["won"]).is_true()
		assert_int(r["phase"]).is_equal(2)
		assert_float(r["time"]).override_failure_message("%.1fs" % r["time"]).is_between(15.0, 25.0)
		for g in r["gaps"]:
			assert_float(g).is_less(6.0)
		var w: Array = r["struck"]
		for i in range(1, w.size()):
			var prev: EnemyAttackData = w[i - 1]
			if prev.follow_up != w[i]:
				assert_int(int((w[i] as EnemyAttackData).kind)).is_not_equal(int(prev.kind))
