extends SceneTree
## 기술 그림 ↔ 실제 판정 프레임 재기: 실제 무대에서 영웅 기술 하나를 쏘고, 처음 프레임 몇 장에 판정 범위를 주황 선으로 겹친다.
##  - 반경 기술 (radius): 시전 자리 원, 반경 + 왜군 몸 (SkillContext.edge_of)
##  - 길 기술 (length·width, 파도격): 시전 자리 → 내닫는 쪽 길이, 폭/2 + 몸
##  - 투사체 (해일검기 물결·글자): 날아가는 동안 투사체마다 원 (판정 원 12px × 크기 + 적 HurtBox 22px)
## godot --path . --resolution 720x1280 -s res://tools/shots/skill_reach_strip.gd -- <출력 png> <영웅> <무대> <칸 tap|dash|charge|counter> [vfx_level=0] [charge=1]

const CROP := Vector2i(560, 560)
const SHOTS := [0, 3, 6, 10, 16, 24]
const HURT_R := 22.0  # enemy.tscn HurtBox2D


class Overlay extends Node2D:
	var circles: Array = []  # [center, r]
	var capsules: Array = []  # [a, b, half]
	var follow: Array = []  # Projectile
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var col := Color(1, 0.45, 0.1, 0.95)
		for c in circles:
			draw_arc(c[0], c[1], 0.0, TAU, 96, col, 2.0)
		for c in capsules:
			var a: Vector2 = c[0]
			var b: Vector2 = c[1]
			var n := (b - a).orthogonal().normalized() * float(c[2])
			draw_line(a + n, b + n, col, 2.0)
			draw_line(a - n, b - n, col, 2.0)
			draw_arc(a, c[2], 0.0, TAU, 48, col, 2.0)
			draw_arc(b, c[2], 0.0, TAU, 48, col, 2.0)
		for p in follow:
			if is_instance_valid(p):
				draw_arc(p.global_position, 12.0 * p.size_scale + HURT_R, 0.0, TAU, 48, col, 2.0)


func _initialize() -> void:
	_run()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var hero := StringName(a[1])
	var slot_name := a[3]
	var level := int(a[4]) if a.size() > 4 else 0
	var charge := float(a[5]) if a.size() > 5 else 1.0
	var main: Node = await ShotStage.open(self, StringName(a[2]), hero)
	await _wait(1.5)
	var player := main.get_node("Player") as Player
	var caster := player.get_node("SkillCaster") as SkillCaster
	player.grant_invulnerability(9999.0)
	player.facing = Vector2.RIGHT
	var slot: SkillCaster.Slot = {"tap": SkillCaster.Slot.TAP, "dash": SkillCaster.Slot.DASH,
		"charge": SkillCaster.Slot.CHARGE, "counter": SkillCaster.Slot.COUNTER}[slot_name]
	var def: SkillDef = caster.def_of(slot)
	def.vfx_level = level
	var grown := SkillGrowthData.get_default().scaled_def(def)
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var foe := spawner.spawn_at(load("res://data/enemies/waegun_soldier.tres"), player.global_position + Vector2(900, 0))
	foe.set_physics_process(false)
	var edge := SkillContext.edge_of(foe)
	var ov := Overlay.new()
	ov.z_index = 100
	main.add_child(ov)
	var at := player.global_position
	if "radius" in grown and float(grown.get("radius")) > 0.0:
		ov.circles.append([at, float(grown.get("radius")) + edge])
		print("[reach] %s %s lv%d: radius %.0f reach %.0f" % [hero, slot_name, level, grown.get("radius"), float(grown.get("radius")) + edge])
	if grown.has_method("radius_for"):  # 모은 만큼 반경 (사임당 화폭)
		var rc: float = grown.call("radius_for", charge)
		ov.circles.append([at, rc + edge])
		print("[reach] %s %s lv%d c%.1f: radius %.0f reach %.0f" % [hero, slot_name, level, charge, rc, rc + edge])
	if "length" in grown and "width" in grown:
		var b := at + Vector2.RIGHT * float(grown.get("length"))
		ov.capsules.append([at - Vector2.RIGHT * 30.0, b, float(grown.get("width")) * 0.5 + edge])
		print("[reach] %s %s lv%d: length %.0f width %.0f (half+edge %.0f)" % [hero, slot_name, level, grown.get("length"), grown.get("width"), float(grown.get("width")) * 0.5 + edge])
	var before := {}
	for c in main.get_children():
		before[c] = true
	caster.cast(slot, charge)
	var shots: Array[Image] = []
	for f in SHOTS[-1] + 1:
		for c in main.get_children():
			if c is Projectile and not before.has(c) and not ov.follow.has(c):
				ov.follow.append(c)
				var pr := c as Projectile
				print("[reach] projectile scale %.2f: hit r %.0f (+hurt %.0f), art %.0fx%.0f -> half height %.0f, front +%.0f" % [pr.size_scale,
					12.0 * pr.size_scale, 12.0 * pr.size_scale + HURT_R, pr.art_size.x * pr.size_scale, pr.art_size.y * pr.size_scale,
					pr.art_size.y * 0.5 * pr.size_scale, pr.art_size.x * 0.4 * pr.size_scale])
		await RenderingServer.frame_post_draw
		if SHOTS.has(f):
			shots.append(_grab(at))
	var strip := Image.create(CROP.x * shots.size(), CROP.y, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		strip.blit_rect(shots[i], Rect2i(Vector2i.ZERO, CROP), Vector2i(CROP.x * i, 0))
	strip.save_png(a[0])
	quit()


func _grab(world_at: Vector2) -> Image:
	var img := root.get_texture().get_image()
	var xf := root.get_canvas_transform() if root.get_camera_2d() == null else root.get_camera_2d().get_canvas_transform()
	var at := Vector2i((xf * world_at) * Vector2(img.get_size()) / root.get_visible_rect().size)
	var c := (at - CROP / 2 + Vector2i(CROP.x / 4, 0)).clamp(Vector2i.ZERO, img.get_size() - CROP)
	var r := img.get_region(Rect2i(c, CROP))
	r.convert(Image.FORMAT_RGBA8)
	return r


func _wait(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
