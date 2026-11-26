extends SceneTree
## 물결별 대형 차례 확인 (gdUnit 없이): 네 무대 물결마다 펼친 차례 길이, 대형 자리, 흩어진 원거리 수.

const STAGES := ["hansan_1592", "manchuria_395", "gyeongbokgung_1433", "chochungdo"]


func _initialize() -> void:
	for id in STAGES:
		var st := load("res://data/stages/%s.tres" % id) as StageTheme
		for i in st.waves.waves.size():
			var r := WaveRunner.new(st.waves, 0.0)
			r._start(i)
			var at := []
			var members := 0
			for k in r._queue.size():
				if r._queue[k] is FormationData:
					at.append(k)
					members += (r._queue[k] as FormationData).count
			var w: WaveData = st.waves.waves[i]
			print("QUEUE %s w%d len %d formations %s members %d cap %d" % [id, i + 1, r._queue.size(), at, members, r.wave_cap(st.waves.max_alive)])
		print("SCORE %s total %d formations %d" % [id, _score(st, false), _score(st, true)])
	quit()


## 판 전체 처치 점수 (test_stage_waves._stage_score와 같은 셈, 정예 자리는 무대 정예): only_f면 대형 구성원 몫만.
func _score(st: StageTheme, only_f: bool) -> int:
	var n := 0
	for wave: WaveData in st.waves.waves:
		var list: Array = [] if only_f else wave.enemies.duplicate()
		if wave.elite_last and not only_f:
			list.append_array(wave.elite_group if not wave.elite_group.is_empty() else [st.elite])
		for f: FormationData in wave.formations:
			for k in f.count:
				list.append(f.member)
		for e: EnemyData in list:
			n += roundi(e.xp * st.waves.xp_mult)
	return n
