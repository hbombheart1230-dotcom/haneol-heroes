extends SceneTree
## 한산 보스전 장면 찍기: 실제 main 장면 (순신 · 한산, 줌 1.09)에서 물결을 건너뛰고 왜군 지휘관을 세운 뒤
## 등장 → 예고(종류별) → 66% 전환 → 2단계 → 33% 전환 → 3단계 혼잡 → 처치 연출 → 승리 화면을 차례로 찍는다.
## 영웅은 무적으로 세워 두고(맞아서 끝나지 않게) 보스 체력은 코드로 깎는다.
## godot --path . --resolution 720x1280 -s res://tools/shots/boss_shot.gd -- <출력 폴더 절대 경로>

var out_dir := ""
var main: Node
var spawner: EnemySpawner
var player: Player
var boss: Enemy
var shots: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_settings.cfg"  # 사용자 설정을 건드리지 않게
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.stage_picked = true
	GameSettings.stage_id = &"hansan_1592"
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.tutorial_done = true
	GameSettings.tutorial_enabled = false
	GameSettings.hero_picked = true
	GameSettings.opening_seen = true
	GameSettings.story_enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	spawner = main.get_node("EnemySpawner") as EnemySpawner
	player = main.get_node("Player") as Player
	if spawner.waves:
		spawner.waves.phase = WaveRunner.Phase.BOSS  # 물결 건너뛰기
	await _wait(3.2)  # 무대 제목 띠가 사라질 때까지
	player.grant_invulnerability(999.0)
	boss = spawner.spawn_boss()
	boss.global_position = player.global_position + Vector2(40, -300)
	await _wait(0.9)
	await _shot("boss_1_intro")
	await _telegraphs(["cone", "charge"], 14.0)
	await _cut_to(0.64)
	await _wait(0.2)
	await _shot("boss_2_phase2_seal")
	await _wait(0.55)
	await _shot("boss_3_phase2_pick")
	_close_pick()
	await _wait(1.2)
	await _shot("boss_4_phase2_summon")
	await _telegraphs(["shockwave", "cone"], 14.0, "p2_")
	await _cut_to(0.31)
	_close_pick_later()
	await _wait(2.4)
	await _shot("boss_5_phase3_crowd")
	await _telegraphs(["charge", "shockwave"], 14.0, "p3_")
	while boss.phase_invuln > 0.0:
		await process_frame
	boss.health.damage(boss.health.current * 4)
	await _wait(0.25)
	await _shot("boss_6_finale_hit")
	await _wait(1.0)
	await _shot("boss_7_finale_banner")
	await _wait(2.0)
	await _shot("boss_8_victory")
	print("[boss-shot] saved ", shots)
	quit()


## 보스 체력을 frac까지 깎는다 (단계 전환이 일어난다). 전환 무적 중이면 끝날 때까지 기다린다.
func _cut_to(frac: float) -> void:
	while boss.phase_invuln > 0.0 or boss.attack.is_busy():
		await process_frame
	var target := int(boss.health.max * frac)
	var guard := 0
	while boss.health.current > target and guard < 200:
		boss.health.damage(maxi(int((boss.health.current - target) / maxf(boss.damage_mult(), 0.01)) + 1, 1))
		guard += 1
		await process_frame


func _close_pick() -> void:
	var sc := main.get("seal_choice") as SealChoice
	if sc and sc.is_open():
		sc.pick(0)


func _close_pick_later() -> void:
	await _wait(1.0)
	_close_pick()


## 예고 종류마다 예고가 60% 찬 순간을 한 장씩 (limit초 안에).
func _telegraphs(kinds: Array, limit: float, prefix: String = "") -> void:
	var names := {EnemyAttackData.Kind.CONE: "cone", EnemyAttackData.Kind.CHARGE: "charge", EnemyAttackData.Kind.SHOCKWAVE: "shockwave"}
	var want := kinds.duplicate()
	var end := Time.get_ticks_msec() + int(limit * 1000.0)
	while not want.is_empty() and Time.get_ticks_msec() < end:
		await process_frame
		_close_pick()
		var a := boss.attack
		if a.state != EnemyAttack.State.WINDUP or a.windup_ratio() < 0.6:
			continue
		var n: String = names.get(a.data.kind, "")
		if n in want:
			want.erase(n)
			await _shot("boss_tele_%s%s" % [prefix, n])
			while a.state == EnemyAttack.State.WINDUP:
				await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(name + ".png")
	root.get_texture().get_image().save_png(path)
	shots.append(name)


func _wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
