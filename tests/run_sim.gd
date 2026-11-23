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

## 전/후 비교: true면 무대 근접 잡몹 공격 시작 거리를 예전 130px로 (판마다 새로 읽은 데이터만 바꾼다).
static var legacy_reach := false
const REACH_IDS := ["chaser", "jurchen_soldier", "cc_mouse"]
var _alive_t := 0.0
var _dis_t := 0.0
var _starts := 0
var _strikes := 0
var _last := {}
## 묶인 까닭별 시간 (stagger, down, stun, launch, slow) — 무엇이 적을 못 움직이게 하는지.
var _why := {}
## 공격 거리 밖(trigger_range 너머)에 있던 시간.
var _far_t := 0.0
## 영웅 가까이(NEAR px 안)에 있던 잡몹: 그 시간과 그중 묶인 시간 (화면에서 보이는 "아무것도 못 하는 적").
const NEAR := 260.0
var _near_t := 0.0
var _near_dis := 0.0


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
	if legacy_reach:
		for w in stage_copy.waves.waves:
			for e: EnemyData in w.enemies:
				if REACH_IDS.has(String(e.id)) and e.attack:
					e.attack.trigger_range = 130.0
	await setup_stage(stage_copy, s)
	spawner.boss_data = BossHpScale.for_hero(stage_copy.boss, player.hero)
	spawner.elite_data = BossHpScale.for_hero(stage_copy.elite, player.hero)
	_alive_t = 0.0
	_dis_t = 0.0
	_starts = 0
	_strikes = 0
	_last.clear()
	_why.clear()
	_far_t = 0.0
	_near_t = 0.0
	_near_dis = 0.0


func _sample(list: Array) -> void:
	for e: Enemy in list:
		if e.data == null or e.data.is_boss or e.data.is_elite or e.data.boss_feel:
			continue
		_alive_t += DT
		var r := e.reaction
		var dis := (r and (r.is_staggered() or r.is_down())) or e.is_stunned() or e.launch.active()
		if dis:
			_dis_t += DT
		if e.global_position.distance_to(player.global_position) <= NEAR:
			_near_t += DT
			_near_dis += DT if dis else 0.0
		for k in ["stagger", "down", "stun", "launch", "slow"]:
			var on: bool = (k == "stagger" and r != null and r.is_staggered()) or (k == "down" and r != null and r.is_down()) 				or (k == "stun" and e.is_stunned()) or (k == "launch" and e.launch.active()) or (k == "slow" and e._slow_left > 0.0)
			if on:
				_why[k] = float(_why.get(k, 0.0)) + DT
		if e.attack and e.global_position.distance_to(player.global_position) > e.attack.data.trigger_range:
			_far_t += DT
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
	var why := {}
	for k in _why:
		why[k] = snappedf(_why[k] / maxf(_alive_t, 0.01), 0.01)
	why["far"] = snappedf(_far_t / maxf(_alive_t, 0.01), 0.01)
	out["near_disabled"] = _near_dis / maxf(_near_t, 0.01)
	out["why"] = why
	return out


## 결과 한 줄 (로그용).
static func run_line(name: String, r: Dictionary) -> String:
	return "[run-sim] %s: %s total %.1fs (waves %.1f, mid %.1f, boss %.1f), damage %d (waves %d), trash disabled %.0f%% (near %.0f%%), starts %.3f/s, strikes %.3f/s, why %s" % [
		name, "WIN" if r["won"] else ("LOSE" if r["lost"] else "TIMEOUT"), r["total"], r["wave_time"], r["mid_time"],
		r["boss_time"], r["damage"], r["wave_damage"], r["disabled"] * 100.0, r.get("near_disabled", 0.0) * 100.0, r["starts_per_s"], r["strikes_per_s"], str(r.get("why", {}))]
