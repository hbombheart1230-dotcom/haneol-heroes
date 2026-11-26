extends SceneTree
## 영웅 머리 위 대사(HeroLineView) 점검: 실제 main 장면을 실시간으로 돌리며 0.25초마다 대사 상태와
## 막는 까닭(blocked/allowed 쪼개서)을 찍고, 대사가 처음 그려지는 순간 화면을 찍는다.
## godot --path . --resolution 900x810 -s res://tools/shots/hero_line_probe.gd -- <hero> <stage|-> <seconds> <out_dir> [tutorial|boss|die|flow]
## 내보낸 판 점검: tools/는 pck에서 빠지므로 이 파일을 밖에 복사해 godot --main-pack <내보낸.pck> -s <복사본> -- ... 로 돌린다.

var main: Node
var out_dir := ""
var _shot_n := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var hero := StringName(a[0])
	var stage := a[1]
	var secs := float(a[2])
	out_dir = a[3]
	var tut := a.size() > 4 and a[4] == "tutorial"
	var mode := a[4] if a.size() > 4 else ""
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_line_settings.cfg"
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.opening_seen = true
	GameSettings.hero_picked = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.hero_id = hero
	GameSettings.stage_picked = stage != "-"
	if stage != "-":
		GameSettings.stage_id = StringName(stage)
	GameSettings.story_enabled = true
	GameSettings.tutorial_enabled = tut
	GameSettings.tutorial_done = not tut
	GameSettings.tutorial_seen_heroes = PackedStringArray() if tut else PackedStringArray([String(hero)])
	GameSettings.want_stage_list = mode == "flow"
	if mode == "flow":
		GameSettings.stage_picked = false
	GameSettings.save_settings()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	if mode == "flow":  # 실제 흐름: 전장 목록에서 고른다
		for i in 30:
			await process_frame
		print("[line] flow waiting_pick=%s view_lines=%s" % [main.waiting_pick, main.hero_lines.lines() if main.hero_lines else null])
		main.flow._on_stage_picked(StringName(stage if stage != "-" else String(main.run_stage_id())))
		for i in 5:
			await process_frame
		print("[line] flow after pick waiting_pick=%s" % main.waiting_pick)
	var p := main.get("player") as Player
	if p:
		p.grant_invulnerability(9999.0)
	var v: HeroLineView = main.hero_lines
	print("[line] hero=%s stage=%s run_stage=%s view=%s tut=%s" % [hero, stage, main.run_stage_id(), v != null, tut])
	var end := Time.get_ticks_msec() + int(secs * 1000.0)
	var next_log := 0
	var last_text := ""
	while Time.get_ticks_msec() < end:
		await process_frame
		var sc := main.get("seal_choice") as SealChoice
		if sc and sc.is_open() and Time.get_ticks_msec() % 1000 < 20:
			sc.pick(0)
		if v == null:
			continue
		await _drive(mode)
		if v.text != "" and v._left > 0.0 and v.text != last_text:
			last_text = v.text
			_log(v, "SAY")
			await _shot(v)
		if Time.get_ticks_msec() >= next_log:
			next_log = Time.get_ticks_msec() + 500
			_log(v, "")
	print("[line] done said=%s" % [v._said.keys() if v else []])
	quit()


var _boss: Enemy
var _t0 := -1


## boss: 6초 뒤 물결 건너뛰고 우두머리를 세운 뒤 5초 뒤부터 체력을 깎아 처치. die: 8초 뒤 영웅을 쓰러뜨린다.
func _drive(mode: String) -> void:
	if _t0 < 0:
		_t0 = Time.get_ticks_msec()
	var t := (Time.get_ticks_msec() - _t0) / 1000.0
	var sp := main.get("spawner") as EnemySpawner
	if mode == "boss" and _boss == null and t > 6.0:
		if sp.waves:
			sp.waves.phase = WaveRunner.Phase.BOSS
		_boss = sp.spawn_boss()
		_boss.global_position = main.player.global_position + Vector2(40, -300)
	if mode == "boss" and _boss != null and is_instance_valid(_boss) and t > 12.0 and not _boss.health.is_dead() and _boss.phase_invuln <= 0.0:
		_boss.health.damage(maxi(int(_boss.health.current / maxf(_boss.damage_mult(), 0.01)) + 1, 1))
	if mode == "tutorial" and t > 6.0 and main.tutorial_director and main.tutorial_director.running():
		main.tutorial_director.run.skip()  # 안내를 건너뛴 뒤 보통 판
	if mode == "die" and t > 8.0 and main.state.is_playing():
		var p: Player = main.player
		p.grant_invulnerability(0.0)
		p._skill_invuln = 0.0
		p.health.damage(99999)


func _log(v: HeroLineView, tag: String) -> void:
	var hud: Hud = main.hud
	var banner: Node = main.get_node_or_null("HUD/BossBanner")
	var tutr: bool = main.tutorial_director != null and main.tutorial_director.running()
	print("[line] %s t=%.1f playing=%s pick=%s choose=%s title=%.2f wave=%s boss_banner=%s tut=%s allowed=%s pend=%d clear=%.2f said=%s text='%s' left=%.2f vis=%s pos=%s size=%s" % [
		tag, main.state.elapsed, main.state.is_playing(), main.waiting_pick, main.is_choosing(),
		hud.stage_title_alpha(), hud.wave_banner_busy(), banner != null and banner.banner_visible(), tutr,
		v.allowed(), v._pending, v._clear, v._said.keys(), v.text, v._left, v.is_visible_in_tree(),
		v.line_pos() if v.text != "" else Vector2.ZERO, v.size])


func _shot(v: HeroLineView) -> void:
	await RenderingServer.frame_post_draw
	_shot_n += 1
	root.get_texture().get_image().save_png(out_dir.path_join("line_%d.png" % _shot_n))
