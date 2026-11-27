class_name BossCalls
extends RefCounted
## 우두머리·중간 우두머리가 그 전장의 원거리 대형을 부른다 (WaveSetData.call_formation, 막판 긴장감):
## 우두머리는 체력 boss_call_hp 문턱마다 boss_call_count 묶음 (한 번에 여러 문턱을 넘으면 마지막 문턱 몫만),
## 중간 우두머리 셋은 하나가 쓰러질 때마다 (남은 셋이 있으면) mid_calls까지.
## 부르기는 판이 돌고 있고·처치 연출이 아니고·강화 고르기 중이 아니고·부른 쪽이 살아 있고 (우두머리는 단계 전환 무적이 아닐 때)
## 동시 상한에 대형 몫이 있을 때 나온다. 아니면 call_retry초 뒤 다시 (call_tries번까지, 매번 다시 확인).


## 맞은 뒤 (Enemy, 살아 있을 때): 우두머리 체력 문턱을 넘었으면 부른다.
static func on_damaged(e: Enemy) -> void:
	if e.data == null or not e.data.is_boss:
		return
	var sp := e.get_parent() as EnemySpawner
	var ws := _waves_of(sp)
	if ws == null or ws.call_formation == null:
		return
	var frac := float(e.health.current) / maxf(e.health.max, 1)
	var done := int(e.get_meta(&"boss_calls", 0))
	var n := 0
	while done < ws.boss_call_hp.size() and frac <= ws.boss_call_hp[done]:
		n = ws.boss_call_count[done] if done < ws.boss_call_count.size() else 1  # 여러 문턱을 한 번에 넘으면 마지막 몫만
		done += 1
	e.set_meta(&"boss_calls", done)
	if n > 0:
		call_out(sp, ws, n, func() -> Enemy: return e if is_instance_valid(e) and not e.health.is_dead() else null)


## 적이 쓰러짐 (생성기): 중간 우두머리 셋 가운데 하나면 (남은 셋이 있을 때) 한 번.
static func on_killed(e: Enemy, sp: EnemySpawner) -> void:
	if e.data == null or e.data.is_boss or e.data.boss_feel == null:
		return
	var ws := _waves_of(sp)
	if ws == null or ws.call_formation == null:
		return
	var done := int(sp.get_meta(&"mid_calls", 0))
	if done >= ws.mid_calls or _mid_alive(sp) == null:
		return
	sp.set_meta(&"mid_calls", done + 1)
	call_out(sp, ws, 1, func() -> Enemy: return _mid_alive(sp))  # 다시 시도 때도 남은 중간 우두머리가 있어야


## 대형 n묶음을 부른다: caller()가 살아 있는 부른 이를 돌려줄 때만. 첫 묶음이 나올 때 외침·북·흔들림.
static func call_out(sp: EnemySpawner, ws: WaveSetData, n: int, caller: Callable) -> void:
	var state := {"shouted": false}
	for k in n:
		_try(sp, ws, caller, state, ws.call_tries)


static func _try(sp: EnemySpawner, ws: WaveSetData, caller: Callable, state: Dictionary, left: int) -> void:
	if not is_instance_valid(sp) or not sp.is_inside_tree():
		return
	var who: Enemy = caller.call()
	if who == null or not sp.active or _player_down(sp):  # 부른 이가 없거나 판이 끝났으면 대기 부르기도 버린다
		return
	var cap := sp.max_alive + (sp.waves.data.alive_cap_add if sp.waves else 0)
	if who.phase_invuln <= 0.0 and not sp.finale_playing() and not _choosing(sp) and sp.alive_count() + ws.call_formation.count <= cap:
		if not state.shouted:
			state.shouted = true
			_shout(ws, who)
		FormationSpawn.spawn(sp, ws.call_formation)
	elif left > 1:
		sp.get_tree().create_timer(ws.call_retry, false).timeout.connect(func() -> void: _try(sp, ws, caller, state, left - 1))


static func _shout(ws: WaveSetData, who: Enemy) -> void:
	var fb := Feedback.instance
	if fb == null:
		return
	fb.play(&"gugak_kill", 0.0)  # 북 (파일이 있을 때만)
	fb.add_trauma(fb.feel.poise_trauma * 0.6)
	if fb.fx and ws.call_label != "":
		fb.fx.add_label(who.global_position + Vector2(0, -who.body_radius * who.size_mult * 2.4), ws.call_label, Ink.SEAL)


static func _mid_alive(sp: EnemySpawner) -> Enemy:
	if not is_instance_valid(sp):
		return null
	for n in sp.get_children():
		var m := n as Enemy
		if m and m.data and m.data.boss_feel != null and not m.data.is_boss and m.health and not m.health.is_dead():
			return m
	return null


static func _player_down(sp: EnemySpawner) -> bool:
	return sp.target == null or not is_instance_valid(sp.target) or (sp.target is Player and (sp.target as Player).is_dead())


static func _choosing(sp: EnemySpawner) -> bool:
	var main := sp.get_parent()
	return main != null and main.has_method("is_choosing") and main.is_choosing()


static func _waves_of(sp: EnemySpawner) -> WaveSetData:
	return sp.waves.data if sp and sp.waves else null
