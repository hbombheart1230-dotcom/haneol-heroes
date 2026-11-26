extends GdUnitTestSuite
## 만주·경복궁·초충도 원거리 졸 대형 (사용자 "영웅에 맞게 맞추고 확 쓸어버릴 수 있게", 2026-11-26).
## 만주 거란 궁수 5 반달(거리 유지하며 물러나 쏘기) · 경복궁 여진 궁수 6 둥근 진(영웅 둘레 고정) · 초충도 방아깨비 6 흩어진 무리(뛰어서 자리로).

const ARC := preload("res://data/formations/manchuria_khitan_arc.tres")
const RING := preload("res://data/formations/gyeongbok_jurchen_ring.tres")
const SWARM := preload("res://data/formations/chochungdo_hopper_swarm.tres")
const GW := preload("res://data/heroes/gwanggaeto.tres")
const SJ := preload("res://data/heroes/sejong.tres")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")


func _min_gap(offs: PackedVector2Array) -> Array:
	var lo := INF
	var hi := 0.0
	for i in offs.size() - 1:
		var d := offs[i].distance_to(offs[i + 1])
		lo = minf(lo, d)
		hi = maxf(hi, d)
	return [lo, hi]


func test_manchuria_arc_fits_gwanggaeto_chain() -> void:
	assert_int(ARC.count).is_equal(5)
	assert_int(ARC.shape).is_equal(FormationData.Shape.ARC)
	assert_int(ARC.move).is_equal(FormationData.Move.KITE)
	var g := _min_gap(FormationLayout.offsets(ARC, ARC.count, Vector2.DOWN))
	var chain: float = GW.kit.charge.chain_range  # 낙뢰 연쇄: 이웃 사이가 이 안이면 끝부터 이어 맞는다
	assert_float(g[1]).is_less_equal(chain)
	assert_float(g[0]).is_greater(60.0)  # 몸이 겹치지 않게
	assert_float(ARC.stop_range).is_less(ARC.member.behaviour.attack.trigger_range)


## 둥근 진은 영웅을 가운데 두고 둘러싼다 (사용자 2026-11-26 "영웅을 두고 동그랗게 서는게 간진데").
## 숨을 데가 없는 대신 세종 해시계 멈춤(반경 300) 한 바퀴에 여섯이 다 들고, 원정 영웅은 내닫기로 구성원 사이를 뚫고 나간다.
func test_gyeongbok_ring_surrounds_hero_inside_sundial() -> void:
	assert_int(RING.count).is_equal(6)
	assert_int(RING.shape).is_equal(FormationData.Shape.RING)
	assert_int(RING.move).is_equal(FormationData.Move.HOLD)
	var sundial: float = SJ.kit.counter.radius  # 해시계 멈춤 = 세종 둘레 원 한 바퀴
	assert_float(RING.radius).is_less_equal(sundial)
	assert_float(RING.radius).is_greater(200.0)  # 영웅 바로 옆에 붙지 않는다


func test_chochungdo_swarm_hops() -> void:
	assert_int(SWARM.count).is_equal(6)
	assert_int(SWARM.shape).is_equal(FormationData.Shape.SCATTER)
	assert_int(SWARM.move).is_equal(FormationData.Move.HOP)
	assert_int(SWARM.member.behaviour.style).is_equal(EnemyBehaviourData.Style.HOP)


func test_waves_swap_scattered_ranged_for_the_formation() -> void:
	for row in [["manchuria_395", ARC], ["gyeongbokgung_1433", RING], ["chochungdo", SWARM]]:
		var st := load("res://data/stages/%s.tres" % row[0]) as StageTheme
		var f: FormationData = row[1]
		for i in [1, 3]:  # 2·4물결: 흩어진 원거리는 없고 대형으로만 (1물결은 원래 원거리 없음)
			var w: WaveData = st.waves.waves[i]
			assert_array(w.formations).contains([f])
			var scattered := w.enemies.filter(func(e: EnemyData) -> bool: return e.id == f.member.id).size()
			assert_int(scattered).override_failure_message("%s w%d" % [row[0], i + 1]).is_equal(0)


func test_hop_aims_at_own_slot_without_overshooting() -> void:
	var b := FormationBrain.new(SWARM, null, Vector2.ZERO, Vector2.DOWN)
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SWARM.member
	add_child(auto_free(e))
	e.set_physics_process(false)
	b.join(e, 0)
	var slot := b.slot_point(0)
	e.global_position = slot + Vector2(50, 0)
	var d := b.hop_dir(e)
	assert_float(d.length()).is_less(1.0)  # 남은 거리가 한 번 뛰기보다 짧으면 그만큼만
	assert_float(d.x).is_less(0.0)  # 자리 쪽
	e.global_position = slot + Vector2(900, 0)
	assert_float(b.hop_dir(e).length()).is_equal_approx(1.0, 0.001)
