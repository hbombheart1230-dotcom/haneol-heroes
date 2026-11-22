extends SceneTree
## 영웅 하나가 적을 처치한 장면을 시간 순서대로 찍는다 (줄: 전 = 군대별 연기·종이, 후 작은 처치(평타), 후 큰 처치(강타·기술)).
## 칸: 0.05 · 0.15 · 0.3 · 0.6 · 1.0초. 칸마다 한 장씩 찍어 이어 붙인다.
## godot --path . --resolution 720x1280 -s res://tools/shots/death_shot.gd -- <영웅 id> <출력 png>

const STAGE := {"yi_sun_sin": "hansan_1592", "gwanggaeto": "manchuria_395", "sejong": "gyeongbokgung_1433",
	"shin_saimdang": "chochungdo"}
const TIMES := [0.05, 0.15, 0.3, 0.6, 1.0]
const AT := Vector2(360, 700)
const CROP := Rect2i(210, 520, 300, 260)


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var hero: HeroData = load("res://data/heroes/%s.tres" % args[0])
	var st: StageTheme = load("res://data/stages/%s.tres" % STAGE[args[0]])
	var bg := Sprite2D.new()
	bg.texture = load(st.background_path)
	bg.position = Vector2(360, 640)
	bg.scale = Vector2.ONE * maxf(720.0 / bg.texture.get_size().x, 1280.0 / bg.texture.get_size().y)
	root.add_child(bg)
	var feel: CombatFeelData = load("res://data/feel/combat_feel.tres")
	var foe: EnemyData = load("res://data/enemies/waegun_soldier.tres")
	var ds := DeathStyleData.get_default()
	var el := ds.element_of(hero.id)
	var shots: Array[Image] = []
	for row in 3:
		for t in TIMES:
			var kill := KillFx.new(feel)
			root.add_child(kill)
			kill.set_process(false)  # 준비될 때 켜지므로 붙인 뒤에 끈다 (시각 고정)
			var fx := DeathFx.new(ds)
			root.add_child(fx)
			fx.set_process(false)
			if row == 0:
				kill.death_burst(AT, foe.death_style)
			else:
				var big := row == 2
				kill.death_burst(AT, &"none")
				fx.burst(AT, el, big)
				if el == &"ink":
					kill.drops(AT, Vector2.UP, ds.count(ds.ink_drops, big))
			kill.step(t)
			fx.step(t)
			kill.queue_redraw()
			fx.queue_redraw()
			for f in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			var vk := img.get_width() / 720.0
			shots.append(img.get_region(Rect2i(Vector2i(Vector2(CROP.position) * vk), Vector2i(Vector2(CROP.size) * vk))))
			kill.queue_free()
			fx.queue_free()
			await process_frame
	var w := shots[0].get_width()
	var h := shots[0].get_height()
	var cols := TIMES.size()
	var out := Image.create((w + 6) * cols, (h + 6) * 3, false, shots[0].get_format())
	out.fill(Color.WHITE)
	for i in shots.size():
		out.blit_rect(shots[i], Rect2i(Vector2i.ZERO, Vector2i(w, h)), Vector2i((i % cols) * (w + 6), (i / cols) * (h + 6)))
	out.save_png(args[1])
	quit()
