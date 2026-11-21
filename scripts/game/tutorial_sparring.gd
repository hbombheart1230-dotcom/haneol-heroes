class_name TutorialSparring
extends RefCounted
## 조작 안내의 연습 상대 (TutorialDirector에서 분리): 지금 단계에 practice_enemy가 있으면 플레이어 위쪽에
## 한 마리를 세운다. 쓰러지면 잠시 뒤 다시 나오고, 그런 단계가 끝나면(건너뛰어도) 치운다.
## 상대의 수치(피해 0 예고 공격, 경험치 0)는 data/tutorial/practice_enemy.tres.

var main: Node
var data: TutorialData
## 지금 서 있는 연습 상대 (없거나 쓰러졌으면 null).
var enemy: Enemy
var _wanted: EnemyData
var _respawn_left := 0.0


func _init(m: Node, d: TutorialData) -> void:
	main = m
	data = d


## 단계가 바뀔 때: 필요한 상대를 세우거나 치운다.
func sync(step: TutorialStep) -> void:
	var want: EnemyData = step.practice_enemy if step else null
	if want == null:
		clear()
		return
	if want != _wanted or not _alive():
		_remove()
		_wanted = want
		_spawn()


## 물리 틱마다: 쓰러진 상대를 잠시 뒤 다시 세운다.
func tick(delta: float) -> void:
	if _wanted == null or _alive():
		return
	_respawn_left -= delta
	if _respawn_left <= 0.0:
		_spawn()


func clear() -> void:
	_wanted = null
	_remove()


func _alive() -> bool:
	return enemy != null and is_instance_valid(enemy) and not enemy.is_queued_for_deletion()


func _spawn() -> void:
	_respawn_left = data.practice_respawn if data else 1.0
	var sp: EnemySpawner = main.spawner
	var player: Player = main.player
	if sp == null or player == null or _wanted == null:
		return
	enemy = sp.spawn_at(_wanted, player.global_position + Vector2(0, -(data.practice_distance if data else 240.0)))
	if enemy:
		enemy.killed.connect(_on_killed)


func _on_killed(e: Enemy) -> void:
	if e == enemy:
		enemy = null


func _remove() -> void:
	if _alive():
		enemy.queue_free()
	enemy = null
