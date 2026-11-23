class_name RunSim
extends StageSim
## 한 판 전체 헤드리스 시뮬레이션 (tests/test_hero_difficulty_sim.gd): 무대 주인 영웅이 세 물결(중간 보스 포함)을 깨고
## 이어서 보스까지 — 체력은 이어진다. 결정성·조작은 StageSim·BossSim 그대로 (피하며 치기, miss_rate = 서툰 사람).
## 보스·중간 보스 체력은 게임처럼 영웅 배율(BossHpScale)을 받는다. 물결 상한은 caps로 바꿔 볼 수 있다 (잡몹 떼 크기).
## 잡몹(정예·보스 빼고)에 대해 매 틱 센다:
##   disabled  = 살아 있는 시간 중 경직·넘어짐·기절·날아가는 중인 비율 (스턴 가동률)
##   starts    = 공격 예고를 시작한 횟수 (적 1마리 1초당으로도), strikes = 예고를 끝까지 쳐낸 횟수
## 결과 사전: won, lost, total (판 길이), wave_time (보스 등장 시각), cleared, mid_time, boss_time,
## damage (판 전체), wave_damage, disabled, starts_per_s, strikes_per_s.

var _alive_t := 0.0
var _dis_t := 0.0
var _starts := 0
var _strikes := 0
var _last := {}


## 무대 꾸리기 (await 필요). caps가 비어 있지 않으면 물결별 상한을 바꾼다 (예: [8, 11, 14]).
func setup_run(st: StageTheme, s: int, caps: Array = []) -> void:
	var stage_copy := st
	if not caps.is_empty():
		stage_copy = st.duplicate() as StageTheme
		var ws := st.waves.duplicate() as WaveSetData
		var list: Array[WaveData] = []
		for i in ws.waves.size():
			var w := ws.waves[i].duplicate() as WaveData
			w.max_alive = caps[mini(i, caps.size() - 1)]
			w.first_count = maxi(w.first_count, w.max_alive)
			list.append(w)
		ws.waves = list
		ws.max_alive = maxi(ws.max_alive, caps.max())
		stage_copy.waves = ws
	await setup_stage(stage_copy, s)
	spawner.boss_data = BossHpScale.for_hero(stage_copy.boss, player.hero)
	spawner.elite_data = BossHpScale.for_hero(stage_copy.elite, player.hero)
	_alive_t = 0.0
	_dis_t = 0.0
	_starts = 0
	_strikes = 0
	_last.clear()


func _sample(list: Array) -> void:
	for e: Enemy in list:
		if e.data == null or e.data.is_boss or e.data.is_elite or e.data.boss_feel:
			continue
		_alive_t += DT
		var r := e.reaction
		if (r and (r.is_staggered() or r.is_down())) or e.is_stunned() or e.launch.active():
			_dis_t += DT
		var st: int = e.attack.state if e.attack else -1
		var was: int = _last.get(e, -1)
		if st == EnemyAttack.State.WINDUP and was != EnemyAttack.State.WINDUP:
			_starts += 1
		if st == EnemyAttack.State.RECOVER and was == EnemyAttack.State.WINDUP:
			_strikes += 1
		_last[e] = st


## 물결 → 보스까지 한 판. miss = 놓치는 예고 비율 (0.3 = 서툰 사람).
func run_full(miss: float = 0.0) -> Dictionary:
	miss_rate = miss
	var w := run_waves()
	var out := {"wave_time": w["time"], "cleared": w["cleared"], "mid_time": w["mid_time"],
		"wave_damage": w["damage"], "boss_time": 0.0, "won": false, "lost": w["lost"]}
	if w["boss"] and not player.is_dead():
		for c in spawner.get_children():
			if c is Enemy and (c as Enemy).data.is_boss:
				boss = c
		if boss:
			var b := run(Bot.DODGE, 200.0)
			out["boss_time"] = b["time"]
			out["won"] = b["won"]
			out["lost"] = b["lost"]
	out["total"] = snappedf(out["wave_time"] + out["boss_time"], 0.1)
	out["damage"] = player.health.max - player.health.current
	out["disabled"] = _dis_t / maxf(_alive_t, 0.01)
	out["starts_per_s"] = _starts / maxf(_alive_t, 0.01)
	out["strikes_per_s"] = _strikes / maxf(_alive_t, 0.01)
	return out


## 결과 한 줄 (로그용).
static func run_line(name: String, r: Dictionary) -> String:
	return "[run-sim] %s: %s total %.1fs (waves %.1f, mid %.1f, boss %.1f), damage %d (waves %d), trash disabled %.0f%%, starts %.3f/s, strikes %.3f/s, cleared %s" % [
		name, "WIN" if r["won"] else ("LOSE" if r["lost"] else "TIMEOUT"), r["total"], r["wave_time"], r["mid_time"],
		r["boss_time"], r["damage"], r["wave_damage"], r["disabled"] * 100.0, r["starts_per_s"], r["strikes_per_s"], str(r["cleared"])]
