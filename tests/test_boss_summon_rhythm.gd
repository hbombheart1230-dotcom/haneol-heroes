extends GdUnitTestSuite
## 우두머리 주기 소환 (BossFeelData.summon_every·summon_first, BossStaging): 꺼져 있으면 단계 전환 때만 부르고,
## 켜면 첫 시각 뒤 외침 한 박자 → 먹 번짐 예고 → 부하. max_minions를 넘지 않는다.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const COMMANDER := "res://data/enemies/waegun_commander.tres"
const BOSSES := ["waegun_commander", "boss_general", "jurchen_chieftain", "cc_frog"]
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


func after_test() -> void:
	BossSim.reset_globals()


func _boss(every: float, first: float) -> EnemyData:
	var d := ResourceLoader.load(COMMANDER, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EnemyData
	d.boss_feel = d.boss_feel.duplicate() as BossFeelData
	d.boss_feel.summon_every = every
	d.boss_feel.summon_first = first
	d.boss_feel.intro_hold = 0.0
	return d


func _step(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		t += DT
		for c in sp.get_children():
			if c.is_queued_for_deletion():
				continue
			if c is SpawnWarning or c is BossStaging:
				c._physics_process(DT)


func _minions() -> int:
	return sp.alive_count() + sp._warnings - 1


func test_rhythm_list_follows_phase() -> void:
	var d := _boss(10.0, 5.0)
	var e := sp.spawn_elite(Vector2(0, -200), d)
	assert_array(BossStaging.rhythm_list(e)).is_equal(d.phases[0].summon)  # 1단계: 첫 전환의 부하
	e.phase_index = 2
	assert_array(BossStaging.rhythm_list(e)).is_equal(d.phases[1].summon)


func test_off_by_default_summons_nothing_before_phase() -> void:
	var e := sp.spawn_elite(Vector2(0, -200), _boss(0.0, -1.0))
	assert_object(e).is_not_null()
	_step(20.0)
	assert_int(_minions()).is_equal(0)


func test_first_summon_after_first_seconds_and_capped() -> void:
	var d := _boss(6.0, 3.0)
	var e := sp.spawn_elite(Vector2(0, -200), d)
	assert_object(e).is_not_null()
	_step(2.5)
	assert_int(_minions()).is_equal(0)
	_step(1.5)
	assert_int(_minions()).is_greater(0)
	_step(30.0)
	assert_int(_minions()).is_less_equal(d.boss_feel.max_minions)


func test_group_members_count_toward_cap_unless_turned_off() -> void:
	var d := ResourceLoader.load("res://data/enemies/waegun_elite.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EnemyData
	d.boss_feel = d.boss_feel.duplicate() as BossFeelData
	var a := sp.spawn_elite(Vector2(0, -200), d)
	sp.spawn_elite(Vector2(200, -200), d)
	var stg := BossStaging.of(a)
	assert_int(stg.minion_count()).is_equal(1)  # 지금: 무리 한 명도 부하로 센다
	d.boss_feel.cap_counts_group = false
	assert_int(stg.minion_count()).is_equal(0)  # 끄면 부른 부하만
