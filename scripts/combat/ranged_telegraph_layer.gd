class_name RangedTelegraphLayer
extends Node2D
## 원거리 예고를 전장(EnemySpawner) 한 층에서 모아 그린다 (VolleyFeelData.batch_telegraphs): 사수마다 획 세 개씩
## 그리기 호출이 들던 것을 InkBatch 하나로 (일제 사격 8~16명이 함께 예고해도 그리기 호출 하나).
## z는 TelegraphRim과 같은 절대 z (색 규칙 B: 기술 효과 위). 전장과 같은 좌표계.

const META := &"ranged_telegraph_layer"

var _b := InkBatch.new()
var _was := false
## 이번 프레임 예고 중인 사수 수 (재기·시험용).
var active: int = 0


## e의 예고를 이 층이 맡는지. 층이 없으면 e의 부모(전장)에 하나 붙인다 (붙는 프레임까지는 각자 그린다).
static func claim(e: Enemy) -> bool:
	if not VolleyFeelData.default().batch_telegraphs:
		return false
	var host := e.get_parent()
	if host == null or not (host is EnemySpawner):
		return false
	var l: Variant = host.get_meta(META) if host.has_meta(META) else null
	if l != null and is_instance_valid(l):
		return (l as Node).is_inside_tree()
	var layer := RangedTelegraphLayer.new()
	layer.name = "RangedTelegraphLayer"
	host.set_meta(META, layer)
	host.add_child.call_deferred(layer)
	return false


func _ready() -> void:
	z_as_relative = false
	z_index = Enemy.ai_data().telegraph_rim_z


func _process(_delta: float) -> void:
	var on := _count() > 0
	if on or _was:
		queue_redraw()  # 예고 중엔 매 프레임, 끝난 그 프레임에 한 번 더 (지우기)
	_was = on


static func _aiming(e: Enemy) -> bool:
	return e.attack != null and e.attack.state == EnemyAttack.State.WINDUP and e.attack.is_shoot() \
		and not e.is_queued_for_deletion()


func _count() -> int:
	var n := 0
	for c in get_parent().get_children():
		if c is Enemy and _aiming(c):
			n += 1
	return n


func _draw() -> void:
	active = _count()
	if active == 0:
		return
	var flash_t := Enemy.ai_data().strike_flash_time
	for c in get_parent().get_children():
		if c is Enemy and _aiming(c):
			var e := c as Enemy
			RangedTelegraph.paint(e, _b, to_local(e.global_position), e.attack.windup_ratio(), e.attack.is_flashing(flash_t), active)
	_b.flush(self)
