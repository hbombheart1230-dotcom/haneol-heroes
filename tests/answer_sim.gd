class_name AnswerSim
extends HordeSim
## 정답 표 견본 재기 (docs/research/enemy_answers.md, tests/test_enemy_answers.gd): 한산 적 섞인 무리 하나를
## 봇 넷이 잡는 시간 (영웅은 죽지 않게 체력을 크게, 받은 피해는 damage로 따로). 모두 예고는 BossSim._dodge로 피하고, 자동 평타는 늘 돈다 (게임과 같게).
##   COMBO  : 가장 가까운 적에 붙어 탭 연타 (4타 마무리 포함)
##   DASH   : 내닫기만 (적 쪽으로 튕겨 닿으면 둘째 기술이 저절로, HordeSim._dash_bot)
##   CHARGE : 모아 치기만 (붙어서 다 모아 놓기, 쿨타임이면 서서 기다림)
##   MIX    : 가장 가까운 적의 정답 수로 (조총 = 내닫기, 무사 = 모아 치기, 사무라이 = 피하고 반격, 졸병 = 연타)

enum AnswerBot { COMBO, DASH, CHARGE, MIX }

## 섞인 무리: 졸병 6, 철포병 2, 무사 2, 사무라이 1 (한산 3·4 물결 비율).
const MIX_ROSTER := {"waegun_soldier": 6, "waegun_gunner": 2, "waegun_heavy": 2, "waegun_captain": 1}

var _hold_left: float = -1.0


## hp_mult: 체력 배율 (기본 판은 몇 초 만에 끝나 수의 차이가 안 보여서, 뒤 물결·성장 뒤 체력에 가깝게).
func spawn_mix(hp_mult: float = 3.0) -> void:
	var i := 0
	for id: String in MIX_ROSTER:
		var data := ResourceLoader.load("res://data/enemies/%s.tres" % id, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EnemyData
		for k in int(MIX_ROSTER[id]):
			var at := Vector2(-180 + (i % 4) * 120, -300 - (i / 4) * 90) + Vector2(randf_range(-30, 30), randf_range(-25, 25))
			var e := spawner.spawn_at(data, at)
			e.global_position = at
			e.target = player
			e.health.max = roundi(e.health.max * hp_mult)
			e.health.current = e.health.max
			i += 1


func run_answers(bot: AnswerBot, limit: float = 90.0) -> Dictionary:
	var res := {"time": limit, "cleared": false, "damage": 0, "counters": 0, "charges": 0, "by": {}, "strikes": 0}
	var tap_t := 0.0
	var t0 := _t
	_hold_left = -1.0
	player.health.max = 100000  # 죽지 않게: 잡는 빠르기만 비교하고, 받은 피해는 따로 센다
	player.health.current = player.health.max
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
		var want := _want(bot, near)
		if bot == AnswerBot.MIX and caster.is_counter_open():
			caster.cast(SkillCaster.Slot.COUNTER)
			res["counters"] += 1
		elif _hold_left >= 0.0:
			_hold(near, res)
		elif not _dodge(list):
			match want:
				EnemyAnswer.DASH:
					_dash_bot(near)
				EnemyAnswer.CHARGE:
					_walk_to(near, 120.0)
					if caster.is_ready(SkillCaster.Slot.CHARGE) and near.global_position.distance_to(player.global_position) <= 200.0:
						_hold_left = caster.kit.full_charge_time
				_:
					_walk_to(near, 70.0)
		player._physics_process(DT)
		caster.tick(DT, _t)
		tap_t -= DT
		if want == EnemyAnswer.COMBO and _hold_left < 0.0 and tap_t <= 0.0 \
				and near.global_position.distance_to(player.global_position) <= 140.0:
			tap_t = TAP_GAP
			caster.combo_tap()
		atk.tick(DT, list)
		_tick_shots(list)
		_tick_rakes()
		_tick_world(list, res)
	res["damage"] = player.health.max - player.health.current
	return res


## 이번 틱 봇이 쓰려는 수.
func _want(bot: AnswerBot, near: Enemy) -> String:
	match bot:
		AnswerBot.DASH:
			return EnemyAnswer.DASH
		AnswerBot.CHARGE:
			return EnemyAnswer.CHARGE
		AnswerBot.MIX:
			var a := EnemyAnswer.answer_of(near)
			if a == EnemyAnswer.CHARGE and not caster.is_ready(SkillCaster.Slot.CHARGE) and _hold_left < 0.0:
				return EnemyAnswer.COMBO  # 모아 치기 쿨타임이면 연타로 메운다
			if a == EnemyAnswer.DASH and not player.dash.can_consume():
				return EnemyAnswer.COMBO
			return EnemyAnswer.COMBO if a == EnemyAnswer.COUNTER or a == "" else a
	return EnemyAnswer.COMBO


## 모으는 중: 서서 적을 보고, 다 모으면 놓는다 (예고가 덮치면 모으기를 버리고 피한다).
func _hold(near: Enemy, res: Dictionary) -> void:
	player.set_move_input(Vector2.ZERO)
	if _dodge(enemies()):
		_hold_left = -1.0
		return
	var to := near.global_position - player.global_position
	if to.length_squared() > 1.0:
		player.facing = to.normalized()
	_hold_left -= DT
	if _hold_left < 0.0:
		caster.aim.active = false
		caster.cast(SkillCaster.Slot.CHARGE, 1.0)
		res["charges"] += 1
