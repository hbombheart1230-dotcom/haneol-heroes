extends SceneTree
## 평타 한 번을 시간 순서로 잘라 가로 띠 한 장에 (검기 궤적 비교용). 순신 + 앞에 왜군 하나.
## godot --path . --resolution 450x1050 -s res://tools/shots/swing_strip.gd -- <출력 png> <타 1~3> <trail|crescent> [영웅 id] [fx|cone]
## cone이면 판정 부채꼴(사거리·각도)을 초록 선으로 겹쳐 그리고 적을 사거리 0.85에 세운다 (검기와 판정 어긋남 보기).
## fx면 영웅·적 그림을 숨기고 25ms 간격 16칸 + 휘두르기 전 바닥(<출력>_base.png)을 남긴다 (이펙트만 재기, measure_swing.py).
## crescent면 궤적을 끄고 예전 초승달로.

var SHOTS := 8
var GAP := 0.035
var CELL := 230


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_settings.cfg"
	GameSettings.hero_picked = true
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.stage_picked = true
	GameSettings.stage_id = &"hansan_1592"
	GameSettings.hero_id = StringName(args[3]) if args.size() > 3 else &"yi_sun_sin"
	GameSettings.tutorial_enabled = false
	GameSettings.show_stats = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	spawner.set_process(false)
	spawner.set_physics_process(false)
	var end := Time.get_ticks_msec() + 3800  # 무대 이름 띠가 사라질 때까지
	while Time.get_ticks_msec() < end:
		await process_frame
	var player := main.get_node("Player") as Player
	if args.size() > 3:  # 저장된 영웅 대신 고른 영웅으로
		player.change_hero(load("res://data/heroes/%s.tres" % args[3]))
		for i in 3:
			await process_frame
	var atk := player.get_node("AutoAttack") as AutoAttack
	if args[2] == "crescent":
		player.remove_meta(&"swing_trail")
	var dir := Vector2(1, -0.25).normalized()
	player.facing = dir
	for o in root.get_tree().get_nodes_in_group(Enemy.GROUP):
		o.queue_free()
	var e: Node2D = spawner._spawn_special(spawner.spawn_table[0])
	e.global_position = player.global_position + dir * 95
	e.set_physics_process(false)
	var fx_only := args.size() > 4 and args[4] == "fx"
	var cone := args.size() > 4 and args[4] == "cone"
	if cone:
		var sd := atk.stats()
		var stp := int(args[1])
		var cr := sd.melee_range * ComboSteps.at(sd.step_range_mults, stp, 1.0)
		e.global_position = player.global_position + dir * cr * 0.85
		var ov := Cone.new()
		ov.r = cr
		ov.half = deg_to_rad(sd.melee_arc_degrees * ComboSteps.at(sd.step_arc_mults, stp, 1.0) * 0.5)
		ov.dir = dir
		ov.z_index = 10
		player.add_child(ov)
		CELL = 400
	if fx_only:
		SHOTS = 16
		GAP = 0.025
		CELL = 320
	await process_frame
	var step := int(args[1])
	atk.chain_step = step - 1
	atk._melee(player.global_position, dir, [], step)
	var t0 := Time.get_ticks_msec()
	var first := (atk.step_pause() + atk.melee_delay() - (0.16 if fx_only else 0.12)) * 1000.0
	if fx_only:
		player.get_node("PlayerView").visible = false
		e.visible = false
		await RenderingServer.frame_post_draw
		_cell(player).save_png(args[0].get_basename() + "_base.png")
	var cells: Array[Image] = []
	var k := 0
	while k < SHOTS:
		for o in root.get_tree().get_nodes_in_group(Enemy.GROUP):  # 다른 적(물결)은 치운다
			if o != e:
				o.queue_free()
		var dt := Time.get_ticks_msec() - t0
		if dt >= first + k * GAP * 1000.0:
			await RenderingServer.frame_post_draw
			cells.append(_cell(player))
			k += 1
		await process_frame
	var strip := Image.create(CELL * SHOTS, CELL, false, cells[0].get_format())
	for i in cells.size():
		strip.blit_rect(cells[i], Rect2i(0, 0, CELL, CELL), Vector2i(i * CELL, 0))
	strip.save_png(args[0])
	quit()


## 영웅 둘레 CELL 칸을 잘라 온다.
func _cell(player: Node2D) -> Image:
	var img := root.get_texture().get_image()
	var sc := img.get_width() / root.get_visible_rect().size.x
	var p := (root.get_canvas_transform() * player.global_position) * sc + Vector2(0, -30) * sc
	return img.get_region(Rect2i(Vector2i(p) - Vector2i(CELL, CELL) / 2, Vector2i(CELL, CELL)))


## 판정 부채꼴 윤곽 (cone 모드).
class Cone extends Node2D:
	var r := 100.0
	var half := 0.5
	var dir := Vector2.RIGHT

	func _draw() -> void:
		var a := dir.angle()
		var c := Color(0.3, 1.0, 0.4, 0.9)
		draw_arc(Vector2.ZERO, r, a - half, a + half, 24, c, 2.0)
		draw_line(Vector2.ZERO, Vector2.from_angle(a - half) * r, c, 2.0)
		draw_line(Vector2.ZERO, Vector2.from_angle(a + half) * r, c, 2.0)
