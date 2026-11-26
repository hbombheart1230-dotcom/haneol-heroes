extends GdUnitTestSuite
## 일제 사격 공정성·읽힘 (VolleyFeelData): 한 번의 일제 사격 명중 상한, 같은 대형의 탄은 같은 열쇠,
## 예고를 모아 그리는 층, 한꺼번에 쓰러뜨릴 때 글자 조각 상한.

const GUNNER := "res://data/enemies/waegun_gunner.tres"


func before_test() -> void:
	VolleyBeat.reset()


func test_defaults() -> void:
	var v := VolleyFeelData.default()
	assert_int(v.max_hero_hits).is_equal(2)
	assert_bool(v.batch_telegraphs).is_true()
	assert_float(v.sfx_gap).is_greater(0.06)


func test_hit_cap_per_volley_key() -> void:
	assert_bool(VolleyBeat.can_hit("", 2)).is_true()  # 일제 사격 아님: 늘
	assert_bool(VolleyBeat.can_hit("f1:10", 2)).is_true()
	VolleyBeat.note_hit("f1:10")
	assert_bool(VolleyBeat.can_hit("f1:10", 2)).is_true()
	VolleyBeat.note_hit("f1:10")
	assert_bool(VolleyBeat.can_hit("f1:10", 2)).is_false()  # 세 번째 탄은 지나간다
	assert_bool(VolleyBeat.can_hit("f1:11", 2)).is_true()  # 다음 일제 사격은 새로
	for i in VolleyBeat.KEEP + 5:  # 오래된 열쇠는 버려 커지지 않는다
		VolleyBeat.note_hit("k%d" % i)
	assert_int(VolleyBeat._hits.size()).is_less_equal(VolleyBeat.KEEP)


func test_formation_members_share_key_in_one_frame() -> void:
	var d := load(GUNNER) as EnemyData
	var a := _enemy(d)
	var b := _enemy(d)
	var f := FormationBrain.new(FormationData.new(), null, Vector2.ZERO, Vector2.DOWN)
	a.formation = f
	b.formation = f
	assert_str(VolleyBeat.key_for(a)).is_equal(VolleyBeat.key_for(b))
	assert_str(VolleyBeat.key_for(a)).is_not_empty()
	var first := VolleyBeat.key_for(a)
	f.fired.emit([a, b])  # 일제 사격이 끝나면 다음 번호 (틱이 몇 번 돌든 일제 사격마다 따로)
	assert_str(VolleyBeat.key_for(a)).is_not_equal(first)
	assert_str(VolleyBeat.key_for(a)).is_equal(VolleyBeat.key_for(b))
	var lone := _enemy(d)  # 대형 밖 철포병 (우두머리가 부른 것 포함): 상한 없음
	assert_str(VolleyBeat.key_for(lone)).is_empty()


## 판·시뮬마다 비운다 (같은 프로세스의 앞 싸움 명중 수가 넘어오지 않게, boss_sim 결정성).
func test_reset_between_fights() -> void:
	VolleyBeat.note_hit("f9:0")
	BossSim.reset_globals()
	assert_int(VolleyBeat.hits("f9:0")).is_equal(0)


func test_paint_batches_every_style_without_drawing_calls() -> void:
	var d := RangedTelegraphData.default()
	var old := d.style
	var e := _enemy(load(GUNNER) as EnemyData)
	e.attack.state = EnemyAttack.State.WINDUP
	for st in 3:
		d.style = st
		var b := InkBatch.new()
		for k in [0.0, 0.5, 1.0]:
			RangedTelegraph.paint(e, b, Vector2(10, 20), k, k >= 1.0, 10)
		assert_int(b.indices.size()).is_greater(0)
		assert_int(b.indices.size() % 3).is_equal(0)
	d.style = old


func test_crowd_look_thins_lines() -> void:
	var v := VolleyFeelData.default()
	var keep := [v.crowd_width_mult, v.crowd_from]
	var e := _enemy(load(GUNNER) as EnemyData)
	e.attack.state = EnemyAttack.State.WINDUP
	e.attack.aim_dir = Vector2.RIGHT
	v.crowd_from = 6
	v.crowd_width_mult = 0.5
	var thin := InkBatch.new()
	RangedTelegraph.paint(e, thin, Vector2.ZERO, 0.5, false, 8)
	var full := InkBatch.new()
	RangedTelegraph.paint(e, full, Vector2.ZERO, 0.5, false, 1)
	assert_float(_span(thin)).is_less(_span(full))
	v.crowd_width_mult = keep[0]
	v.crowd_from = keep[1]


func test_glyph_bits_are_capped_rest_become_stars() -> void:
	var data := DeathStyleData.get_default().duplicate() as DeathStyleData
	data.max_glyph_bits = 5
	var fx := DeathFx.new(data)
	add_child(auto_free(fx))
	for i in 6:
		fx.burst(Vector2(i * 40, 0), &"glyph", false)
	assert_int(fx._count_kind(DeathFx.Bit.GLYPH)).is_less_equal(5)
	assert_int(fx.bit_count()).is_greater(5)  # 넘친 몫은 별로 남는다


func _enemy(d: EnemyData) -> Enemy:
	var e: Enemy = preload("res://scenes/enemy.tscn").instantiate()
	e.data = d
	add_child(auto_free(e))
	e.attack = EnemyAttack.new(d.attack, 0.0)
	return e


## 모은 점들의 옆 폭: 겨눈 쪽에 수직인 범위 (가는 획일수록 작다). 길이(겨눈 쪽)는 붐빔과 상관없다.
func _span(b: InkBatch, aim: Vector2 = Vector2.RIGHT) -> float:
	var side := aim.orthogonal().normalized()
	var lo := INF
	var hi := -INF
	for p in b.points:
		lo = minf(lo, p.dot(side))
		hi = maxf(hi, p.dot(side))
	return hi - lo
