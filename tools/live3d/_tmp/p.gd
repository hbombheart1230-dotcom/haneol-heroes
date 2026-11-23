extends SceneTree
const PV := preload("res://scripts/player/player_view_3d.gd")
const Rig := preload("res://scripts/art/live3d/live3d_rig.gd")
func _initialize() -> void:
	_run()
func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var live: Live3DHeroData = load("res://data/live3d/yi_sun_sin.tres")
	var hero: HeroData = load("res://data/heroes/yi_sun_sin.tres")
	var t := Time.get_ticks_usec()
	var r: Node = Rig.new()
	root.add_child(r)
	r.setup(live, PV.durations(hero.sprite_sheet))
	print("setup ms ", (Time.get_ticks_usec() - t) / 1000.0)
	var s := Sprite2D.new()
	s.texture = r.texture()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ink_live.gdshader")
	s.material = mat
	s.position = Vector2(200, 200)
	root.add_child(s)
	for k in 3:
		print("warm ", await _f())
	for a in ["idle", "attack", "attack2", "attack3", "cast_tap", "dash", "hit", "run", "attack2", "cast_charge", "death"]:
		r.play_body(a, true, -1.0, 1.0)
		var w := 0.0
		for i in 5:
			w = maxf(w, await _f())
		print(a, " ", w)
	r.set_upper("attack", true, true, 1.0, 0.016)
	print("upper ", await _f(), " ", await _f())
	quit()
var _p := 0
func _f() -> float:
	if _p == 0: _p = Time.get_ticks_usec()
	await process_frame
	var n := Time.get_ticks_usec()
	var d := (n - _p) / 1000.0
	_p = n
	return d
