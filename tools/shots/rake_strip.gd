extends SceneTree
## 순신 해일검기가 잡몹 떼를 지나가는 연속 장면 띠 + 떼 처치 재기 (전·후 비교용: 예전 코드에서도 돈다).
##   strip <충전 0~1> <출력 png> : 실제 main 장면, 위쪽에 잡몹 떼, 놓은 뒤 STRIP_TIMES마다 한 칸 (가로 띠).
##   horde <충전 0~1> <마리 수>  : 떼 n마리 앞에서 한 번 쏘고 1.6초 동안 처치 수·넣은 피해·마지막 피해 시각을 적는다.
## godot --path . --resolution 720x1280 -s res://tools/shots/rake_strip.gd -- strip 1.0 build/preview/rake_after.png
## 결과 줄: RAKE charge=<c> n=<n> kills=<k> damage=<합> hits=<맞은 수> last_hit_s=<초>

const STRIP_TIMES := [0.06, 0.14, 0.22, 0.3, 0.38, 0.46, 0.56, 0.7]
const CROP := Rect2i(0, 120, 720, 760)

var main: Node
var player: Player
var caster: SkillCaster
var spawner: EnemySpawner


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() > 0 else "strip"
	var charge := float(args[1]) if args.size() > 1 else 1.0
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_settings.cfg"
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.stage_picked = true
	GameSettings.tutorial_done = true
	GameSettings.hero_picked = true
	GameSettings.opening_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.stage_id = &"hansan_1592"
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.tutorial_enabled = false
	GameSettings.story_enabled = false
	GameSettings.enemy_hp_bars = false
	GameSettings.save_settings()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 200:  # 무대 제목 띠
		await process_frame
	spawner = main.get_node("EnemySpawner") as EnemySpawner
	player = main.get_node("Player") as Player
	caster = player.get_node("SkillCaster") as SkillCaster
	if spawner.waves:
		spawner.waves.phase = WaveRunner.Phase.BOSS  # 물결은 멈추고 손으로 놓는다
	player.grant_invulnerability(9999.0)
	player.facing = Vector2.UP
	var n := int(args[2]) if mode == "horde" and args.size() > 2 else 8
	var foes := _horde(n)
	for i in 10:
		await physics_frame
	if mode == "horde":
		await _horde_run(foes, charge, n)
	else:
		await _strip(charge, args[2] if args.size() > 2 else "build/preview/rake.png")
	quit()


## 떼: 영웅 위쪽 150~520px에 지그재그로 (실제 잡몹, 움직이지 않게).
func _horde(n: int) -> Array:
	var st: StageTheme = load("res://data/stages/hansan_1592.tres")
	var d: EnemyData = st.waves.waves[0].enemies[0] if st.waves else st.spawn_table[0]
	var out: Array = []
	for i in n:
		var row := i / 2
		var at := player.global_position + Vector2((-1.0 if i % 2 == 0 else 1.0) * (18.0 + 10.0 * (row % 2)), -150.0 - row * 52.0)
		var e := spawner.spawn_at(d, at)
		if e:
			e.speed_mult = 0.0
			out.append(e)
	return out


func _cast(charge: float) -> void:
	player.facing = Vector2.UP
	caster.aim.active = true  # 위쪽으로 조준한 채 놓는다
	caster.aim.dir = Vector2.UP
	caster.reset_cooldown(SkillCaster.Slot.CHARGE)
	caster.cast(SkillCaster.Slot.CHARGE, charge)


func _horde_run(foes: Array, charge: float, n: int) -> void:
	var hp0 := 0
	for e in foes:
		hp0 += (e as Enemy).health.current
	var hits := [0, 0.0]
	for e in foes:
		(e as Enemy).health.damaged.connect(func(_a, _b, _c, _d, _e, _applied) -> void:
			hits[0] += 1
			hits[1] = Time.get_ticks_msec() / 1000.0)
	var t0 := Time.get_ticks_msec() / 1000.0
	_cast(charge)
	for i in 96:  # 1.6초
		await physics_frame
	var kills := 0
	var hp1 := 0
	for e in foes:
		if not is_instance_valid(e) or (e as Enemy).health.is_dead():
			kills += 1
		else:
			hp1 += (e as Enemy).health.current
	print("RAKE charge=%.2f n=%d kills=%d damage=%d hits=%d last_hit_s=%.2f" % [charge, n, kills, hp0 - hp1, hits[0],
		maxf(float(hits[1]) - t0, 0.0)])


func _strip(charge: float, out_path: String) -> void:
	var t0 := Time.get_ticks_msec() / 1000.0
	_cast(charge)
	var shots: Array[Image] = []
	for t in STRIP_TIMES:
		while Time.get_ticks_msec() / 1000.0 - t0 < t:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var vk := img.get_width() / 720.0
		shots.append(img.get_region(Rect2i(Vector2i(Vector2(CROP.position) * vk), Vector2i(Vector2(CROP.size) * vk))))
	var w := shots[0].get_width() / 2
	var h := shots[0].get_height() / 2
	var out := Image.create((w + 6) * 4, (h + 6) * 2, false, shots[0].get_format())
	out.fill(Color.WHITE)
	for i in shots.size():
		shots[i].resize(w, h)
		out.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i((i % 4) * (w + 6), (i / 4) * (h + 6)))
	out.save_png(out_path)
