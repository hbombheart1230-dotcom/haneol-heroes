class_name StageHazards
extends Node2D
## 무대 장치들을 담는 노드 (Arena 자식이라 바닥 위·적 아래에 그려진다). 무대마다 StageTheme.hazards로 다시 만든다.
## 장치 노드는 host(이 노드)에게 영웅·적·박자가 흐르는지를 묻는다. 장치가 없는 무대는 자식이 없어 아무것도 안 한다.

var player: Player
var spawner: EnemySpawner
## 박자가 흐를 수 있는 판 상태인가 (Main이 넣는다: 판 진행 중, 강화 고르기·길잡이 아님). 비면 늘 참 (도구·시험).
var running_check: Callable


func setup(list: Array[StageHazardData]) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	for d in list:
		var n := d.make() if d else null
		if n:
			n.set(&"host", self)
			add_child(n)


func hazard_count() -> int:
	return get_child_count()


## 박자가 흐르는가: 판 상태가 되고, 물결 모드면 물결 싸움(RUN)이나 우두머리전(BOSS)일 때만
## (숨 고르기 GAP·우두머리 등장 BOSS_WAIT에는 멈춤).
func running() -> bool:
	if running_check.is_valid() and not running_check.call():
		return false
	if player == null or not is_instance_valid(player) or player.is_dead():
		return false
	if spawner and spawner.waves:
		var ph := spawner.waves.phase
		return ph == WaveRunner.Phase.RUN or ph == WaveRunner.Phase.BOSS
	return true


func boss() -> bool:
	if spawner and spawner.waves:
		return spawner.waves.phase == WaveRunner.Phase.BOSS
	return is_inside_tree() and not get_tree().get_nodes_in_group(Enemy.BOSS_GROUP).is_empty()


func enemies() -> Array:
	return get_tree().get_nodes_in_group(Enemy.GROUP) if is_inside_tree() else []


## 지금 화면에 보이는 월드 영역. 카메라가 없으면 (시뮬·시험) 영웅을 가운데 둔 기준 화면 크기.
func view_rect() -> Rect2:
	var vp := get_viewport() if is_inside_tree() else null
	if vp and vp.get_camera_2d():
		return vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	var size := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width", 720),
		ProjectSettings.get_setting("display/window/size/viewport_height", 1280))
	var c := player.global_position if player and is_instance_valid(player) else Vector2.ZERO
	return Rect2(c - size * 0.5, size)
