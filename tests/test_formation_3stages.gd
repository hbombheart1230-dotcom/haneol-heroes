extends GdUnitTestSuite
## 만주·경복궁·초충도 원거리 졸 대형 (사용자 "영웅에 맞게 맞추고 확 쓸어버릴 수 있게", 2026-11-26).
## 만주 거란 궁수 5 반달(거리 유지하며 물러나 쏘기) · 경복궁 여진 궁수 6 작은 둥근 진(한쪽에 고정) · 초충도 방아깨비 6 흩어진 무리(뛰어서 자리로).

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


## 둥근 진은 영웅을 둘러싸지 않고 한쪽에 작게 선다: 일제 사격이 한 방향에서 와서 경복궁 가림막이 막을 수 있고
## (둘러싸면 어디에 숨어도 맞는다 — 엄폐 시뮬 광개토 피해 몫 0.85), 정음진 하나가 여섯을 다 덮는다.
## 모양: ARC 300°에 6명 = 원 위에 60° 간격 (FormationLayout ARC, 마지막 간격도 60°).
func test_gyeongbok_circle_fits_one_jeongeum_and_faces_one_side() -> void:
	assert_int(RING.count).is_equal(6)
	assert_int(RING.shape).is_equal(FormationData.Shape.ARC)
	assert_float(RING.arc_deg).is_equal_approx(300.0, 0.01)
	assert_int(RING.move).is_equal(FormationData.Move.HOLD)
	var offs := FormationLayout.offsets(RING, RING.count, Vector2.DOWN)
	var far := 0.0
	var near := INF
	for i in offs.size():
		for j in range(i + 1, offs.size()):
			far = maxf(far, offs[i].distance_to(offs[j]))
			near = minf(near, offs[i].distance_to(offs[j]))
	var jeongeum := SJ.kit.tap as JeongeumSkill
	var reach := jeongeum.radius + RING.member.body_radius * Feedback.feel_data().skill_edge_scale
	assert_float(far).is_less_equal(reach)  # 누구에게 씌워도 여섯 모두
	assert_float(near).is_greater(RING.member.body_radius * 2.0)  # 몸이 겹치지 않게
	assert_float(RING.spawn_dist - RING.radius * 2.0).is_greater(200.0)  # 영웅에게서 떨어져 한쪽에


func test_chochungdo_swarm_hops() -> void:
	assert_int(SWARM.count).is_equal(6)
	assert_int(SWARM.shape).is_equal(FormationData.Shape.SCATTER)
	assert_int(SWARM.move).is_equal(FormationData.Move.HOP)
	assert_int(SWARM.member.behaviour.style).is_equal(EnemyBehaviourData.Style.HOP)


func test_waves_swap_scattered_ranged_for_the_formation() -> void:
	for row in [["manchuria_395", ARC], ["gyeongbokgung_1433", RING], ["chochungdo", SWARM]]:
		var st := load("res://data/stages/%s.tres" % row[0]) as StageTheme
		var w: WaveData = st.waves.waves[1]
		var f: FormationData = row[1]
		assert_array(w.formations).contains([f])
		assert_int(w.formation_after[0]).is_equal(10)
		var scattered := w.enemies.filter(func(e: EnemyData) -> bool: return e.id == f.member.id).size()
		assert_int(scattered).is_equal(1)  # 흩어진 원거리 3 → 1


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
