extends SceneTree
## gdUnit 잠금 중에 tests/test_volley_feel.gd의 핵심을 단독으로 확인한다 (같은 내용). 실패하면 FAIL 줄과 종료 코드 1.
## godot --headless --path . -s res://tools/probe/volley_check.gd

var fails := 0


func _initialize() -> void:
	var gunner := load("res://data/enemies/waegun_gunner.tres") as EnemyData
	VolleyBeat.reset()
	_ok(VolleyBeat.can_hit("", 2), "no key always hits")
	VolleyBeat.note_hit("f1:10")
	VolleyBeat.note_hit("f1:10")
	_ok(not VolleyBeat.can_hit("f1:10", 2), "third shot passes")
	_ok(VolleyBeat.can_hit("f1:11", 2), "next volley fresh")
	for i in VolleyBeat.KEEP + 5:
		VolleyBeat.note_hit("k%d" % i)
	_ok(VolleyBeat._hits.size() <= VolleyBeat.KEEP, "keys pruned")
	var a := _enemy(gunner)
	var b := _enemy(gunner)
	var f := FormationBrain.new(FormationData.new(), null, Vector2.ZERO, Vector2.DOWN)
	a.formation = f
	b.formation = f
	_ok(VolleyBeat.key_for(a) == VolleyBeat.key_for(b) and VolleyBeat.key_for(a) != "", "formation shares key")
	a.attack.state = EnemyAttack.State.WINDUP
	var d := RangedTelegraphData.default()
	for st in 3:
		d.style = st
		var bt := InkBatch.new()
		RangedTelegraph.paint(a, bt, Vector2(10, 20), 0.5, false, 10)
		_ok(bt.indices.size() > 0 and bt.indices.size() % 3 == 0, "paint style %d" % st)
	var data := DeathStyleData.get_default().duplicate() as DeathStyleData
	data.max_glyph_bits = 5
	var fx := DeathFx.new(data)
	root.add_child(fx)
	for i in 6:
		fx.burst(Vector2(i * 40, 0), &"glyph", false)
	_ok(fx._count_kind(DeathFx.Bit.GLYPH) <= 5 and fx.bit_count() > 5, "glyph cap → stars")
	print("VOLLEY_CHECK ", "PASS" if fails == 0 else "FAIL %d" % fails)
	quit(1 if fails else 0)


func _enemy(dd: EnemyData) -> Enemy:
	var e: Enemy = load("res://scenes/enemy.tscn").instantiate()
	e.data = dd
	root.add_child(e)
	e.attack = EnemyAttack.new(dd.attack, 0.0)
	return e


func _ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
		print("FAIL ", what)
