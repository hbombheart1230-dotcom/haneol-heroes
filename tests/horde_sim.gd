class_name HordeSim
extends BossSim
## 잡몹 떼 시뮬레이션 (대시 방향 나누기 재고, tests/test_dash_direction.gd): 왜군 병사 n마리가 앞쪽 무리로 오고,
## 봇 둘을 같은 씨앗으로 비교한다. 둘 다 예고는 BossSim._dodge로 피한다 (회피 무적이 나는 길은 같게).
##   MELEE : 가장 가까운 적에게 붙어 탭 연타 (지금 정답)
##   DASH  : 탭 없이 돌진 대시만 (충전이 있고 연속이 아니면 가장 가까운 적 쪽으로, 아니면 다가감)
## 결과: time(다 잡은 시각, 못 잡으면 limit), cleared, damage, evades(회피 성공 수), invuln(회피 무적이 켜진 시간 비율), strikes(돌진 타격 수).

enum HordeBot { MELEE, DASH }

const SOLDIER_PATH := "res://data/enemies/waegun_soldier.tres"


## 앞쪽(위) 무리로 n마리. hp_mult: 체력 배율 (판이 몇 초 안에 끝나면 차이가 안 보여서, 뒤 무대·성장 뒤 체력에 가깝게).
func spawn_horde(n: int, hp_mult: float = 1.0) -> void:
	var data := ResourceLoader.load(SOLDIER_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EnemyData
	for i in n:
		var at := Vector2(-150 + (i % 5) * 75, -320 - (i / 5) * 70) + Vector2(randf_range(-30, 30), randf_range(-25, 25))  # 씨앗마다 다른 무리
		var e := spawner.spawn_at(data, at)
		e.global_position = at
		e.target = player
		e.health.max = roundi(e.health.max * hp_mult)
		e.health.current = e.health.max


func run_horde(bot: HordeBot, limit: float = 60.0) -> Dictionary:
	var res := {"time": limit, "cleared": false, "damage": 0, "evades": 0, "invuln": 0.0, "strikes": 0, "by": {}}
	var evades := [0]
	player.evaded.connect(func() -> void: evades[0] += 1)
	var tap_t := 0.0
	var inv := 0.0
	var t0 := _t
	while _t - t0 < limit and not player.is_dead():
		_t += DT
		Engine.time_scale = 1.0
		for c in spawner.get_children():
			c.set_physics_process(false)
		var list := enemies()
		if list.is_empty():
			res["cleared"] = true
			res["time"] = snappedf(_t - t0, 0.1)
			break
		var near := _nearest(list)
		if not _dodge(list):
			if bot == HordeBot.DASH:
				_dash_bot(near)
			else:
				_walk_to(near, 70.0)
		var struck_before := _struck()
		player._physics_process(DT)
		res["strikes"] += maxi(_struck() - struck_before, 0)
		caster.tick(DT, _t)
		tap_t -= DT
		if bot == HordeBot.MELEE and tap_t <= 0.0 and near.global_position.distance_to(player.global_position) <= 140.0:
			tap_t = TAP_GAP
			caster.combo_tap()
		atk.tick(DT, list)
		_tick_shots(list)
		_tick_rakes()  # 기술 박자 타격 (WaveRake): 손으로 굴려 물리 틱이 돌지 않는다 (BossSim과 같이)
		_tick_world(list, res)
		if player.skill_invuln_left() > 0.0:
			inv += DT
	res["damage"] = player.health.max - player.health.current
	res["evades"] = evades[0]
	res["invuln"] = snappedf(inv / maxf(_t - t0, 0.001), 0.01)
	return res


## 이번 대시에 돌진 타격으로 친 적 수 (대시 방향 나누기가 없으면 0).
func _struck() -> int:
	var s: Variant = player.get("dash_struck")
	return (s as Dictionary).size() if s is Dictionary else 0


func _nearest(list: Array) -> Enemy:
	var best: Enemy = list[0]
	for e in list:
		if e.global_position.distance_squared_to(player.global_position) < best.global_position.distance_squared_to(player.global_position):
			best = e
	return best


func _walk_to(e: Enemy, stop: float) -> void:
	var to := e.global_position - player.global_position
	player.set_move_input(to.normalized() if to.length() > stop else Vector2.ZERO)
	if to.length() <= stop:
		player.facing = to.normalized()


## 돌진만: 대시를 쓸 수 있고 연속이 아니면 (타격이 나는 대시) 적 쪽으로, 아니면 다가감.
func _dash_bot(e: Enemy) -> void:
	var d: Variant = player.hero.get("dash_dir")  # 대시 방향 나누기가 없는 가지에서도 돈다
	var to := e.global_position - player.global_position
	var fresh: bool = d == null or player._since_dash_end >= float(d.chain_gap)
	if not player.is_dashing() and fresh and player.dash.can_consume() and to.length() <= 380.0:
		player.request_dash(to.normalized())
	else:
		_walk_to(e, 60.0)


static func horde_line(name: String, r: Dictionary) -> String:
	return "[horde-sim] %s: %s %.1fs, damage %d, evades %d, invuln %.0f%%, dash strikes %d, by %s" % [
		name, "CLEAR" if r["cleared"] else "NOT CLEARED", r["time"], r["damage"], r["evades"],
		r["invuln"] * 100.0, r["strikes"], str(r["by"])]
