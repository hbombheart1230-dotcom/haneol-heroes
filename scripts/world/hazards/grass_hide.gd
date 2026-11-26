class_name GrassHide
extends Node2D
## 풀숲 (초충도): 먹 풀포기로 그린 면. 영웅이 들어가 숨으면 잡몹·정예의 겨냥(target)을 들어간 자리의 미끼로 바꾼다
## (공격 중인 적은 그 공격을 끝낸 뒤) — 적 파일은 건드리지 않는다 (target이 영웅이 아니면 공격을 시작하지 않는다).
## 숨은 채로·나온 뒤 잠깐 친 첫 공격은 기습: 맞은 적 피해 알림(Health.damaged)에 덤 피해를 얹고 금빛 글자.
## 수치·그림·소리는 GrassData, 상태 계산은 GrassPlan.

var data: GrassData
var host: StageHazards
var state: GrassPlan.State
## 센 것 (시험·시뮬).
var hides: int = 0
var lost_aims: int = 0
var ambushes: int = 0
var ambush_damage: int = 0

var _decoy: Node2D
var _fooled: Array[Enemy] = []
var _hooked := {}
var _dealing: bool = false
var _spent_frame: int = -1
## 이 노드의 틀 번호 (시뮬은 한 엔진 틀 안에서 손으로 굴려 Engine 틀 번호가 안 바뀐다).
var _frame: int = 0
var _t: float = 0.0


func _init(d: GrassData) -> void:
	data = d
	state = GrassPlan.State.new(d)


func _ready() -> void:
	_decoy = Node2D.new()
	add_child(_decoy)
	queue_redraw()


func report() -> Dictionary:
	return {"grass_hides": hides, "grass_lost_aims": lost_aims, "grass_ambushes": ambushes, "grass_ambush_damage": ambush_damage}


func _physics_process(delta: float) -> void:
	_t += delta
	_frame += 1
	var p := host.player if host else null
	if p == null or not is_instance_valid(p):
		return
	var was_hidden := state.hidden()
	var change := state.step(delta, GrassPlan.inside(data.patches, p.global_position) >= 0)
	if change != 0:
		_play(data.rustle_sfx)
	if state.hidden() and not was_hidden:
		hides += 1
		_decoy.global_position = p.global_position  # 마지막으로 본 자리
	if _spent_frame >= 0 and _frame != _spent_frame:
		_spent_frame = -1
		state.spend()
	for e in host.enemies():
		var en := e as Enemy
		if en and is_instance_valid(en) and not _hooked.has(en.get_instance_id()) and en.health:
			_hooked[en.get_instance_id()] = true
			en.health.damaged.connect(_on_enemy_damaged.bind(en))
		if state.hidden():
			_fool(en, p)
	if not state.hidden():
		_restore(p)
	var view := p.get_node_or_null("PlayerView") as CanvasItem
	if view:
		view.modulate.a = data.hidden_alpha if state.hidden() else 1.0
	queue_redraw()


func _fool(en: Enemy, p: Player) -> void:
	if en == null or not is_instance_valid(en) or en.target != p or en.is_in_group(Enemy.BOSS_GROUP):
		return
	if en.global_position.distance_to(p.global_position) <= data.sense_range:
		return
	if en.attack and en.attack.state != EnemyAttack.State.READY:
		return  # 하던 공격은 끝낸다
	en.target = _decoy
	_fooled.append(en)
	lost_aims += 1


func _restore(p: Player) -> void:
	for en in _fooled:
		if is_instance_valid(en) and en.target == _decoy:
			en.target = p
	_fooled.clear()


func _on_enemy_damaged(_ent: Node, _type: int, amount: int, _inc: int, _mul: float, applied: int, en: Enemy) -> void:
	if _dealing or applied <= 0 or not is_instance_valid(en):
		return
	var frame := _frame
	if not state.ambush_ready() and _spent_frame != frame:
		return
	var extra := GrassPlan.ambush_extra(amount, data.ambush_mult)
	if extra > 0 and en.health.is_alive():  # 이미 쓰러졌으면 덤은 없고 기습만 센다
		_dealing = true
		FxLayer.tag_last_number(en.get_instance_id(), en.global_position)
		FxLayer.stack_key = en.get_instance_id()  # 덤 피해는 방금 뜬 숫자에 쌓는다
		en.health.damage(extra)
		FxLayer.stack_key = 0
		_dealing = false
		ambush_damage += extra
	if _spent_frame != frame:  # 같은 틀에 맞은 적은 모두 기습 (한 번 휘두름)
		_spent_frame = frame
		ambushes += 1
		_play(data.ambush_sfx)
		if Feedback.instance and Feedback.instance.fx:
			Feedback.instance.fx.add_label(en.global_position + Vector2(0, -90), data.ambush_word, data.ambush_color)


func _play(kind: StringName) -> void:
	if kind != &"" and Feedback.instance:
		Feedback.instance.play(kind, 0.1)


## 풀숲 덩어리·풀잎을 모아 한 번에 그린다 (모양·색은 Ink.blob·Ink.stroke 그대로).
var _batch := InkBatch.new()


func _draw() -> void:
	var view := host.view_rect().grow(200.0) if host else Rect2(-1e6, -1e6, 2e6, 2e6)
	var hero := host.player.global_position if host and host.player else Vector2.INF
	for i in data.patches.size():
		var c := Vector2(data.patches[i].x, data.patches[i].y)
		var r := data.patches[i].z
		if not view.intersects(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)):
			continue
		_batch.blob(c, r, Color(data.grass_color, 0.22), i, 0.18, 0.62)
		var n := int(data.blades_per_100 * r / 100.0 * r / 100.0 * 3.0)
		var stir := 1.0 if hero.distance_to(c) <= r + 30.0 else 0.25
		for k in n:
			var a := k * 2.39996 + i
			var d := sqrt(float(k) / n) * r * 0.92
			var base := c + Vector2(cos(a) * d, sin(a) * d * 0.62)
			var sway := sin(_t * (3.0 + stir * 4.0) + k) * (3.0 + 7.0 * stir)
			var h := 38.0 + 22.0 * absf(sin(k * 1.7 + i))
			var col := data.grass_light if k % 3 == 0 else data.grass_color
			_batch.stroke(base, base + Vector2(sway + sin(k * 3.1) * 8.0, -h), 7.0, col)
	_batch.flush(self)  # 한 번에 (InkBatch: 풀잎마다 그리기 호출이던 것)
