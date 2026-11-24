class_name EnemyBars
extends Node2D
## 적 머리 위 체력 막대 (설정 "적 체력"). 다친 적만, 보스는 빼고 (보스는 HUD 위쪽 막대).
## 적 스크립트를 건드리지 않고 한 노드에서 모두 그린다.

@export var width: float = 64.0


func _ready() -> void:
	z_index = 5


func _process(_delta: float) -> void:
	queue_redraw()


## 그릴 막대들: [위치, 비율, 정예인지].
func bars() -> Array:
	var out: Array = []
	if not GameSettings.enemy_hp_bars or not is_inside_tree():
		return out
	for n in get_tree().get_nodes_in_group(Enemy.GROUP):
		var e := n as Enemy
		if e == null or not is_instance_valid(e) or e.health == null or e.health.is_dead():
			continue
		if e.data and (e.data.is_boss or e.data.boss_feel):  # 화면 위 띠가 있다
			continue
		var r := float(e.health.current) / maxf(float(e.health.max), 1.0)
		if r >= 1.0:
			continue
		out.append([e.global_position + Vector2(0, -e.body_radius * 3.2), r, e.data != null and e.data.is_elite])
	return out


func _draw() -> void:
	var st := InkUiStyle.default()
	for b in bars():
		var w := width * (1.4 if b[2] else 1.0)
		var r := Rect2(b[0] - Vector2(w * 0.5, 0), Vector2(w, st.enemy_bar_height))
		InkPaint.bar(self, r, b[1], st.elite_fill if b[2] else st.enemy_fill, st.bar_back, 3.0, st.bar_under)
