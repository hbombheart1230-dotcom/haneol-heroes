class_name TutorialSparring
extends RefCounted
## 조작 안내의 연습 상대 (TutorialDirector에서 분리): 지금 단계에 practice_enemy가 있으면 플레이어 위쪽에
## 한 마리를 세운다. 쓰러지면 잠시 뒤 다시 나오고, 그런 단계가 끝나면(건너뛰어도) 치운다.
## 연습 상대는 잡몹이 아니다: 튼튼하고(체력이 반 밑으로 내려가면 다시 가득), 잡몹 수·체력 배율(많이·약하게 변형)을 받지 않고
## (is_practice 표시), 단계가 끝나 치울 때는 조용히 사라지지 않고 쓰러진다 (후련하게).
## 상대의 수치: 허수아비 data/tutorial/practice_dummy.tres (공격 없음), 회피 상대 practice_enemy.tres (피해 0 예고).

const PRACTICE_META := &"tutorial_practice"

var main: Node
var data: TutorialData
## 지금 서 있는 연습 상대 (없거나 쓰러졌으면 null).
var enemy: Enemy
var _wanted: EnemyData
var _respawn_left := 0.0
var _distance := 0.0


func _init(m: Node, d: TutorialData) -> void:
	main = m
	data = d


## 단계가 바뀔 때: 필요한 상대를 세우거나 치운다.
func sync(step: TutorialStep) -> void:
	var want: EnemyData = step.practice_enemy if step else null
	if want == null:
		clear()
		return
	_distance = step.practice_distance if step.practice_distance > 0.0 else data.practice_distance
	if want != _wanted or not _alive():
		_remove()
		_wanted = want
		_spawn()


## 물리 틱마다: 쓰러진 상대를 잠시 뒤 다시 세운다.
func tick(delta: float) -> void:
	if _alive():
		_keep_standing()
		return
	if _wanted == null:
		return
	_respawn_left -= delta
	if _respawn_left <= 0.0:
		_spawn()


func clear() -> void:
	_wanted = null
	_remove()


## 연습 상대 표시 (적 수·체력 배율을 곱하는 곳은 이 표시가 있으면 건너뛴다).
static func is_practice(e: Node) -> bool:
	return e != null and e.has_meta(PRACTICE_META)


## 체력이 refill 비율 아래로 내려가면 가득 채운다 (한 번에 그 이상 깎는 일이 없을 만큼 튼튼해서 쓰러질 일은 없다).
func _keep_standing() -> void:
	var h := enemy.health
	if h and not h.is_dead() and float(h.current) < float(h.max) * data.practice_refill_below:
		h.current = h.max


func _alive() -> bool:
	return enemy != null and is_instance_valid(enemy) and not enemy.is_queued_for_deletion()


func _spawn() -> void:
	var sp: EnemySpawner = main.spawner
	var player: Player = main.player
	if data == null or sp == null or player == null or _wanted == null:
		return
	_respawn_left = data.practice_respawn
	enemy = sp.spawn_at(_wanted, player.global_position + Vector2(0, -_distance), func(e: Enemy) -> void:
		e.hp_mult = 1.0  # 체력 배율 없음
		e.set_meta(PRACTICE_META, true))
	if enemy:
		enemy.killed.connect(_on_killed)


func _on_killed(e: Enemy) -> void:
	if e == enemy:
		enemy = null


func _remove() -> void:
	if _alive():
		if _wanted == null and enemy.data.attack != null and not enemy.health.is_dead():
			enemy.health.damage(enemy.health.max)  # 공격하던 상대는 단계를 마치면 쓰러진다
		else:
			enemy.queue_free()
	enemy = null
