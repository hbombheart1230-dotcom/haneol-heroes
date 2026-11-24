class_name StepGuard
extends RefCounted
## 연타 전진이 영웅을 위험한 자리로 밀어 넣지 않게 (사용자 2026-11-25 "근접 연타에 실제 전진"):
## 무리 GROUP의 무대 장치가 step_danger_at(위치, 몸 반지름) -> bool을 가진다 (한산 포격선 예고 줄, 만주 들불 타는 칸).
## 적 공격 예고는 ComboSteps.in_windup이 따로 본다. 벽·가림막은 몸 이동(move_and_slide)이 막는다.

const GROUP := &"hero_step_danger"


## dir 쪽으로 px만큼 내디딜 때 안전한 거리: 끝점이 위험하면 절반, 그래도 위험하면 0.
static func safe_px(tree: SceneTree, from: Vector2, dir: Vector2, px: float, radius: float) -> float:
	if tree == null or px <= 0.0:
		return px
	var list := tree.get_nodes_in_group(GROUP)
	if list.is_empty():
		return px
	for k in [1.0, 0.5]:
		if not danger_at(list, from + dir * px * k, radius):
			return px * k
	return 0.0


static func danger_at(list: Array, p: Vector2, radius: float) -> bool:
	for n in list:
		if is_instance_valid(n) and n.has_method(&"step_danger_at") and n.step_danger_at(p, radius):
			return true
	return false
