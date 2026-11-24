extends GdUnitTestSuite
## 근접 잡몹 수 배율 (WaveSwarm, WaveSetData.melee_count_mult): 기본은 지금 수, 켜면 근접 잡몹만 늘고 체력·원거리·정예는 그대로.

const MOUSE := "res://data/enemies/cc_mouse.tres"
const HOPPER := "res://data/enemies/cc_grasshopper.tres"
const BEETLE := "res://data/enemies/cc_beetle.tres"
const ARCHER := "res://data/enemies/jurchen_archer.tres"
const MANTIS := "res://data/enemies/cc_mantis.tres"
const STAGES := ["hansan_1592", "manchuria_395", "gyeongbokgung_1433", "chochungdo"]


func _d(p: String) -> EnemyData:
	return load(p) as EnemyData


func _count(list: Array, d: EnemyData) -> int:
	return list.filter(func(x: EnemyData) -> bool: return x == d).size()


## 사용자 결정 (D안): 네 무대 모두 근접 잡몹 ×1.5.
func test_every_stage_uses_one_and_a_half_melee() -> void:
	for id in STAGES:
		var st := load("res://data/stages/%s.tres" % id) as StageTheme
		assert_float(st.waves.melee_count_mult).override_failure_message(id).is_equal(1.5)


func test_melee_trash_kinds() -> void:
	assert_bool(WaveSwarm.is_melee_trash(_d(MOUSE))).is_true()
	assert_bool(WaveSwarm.is_melee_trash(_d(BEETLE))).is_true()
	assert_bool(WaveSwarm.is_melee_trash(_d(HOPPER))).is_false()  # 원거리
	assert_bool(WaveSwarm.is_melee_trash(_d(ARCHER))).is_false()
	assert_bool(WaveSwarm.is_melee_trash(_d(MANTIS))).is_false()  # 정예
	assert_bool(WaveSwarm.is_melee_trash(_d("res://data/enemies/waegun_flag.tres"))).is_false()  # 깃발 (둘레 힘)
	assert_bool(WaveSwarm.is_melee_trash(_d("res://data/enemies/cc_frog.tres"))).is_false()


func test_expand_only_adds_melee() -> void:
	var m := _d(MOUSE)
	var h := _d(HOPPER)
	var b := _d(BEETLE)
	var base: Array = [m, m, h, m, b, m, h, m, m, m]  # 근접 8, 원거리 2
	assert_array(WaveSwarm.expand(base, 1.0)).is_equal(base)
	var x15 := WaveSwarm.expand(base, 1.5)
	assert_int(x15.size()).is_equal(14)
	assert_int(_count(x15, h)).is_equal(2)
	assert_int(_count(x15, m) + _count(x15, b)).is_equal(12)
	var x125 := WaveSwarm.expand(base, 1.25)
	assert_int(x125.size()).is_equal(12)
	assert_int(_count(x125, h)).is_equal(2)


func test_runner_queue_grows_but_elite_stays_last() -> void:
	var st := ResourceLoader.load("res://data/stages/chochungdo.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageTheme
	var ws := st.waves
	ws.melee_count_mult = 1.0  # 무대 기본(D안 1.5)과 견준다: 배율 없는 수
	var off := WaveRunner.new(ws, 0.0)
	off.tick(0.01, 0, false)
	var n_off := off._queue.size()
	ws.melee_count_mult = 1.5
	var on := WaveRunner.new(ws, 0.0)
	on.tick(0.01, 0, false)
	assert_int(on._queue.size()).is_greater(n_off)
	for i in 2:  # 3물결 (정예가 마지막)까지
		for r: WaveRunner in [on]:
			r._queue.clear()
			r.tick(0.01, 0, false)
			r.tick(10.0, 0, false)
	assert_int(on.index).is_equal(2)
	assert_object(on._queue.back()).is_null()  # 정예(무리) 자리는 그대로 맨 끝 하나
	assert_int(on._queue.count(null)).is_equal(1)


## 체력은 그대로: 늘어난 적도 같은 EnemyData (hp 배율을 곱하지 않는다).
func test_added_enemies_keep_their_hp() -> void:
	var m := _d(MOUSE)
	for d: EnemyData in WaveSwarm.expand([m, m, m, m], 1.5):
		assert_int(d.max_hp).is_equal(m.max_hp)
