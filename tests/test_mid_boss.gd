extends GdUnitTestSuite
## 중간 보스 (boss_feel이 있는 정예, 한산 왜군 정예부터): 2물결에서 잡몹이 줄어든 뒤 등장 → 이름·체력 띠 →
## 살아 있는 동안 일반 보충 없음, 잡몹은 소환으로만 (강화 고르기 없음) → 죽으면 짧은 처치 연출, 남은 부하를 지워 물결 끝.
## 최종 보스 구조(BossStaging·BossPhases)를 데이터로 다시 쓴다: is_boss가 아니면 중간 보스.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const ELITE_PATH := "res://data/enemies/waegun_elite.tres"
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const COMMANDER := preload("res://data/enemies/waegun_commander.tres")
const DT := 1.0 / 60.0
## 네 무대 중간 보스 → 무대 주인 영웅, 붙는 거리, 탭 거리 (StageSim.HEROES와 같은 값).
const MIDS := {
	"res://data/enemies/waegun_elite.tres": ["yi_sun_sin", 90.0, 170.0],
	"res://data/enemies/elite_warrior.tres": ["gwanggaeto", 110.0, 200.0],
	"res://data/enemies/jurchen_elite.tres": ["sejong", 280.0, 520.0],
	"res://data/enemies/cc_mantis.tres": ["shin_saimdang", 150.0, 240.0],
}

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
	for path in MIDS:
		_check_data(ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EnemyData)


func _check_data(d: EnemyData) -> void:
	assert_int(d.xp).is_equal(20)  # 처치 점수 (레벨 곡선)
	assert_str(d.boss_feel.intro_subtitle).is_equal("정예 출현")
	assert_str(d.boss_feel.finale_subtitle).is_equal("정예 격파")
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


## 결정적 시뮬레이션: 무대 주인 영웅이 피하며 치면 (영웅 배율 받은 체력) 15~25초 안에 잡고 (등장 대기·소환 포함),
## 막힘 없이, 같은 공격 연속 없이. 보통 실행은 씨앗 하나, HH_SLOW=1이면 셋.
func test_mid_boss_fight_length() -> void:
	var seeds := [11, 23, 37] if OS.get_environment("HH_SLOW") == "1" else [11]
	for path in MIDS:
		var c: Array = MIDS[path]
		var hp := "res://data/heroes/%s.tres" % c[0]
		var total := 0.0
		for s in seeds:
			var grown: Array = await GrownHeroes.take(self, c[0], s, GrownHeroes.At.MID)  # 3물결까지 성장한 영웅
			var sim := BossSim.new(self)
			sim.use_hero(hp, c[1], c[2])
			sim.hero_override = grown[0]
			var hero: HeroData = grown[0]
			var d := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EnemyData
			await sim.setup(BossHpScale.for_hero(d, hero), s)
			var r := sim.run(BossSim.Bot.DODGE, 60.0)
			print(BossSim.line("mid-boss %s %s (level %d) seed %d" % [d.id, c[0], grown[1], s], r))
			sim.free_all()
			_check_fight(r, String(d.id))
			total += r["time"]
		var mean: float = total / seeds.size()
		print("[boss-sim] mid-boss %s mean %.1fs" % [path.get_file(), mean])
		if seeds.size() > 1:  # 목표 길이는 씨앗 셋 평균 (보통 실행은 한 판이라 한 판 범위 10~32초만, 위 _check_fight)
			assert_float(mean).override_failure_message("%s mean %.1fs" % [path, mean]).is_between(15.0, 25.0)


func _check_fight(r: Dictionary, label: String) -> void:
	assert_bool(r["won"]).override_failure_message(label).is_true()
	assert_int(r["phase"]).is_equal(2)
	assert_float(r["time"]).override_failure_message("%s %.1fs" % [label, r["time"]]).is_between(10.0, 32.0)  # 고른 패마다 흔들림 (평균은 위에서 15~25)
	for g in r["gaps"]:
		assert_float(g).is_less(6.0)
	var w: Array = r["struck"]
	for i in range(1, w.size()):
		var prev: EnemyAttackData = w[i - 1]
		if prev.follow_up != w[i]:
			assert_int(int((w[i] as EnemyAttackData).kind)).is_not_equal(int(prev.kind))


## 중간 우두머리 처치 연출 동안은 물결이 끝나지 않는다 → 연출이 끝난 뒤 숨 고르기 (패 고르기가 연출 위에 뜨지 않게).
func test_breather_waits_for_mid_boss_finale() -> void:
	sp.set_waves(_wave_set(2))
	sp.waves._start(0)
	sp.waves._queue.clear()
	var picks := [0]
	sp.breather.connect(func(_s: bool) -> void: picks[0] += 1)
	var m := sp.spawn_elite(Vector2(0, -150))
	var t := m.data.boss_feel.finale_time
	m.health.kill()
	assert_bool(sp.finale_playing()).is_true()
	await get_tree().process_frame
	sp._tick_waves(DT)
	assert_int(picks[0]).is_equal(0)  # 연출 중: 아직
	var end := Time.get_ticks_msec() + int(t * 1000.0) + 100  # 실제 시각으로 기다린다 (느린 시간에선 SceneTreeTimer가 일찍 끝난다)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame
	assert_bool(sp.finale_playing()).is_false()
	sp._tick_waves(DT)
	assert_int(picks[0]).is_equal(1)  # 연출 뒤 숨 고르기


## 시뮬레이션 (판 시각 GameTime.clock, 한 프레임 안에서 몇 분을 돌린다): 연출이 판 시각으로 끝나 물결이 끝난다.
func test_finale_hold_ends_on_sim_clock() -> void:
	var now := [5000]
	GameTime.clock = func() -> int: return now[0]
	sp.set_waves(_wave_set(2))
	sp.waves._start(0)
	sp.waves._queue.clear()
	var picks := [0]
	sp.breather.connect(func(_s: bool) -> void: picks[0] += 1)
	var m := sp.spawn_elite(Vector2(0, -150))
	var t := m.data.boss_feel.finale_time
	m.health.kill()
	m.remove_from_group(Enemy.GROUP)
	sp.remove_child(m)
	sp._tick_waves(DT)
	assert_int(picks[0]).is_equal(0)
	now[0] += int(t * 1000.0) + 10  # 실제 시간은 거의 안 흘렀다
	sp._tick_waves(DT)
	assert_int(picks[0]).is_equal(1)
	m.free()
