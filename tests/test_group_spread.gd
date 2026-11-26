extends GdUnitTestSuite
## 한꺼번에 부르는 무리·부하를 한 프레임에 몰아 만들지 않는다 (EnemySpawner.group_spread): 예고 길이를 하나씩 조금 늘려
## 나오는 순간이 프레임 몇 개에 흩어진다. 나오는 수는 그대로 (사용자 폴드 7 "몹이 갑자기 많이 확 뜰 때" 끊김).

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const COMMANDER := "res://data/enemies/waegun_commander.tres"

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


func _warning_times() -> Array:
	return sp.get_children().filter(func(c: Node) -> bool: return c is SpawnWarning).map(func(w: SpawnWarning) -> float: return snappedf(w.time, 0.001))


func test_warn_spawn_extra_lengthens_the_warning() -> void:
	var d := load("res://data/enemies/waegun_soldier.tres") as EnemyData
	for i in 3:
		sp.warn_spawn(d, Vector2(100 * i, -200), false, i * sp.group_spread)
	var t := _warning_times()
	assert_int(t.size()).is_equal(3)
	assert_float(t[1] - t[0]).is_equal_approx(sp.group_spread, 0.001)
	assert_float(t[2] - t[0]).is_equal_approx(sp.group_spread * 2.0, 0.001)


func test_boss_summon_is_spread_but_keeps_its_count() -> void:
	var d := ResourceLoader.load(COMMANDER, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EnemyData
	d.boss_feel = d.boss_feel.duplicate() as BossFeelData
	d.boss_feel.intro_hold = 0.0
	var e := sp.spawn_elite(Vector2(0, -200), d)
	var stg := BossStaging.of(e)
	var list: Array = d.phases[1].summon
	stg.summon(list)
	var t := _warning_times()
	assert_int(t.size()).is_equal(mini(list.size(), d.boss_feel.max_minions))
	t.sort()
	for i in range(1, t.size()):
		assert_float(t[i] - t[i - 1]).is_greater_equal(sp.group_spread - 0.001)  # 같은 프레임에 둘이 나오지 않는다
