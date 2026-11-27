class_name BossCalls
extends RefCounted
## 우두머리·중간 우두머리가 그 전장의 원거리 대형을 부른다 (WaveSetData.call_formation, 막판 긴장감):
## 우두머리는 체력 boss_call_hp 문턱마다 boss_call_count 묶음 (여러 묶음은 FormationSpawn이 반대쪽에 세우고 겨눔이 엇갈린다),
## 중간 우두머리 셋은 하나가 쓰러질 때마다 (남은 셋이 있으면) mid_calls까지. 동시 상한에 대형 몫이 없으면 1초 뒤 다시.

const RETRY := 1.0
const TRIES := 6


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
	while done < ws.boss_call_hp.size() and frac <= ws.boss_call_hp[done]:
		call_out(sp, ws, ws.boss_call_count[done] if done < ws.boss_call_count.size() else 1, e)
		done += 1
	e.set_meta(&"boss_calls", done)


## 적이 쓰러짐 (생성기): 중간 우두머리 셋 가운데 하나면 (남은 셋이 있을 때) 한 번.
static func on_killed(e: Enemy, sp: EnemySpawner) -> void:
	if e.data == null or e.data.is_boss or e.data.boss_feel == null:
		return
	var ws := _waves_of(sp)
	if ws == null or ws.call_formation == null:
		return
	var done := int(sp.get_meta(&"mid_calls", 0))
	var others := sp.get_children().filter(func(n: Node) -> bool:
		return n != e and n is Enemy and (n as Enemy).data and (n as Enemy).data.boss_feel != null and not (n as Enemy).data.is_boss and not (n as Enemy).health.is_dead())
	if done >= ws.mid_calls or others.is_empty():
		return
	sp.set_meta(&"mid_calls", done + 1)
	call_out(sp, ws, 1, others[0])


## 대형 n묶음을 부른다: 외침·북·흔들림, 자리가 나는 대로 하나씩.
static func call_out(sp: EnemySpawner, ws: WaveSetData, n: int, caller: Enemy) -> void:
	var fb := Feedback.instance
	if fb:
		fb.play(&"gugak_kill", 0.0)  # 북 (파일이 있을 때만)
		fb.add_trauma(fb.feel.poise_trauma * 0.6)
		if fb.fx and ws.call_label != "" and is_instance_valid(caller):
			fb.fx.add_label(caller.global_position + Vector2(0, -caller.body_radius * caller.size_mult * 2.4), ws.call_label, Ink.SEAL)
	for k in n:
		_try(sp, ws.call_formation, TRIES)


static func _try(sp: EnemySpawner, f: FormationData, left: int) -> void:
	if not is_instance_valid(sp) or not sp.active or sp.target == null:
		return
	var cap := sp.max_alive + (sp.waves.data.alive_cap_add if sp.waves else 0)
	if sp.alive_count() + f.count <= cap:
		FormationSpawn.spawn(sp, f)
	elif left > 1 and sp.is_inside_tree():
		sp.get_tree().create_timer(RETRY).timeout.connect(func() -> void: _try(sp, f, left - 1))


static func _waves_of(sp: EnemySpawner) -> WaveSetData:
	return sp.waves.data if sp and sp.waves else null
