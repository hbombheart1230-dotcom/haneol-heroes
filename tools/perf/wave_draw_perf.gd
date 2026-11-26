extends SceneTree
## 물결별 그리기 호출·동시 적 수 (실제 main 장면, 판 처음부터 우두머리 전까지): 영웅 무적, 가장 가까운 적 쪽으로 걸으며 탭 연타,
## 강화는 첫 패. 대형을 늘린 물결이 폰에서 무거워지는지 본다.
## godot --path . --resolution 720x1280 -s res://tools/perf/wave_draw_perf.gd -- <무대 id> <영웅 id> [최대 초]
## 결과 줄: WAVEDRAW w<n> secs <초> draws_max <n> draws_avg <n> enemies_max <n> formations_max <n>

var main: Node
var spawner: EnemySpawner
var player: Player
var caster: SkillCaster
var _stats := {}  # 물결 이름 → [프레임, 그리기 합, 그리기 최대, 적 최대, 대형 최대, 시작 시각, 끝 시각]


func _initialize() -> void:
	_run()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var secs := float(a[2]) if a.size() > 2 else 420.0
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_settings_%d.cfg" % OS.get_process_id()  # 실행마다 따로
	ShotStage.skip_menus(StringName(a[0]), StringName(a[1]))
	GameSettings.save_settings(GameSettings.settings_path)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	spawner = main.get_node("EnemySpawner") as EnemySpawner
	player = main.get_node("Player") as Player
	caster = player.get_node_or_null("SkillCaster") as SkillCaster
	var seal := main.get("seal_choice") as SealChoice
	player.grant_invulnerability(99999.0)
	var t0 := Time.get_ticks_msec()
	var tap := 0.0
	while (Time.get_ticks_msec() - t0) / 1000.0 < secs:
		await process_frame
		if seal and seal.is_open():
			seal.pick(0)
			continue
		var w := spawner.waves
		if w == null or w.phase == WaveRunner.Phase.BOSS or w.phase == WaveRunner.Phase.BOSS_WAIT:
			break
		tap -= 1.0 / 60.0
		if caster and tap <= 0.0:
			tap = 0.2
			caster.combo_tap()
		_hop_if_waiting()
		_walk()
		if w.phase == WaveRunner.Phase.RUN:
			_add("w%d" % (w.index + 1), (Time.get_ticks_msec() - t0) / 1000.0)
	for k in _stats:
		var s: Array = _stats[k]
		print("WAVEDRAW %s secs %.1f draws_max %d draws_avg %d enemies_max %d formations_max %d" % [k, s[6] - s[5], s[2], roundi(s[1] / maxf(s[0], 1)), s[3], s[4]])
	quit()


func _add(k: String, t: float) -> void:
	if not _stats.has(k):
		_stats[k] = [0, 0.0, 0, 0, 0, t, t]
	var s: Array = _stats[k]
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var alive := 0
	for c in spawner.get_children():
		if c is Enemy and not (c as Enemy).health.is_dead():
			alive += 1
	s[0] += 1
	s[1] += draws
	s[2] = maxi(s[2], draws)
	s[3] = maxi(s[3], alive)
	s[4] = maxi(s[4], spawner.formations.size())
	s[6] = t


## 가장 가까운 적이 멀면 그쪽으로 조금 (서툰 사람처럼 붙어 싸운다).
func _walk() -> void:
	var best: Enemy = null
	var bd := INF
	for c in spawner.get_children():
		if c is Enemy and not (c as Enemy).health.is_dead():
			var d := player.global_position.distance_to((c as Enemy).global_position)
			if d < bd:
				bd = d
				best = c
	if best and bd > 140.0:
		player.global_position += (best.global_position - player.global_position).normalized() * 4.0


## 구역 건너뛰기 (ZoneHop): 화살을 기다리면 가까운 난간 자리 아래로 옮겨 그쪽으로 내닫는다.
var _hop_wait := 0.0
func _hop_if_waiting() -> void:
	var zh := main.find_children("*", "ZoneHop", true, false)
	if zh.is_empty() or (zh[0] as ZoneHop).state != ZoneHop.State.AWAIT:
		_hop_wait = 0.0
		return
	_hop_wait += 1.0 / 60.0
	if _hop_wait < 1.0 or player.is_dashing():
		return
	var z := zh[0] as ZoneHop
	var rail := z.plan.nearest_exit(player.global_position)
	if rail != Vector2.INF:
		ShotStage.move_hero(main, rail + Vector2(0, 240))
	player.request_dash((rail - player.global_position).normalized() if rail != Vector2.INF else z.plan.zone().exit_dir)
	_hop_wait = 0.0

