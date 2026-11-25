extends GdUnitTestSuite
## 원거리 예고: 데이터 값이 맞고, 사격 예고가 번쩍일 때까지 그려도 탈이 없다.


func test_data_defaults_are_sane() -> void:
	var d := RangedTelegraphData.default()
	assert_int(d.style).is_between(0, 2)
	assert_float(d.alpha_to).is_greater(d.alpha_from)
	assert_float(d.width_to).is_less(12.0)  # 가늘고 날렵하게


func test_shoot_windup_draws_band_for_every_style() -> void:
	var d := RangedTelegraphData.default()
	var old := d.style
	var archer := load("res://data/enemies/waegun_gunner.tres") as EnemyData
	for st in 3:
		d.style = st
		var e: Enemy = preload("res://scenes/enemy.tscn").instantiate()
		e.data = archer
		add_child(auto_free(e))
		var a := EnemyAttack.new(archer.attack, 0.0)
		a.state = EnemyAttack.State.WINDUP
		e.attack = a
		for k in [0.0, 0.5, 1.0]:
			RangedTelegraph.draw(e, e, k, k >= 1.0)
	d.style = old
