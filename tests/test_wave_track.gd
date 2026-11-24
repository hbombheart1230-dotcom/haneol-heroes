extends GdUnitTestSuite
## 물결 진행 표시 (WaveTrack · WaveTrackDrawer): 물결 진행에 따라 점의 종류·상태가 맞고, 물결이 많아도 그려진다.

const HANSAN := preload("res://data/stages/hansan_1592.tres")


class Painter:
	extends Node2D
	var kinds := PackedInt32Array()
	var states := PackedInt32Array()

	func _draw() -> void:
		WaveTrackDrawer.draw(self, kinds, states, 2, 600.0, 0.5, 1, 1.0)


func _runner(count: int = 4) -> WaveRunner:
	var set := WaveSetData.new()
	for i in count:
		var w := WaveData.new()
		w.elite_last = i == 2
		set.waves.append(w)
	return WaveRunner.new(set)


func test_dots_are_waves_plus_boss_with_elite_kind() -> void:
	var r := _runner()
	var k := WaveTrack.kinds(r.data)
	assert_int(k.size()).is_equal(5)
	assert_int(k[2]).is_equal(WaveTrack.Kind.ELITE)
	assert_int(k[4]).is_equal(WaveTrack.Kind.BOSS)
	assert_int(k[0]).is_equal(WaveTrack.Kind.NORMAL)
	assert_int(WaveTrack.kinds(HANSAN.waves).size()).is_equal(HANSAN.waves.waves.size() + 1)  # 실제 전장 데이터에서 읽는다


func test_states_follow_the_run() -> void:
	var r := _runner()
	assert_array(Array(WaveTrack.states(r))).is_equal([0, 0, 0, 0, 0])  # 아직 시작 전 (숨 고르기)
	assert_int(WaveTrack.shown_number(r)).is_equal(1)
	r.index = 0
	r.phase = WaveRunner.Phase.RUN
	assert_array(Array(WaveTrack.states(r))).is_equal([1, 0, 0, 0, 0])
	r.index = 1
	assert_array(Array(WaveTrack.states(r))).is_equal([2, 1, 0, 0, 0])
	assert_int(WaveTrack.shown_number(r)).is_equal(2)
	r.phase = WaveRunner.Phase.GAP  # 둘째 물결을 끝내고 숨 고르기: 둘 찼고 지금 점은 없다, 다음은 3
	assert_array(Array(WaveTrack.states(r))).is_equal([2, 2, 0, 0, 0])
	assert_int(WaveTrack.shown_number(r)).is_equal(3)
	r.index = 3
	r.phase = WaveRunner.Phase.BOSS_WAIT
	assert_array(Array(WaveTrack.states(r))).is_equal([2, 2, 2, 2, 0])
	r.phase = WaveRunner.Phase.BOSS
	assert_array(Array(WaveTrack.states(r))).is_equal([2, 2, 2, 2, 1])
	assert_int(WaveTrack.shown_number(r)).is_equal(5)


func test_no_runner_means_nothing_to_show() -> void:
	assert_int(WaveTrack.states(null).size()).is_equal(0)
	assert_int(WaveTrack.cleared_count(null)).is_equal(0)


func test_drawing_runs_for_few_and_many_waves() -> void:
	for count in [4, 25]:
		var r := _runner(count)
		r.index = 1
		r.phase = WaveRunner.Phase.RUN
		var p: Painter = auto_free(Painter.new())
		p.kinds = WaveTrack.kinds(r.data)
		p.states = WaveTrack.states(r)
		add_child(p)
		await get_tree().process_frame
		assert_bool(p.is_inside_tree()).is_true()
		# 많아도 한 줄이 최대 너비를 넘지 않는다 (간격이 줄어든다)
		var st := InkUiStyle.default()
		var gap := minf(st.wave_spacing, st.wave_max_width / maxf(p.kinds.size() - 1, 1))
		assert_float(gap * (p.kinds.size() - 1)).is_less_equal(st.wave_max_width + 0.01)


func test_spawner_announces_each_wave_once_when_not_holding() -> void:
	var sp: EnemySpawner = auto_free(EnemySpawner.new())
	add_child(sp)
	var set := _runner().data
	sp.set_waves(set)
	var got: Array = []
	sp.wave_announce.connect(func(i: int, elite: bool) -> void: got.append([i, elite]))
	var hold := [true]
	sp.hold_check = func() -> bool: return hold[0]
	sp.tick(0.1)
	assert_int(got.size()).is_equal(0)  # 패 고르는 동안엔 알리지 않는다
	hold[0] = false
	sp.tick(0.1)
	sp.tick(0.1)
	assert_array(got).is_equal([[0, false]])  # 한 번만
	# 셋째 물결(번호 2)은 중간 우두머리
	sp.waves.index = 1
	sp.waves.phase = WaveRunner.Phase.GAP
	sp.tick(0.01)
	assert_array(got).is_equal([[0, false], [2, true]])
	# 우두머리 물결은 알림 없음 (우두머리 등장 띠가 몫)
	sp.waves.index = 3
	sp.tick(0.01)
	assert_int(got.size()).is_equal(2)


func test_banner_texts_come_from_data_and_wait_for_other_titles() -> void:
	var d := WaveBannerData.default()
	assert_str(d.title_for(0)).is_equal("첫째 물결")
	assert_str(d.title_for(1)).is_equal("둘째 물결")
	assert_str(d.title_for(40)).is_equal("41번째 물결")
	var b := WaveBanner.new()
	b.request(2, true)
	b.tick(0.1, true)  # 무대 시작 문구가 떠 있는 동안은 기다린다
	assert_bool(b.is_showing()).is_false()
	assert_bool(b.is_pending()).is_true()
	b.tick(0.1, false)
	assert_bool(b.is_showing()).is_true()
	assert_float(b.alpha()).is_between(0.0, 1.0)
	b.tick(d.show_time + 0.1, false)
	assert_bool(b.is_showing()).is_false()
	b.request(1, false)
	b.tick(0.1, true, true)  # 조작 안내 중에는 버린다
	assert_bool(b.is_pending()).is_false()
