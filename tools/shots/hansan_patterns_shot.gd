extends SceneTree
## 한산 우두머리 새 패턴 화면 (build/preview/hansan_*.png): 군기 꽂기 + 먹물 장판, 격노 3연 돌진 예고, 중간 우두머리 무리.
## godot --path . --resolution 720x1280 -s res://tools/shots/hansan_patterns_shot.gd -- <출력 폴더 절대 경로>

var main: Node
var spawner: EnemySpawner
var player: Player
var out_dir := ""
var shots: Array[String] = []


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
	await _wait(3.2)
	player.grant_invulnerability(999.0)
	# 1. 중간 우두머리 무리 (3물결 자리): 셋이 한꺼번에, 동시 예고 최대 둘
	var group: Array = (spawner.waves.data.waves[2] as WaveData).elite_group
	var mids: Array = []
	for i in group.size():
		mids.append(spawner.spawn_elite(player.global_position + Vector2(-200 + 200 * i, -260), group[i]))
	await _wait(1.0)
	await _shot("hansan_trio_intro")
	await _wait(2.6)  # 등장 띠가 빠질 때까지
	await _until(func() -> bool:
		return mids.filter(func(m: Enemy) -> bool: return is_instance_valid(m) and m.attack and m.attack.state == EnemyAttack.State.WINDUP).size() >= 2, 8.0)
	await _shot("hansan_trio_two_windups")
	for m in mids:
		if is_instance_valid(m):
			(m as Enemy).health.kill()
	await _wait(2.0)
	await _close_picks()
	# 2. 대장: 66% → 군기 꽂기 + 먹물 장판
	var boss := spawner.spawn_boss()
	boss.global_position = player.global_position + Vector2(40, -300)
	await _wait(2.6)
	await _cut_to(boss, 0.64)
	await _wait(0.8)
	await _close_picks()
	await _wait(1.4)
	var flag_atk: EnemyAttackData = null
	for a: EnemyAttackData in (boss.data.phases[0] as BossPhaseData).patterns:
		if a.spawn_on_strike:
			flag_atk = a
	boss.attack.data = flag_atk
	await _until(func() -> bool: return boss.attack.state == EnemyAttack.State.WINDUP, 6.0)
	await _wait(0.5)
	await _shot("hansan_flag_windup")
	await _until(func() -> bool: return boss.attack.state == EnemyAttack.State.RECOVER, 3.0)
	await _wait(0.4)
	await _shot("hansan_flag_field")
	# 3. 33% 격노: 3연 돌진 예고
	await _cut_to(boss, 0.31)
	await _wait(0.8)
	await _close_picks()
	await _wait(1.4)
	for a: EnemyAttackData in (boss.data.phases[1] as BossPhaseData).patterns:
		if a.chain_repeat:
			boss.attack.data = a
	await _until(func() -> bool: return boss.attack.state == EnemyAttack.State.WINDUP, 6.0)
	await _wait(0.45)
	await _shot("hansan_rage_charge_1")
	await _until(func() -> bool: return boss.attack.state == EnemyAttack.State.WINDUP and boss.attack.data.follow_up != null and boss.attack.data.follow_up.follow_up == null, 4.0)
	await _wait(0.4)
	await _shot("hansan_rage_charge_2")
	print("[hansan-shot] saved ", shots)
	quit()


## 보스 체력을 frac까지 (전환 무적·공격 중이면 기다림, 받는 피해 배율을 거슬러).
func _cut_to(boss: Enemy, frac: float) -> void:
	while boss.phase_invuln > 0.0 or boss.attack.is_busy():
		await process_frame
	var target := int(boss.health.max * frac)
	var guard := 0
	while boss.health.current > target and guard < 200:
		boss.health.damage(maxi(int((boss.health.current - target) / maxf(boss.damage_mult(), 0.01)) + 1, 1))
		guard += 1
		await process_frame


## 열린 강화 고르기를 모두 닫는다 (첫 장).
func _close_picks() -> void:
	var sc := main.get("seal_choice") as SealChoice
	var guard := 0
	while sc and guard < 10:
		if sc.is_open():
			sc.pick(0)
		await _wait(0.3)
		guard += 1
		if not sc.is_open():
			break


func _until(cond: Callable, limit: float) -> void:
	var t := 0.0
	while t < limit and not bool(cond.call()):
		await process_frame
		t += 1.0 / 60.0


func _shot(name: String) -> void:
	await process_frame
	var path := out_dir.path_join(name + ".png")
	root.get_texture().get_image().save_png(path)
	shots.append(name)


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout
