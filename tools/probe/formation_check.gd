extends SceneTree
## 대형 뼈대 확인 (gdUnit 없이): 스크립트 불러오기, 한산 2물결 차례에 대형이 들어가는지, 자리 계산.

func _initialize() -> void:
	for p in ["res://scripts/combat/formation_brain.gd", "res://scripts/combat/formation_spawn.gd", "res://scripts/combat/enemy.gd",
			"res://scripts/combat/enemy_spawner.gd", "res://scripts/combat/enemy_attack.gd", "res://scripts/combat/wave_runner.gd"]:
		print("LOAD %s %s" % [p, load(p) != null])
	var st := load("res://data/stages/hansan_1592.tres") as StageTheme
	var r := WaveRunner.new(st.waves, 0.0)
	r._start(1)
	var idx := r._queue.map(func(x: Variant) -> String: return "F" if x is FormationData else ("E" if x == null else "."))
	print("WAVE2 queue %d formation at %d" % [r._queue.size(), idx.find("F")])
	var f := load("res://data/formations/hansan_gunner_line.tres") as FormationData
	for sh in [0, 1, 2]:
		f.shape = sh
		print("SHAPE %d %s" % [sh, str(FormationLayout.offsets(f, 5, Vector2.DOWN))])
	quit()
