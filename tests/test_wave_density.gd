extends GdUnitTestSuite
## 밀도 변형 (WaveSetData.alive_cap_add)과 중간 우두머리 물결 뒤 회복 (elite_clear_heal, WaveBreath): 기본 꺼짐.

const STAGES := ["hansan_1592", "manchuria_395", "gyeongbokgung_1433", "chochungdo"]


func _wave_set(caps: Array, elite_at: int) -> WaveSetData:
	var ws := WaveSetData.new()
	ws.max_alive = 14
	var list: Array[WaveData] = []
	for i in caps.size():
		var w := WaveData.new()
		w.max_alive = caps[i]
		w.elite_last = i == elite_at
		list.append(w)
	ws.waves = list
	return ws


func test_default_is_off_on_every_stage() -> void:
	for id in STAGES:
		var st := load("res://data/stages/%s.tres" % id) as StageTheme
		assert_int(st.waves.alive_cap_add).override_failure_message(id).is_equal(0)
		assert_float(st.waves.elite_clear_heal).override_failure_message(id).is_equal(0.0)


func test_cap_add_raises_wave_and_stage_cap() -> void:
	var ws := _wave_set([8, 14, 0], -1)
	var r := WaveRunner.new(ws)
	r.index = 0
	assert_int(r.wave_cap(14)).is_equal(8)
	ws.alive_cap_add = 4
	assert_int(r.wave_cap(14)).is_equal(12)
	r.index = 1
	assert_int(r.wave_cap(14)).is_equal(18)
	r.index = 2  # 물결 값 없음 → 무대 상한 + 더하기
	assert_int(r.wave_cap(14)).is_equal(18)
	r.index = 1  # 난이도 추가분(cap 16)도 그대로 얹힌다
	assert_int(r.wave_cap(16)).is_equal(20)


func test_heal_only_after_elite_wave_and_only_when_on() -> void:
	var ws := _wave_set([8, 8], 1)
	var r := WaveRunner.new(ws)
	var h := Health.new()
	h.max = 100
	h.current = 40
	r.index = 1
	assert_int(WaveBreath.on_cleared(r, h)).is_equal(0)  # 꺼짐
	ws.elite_clear_heal = 0.25
	r.index = 0
	assert_int(WaveBreath.on_cleared(r, h)).is_equal(0)  # 정예 물결 아님
	r.index = 1
	assert_int(WaveBreath.on_cleared(r, h)).is_equal(25)
	assert_int(h.current).is_equal(65)
	h.free()
