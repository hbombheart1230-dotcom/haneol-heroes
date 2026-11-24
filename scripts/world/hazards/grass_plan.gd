class_name GrassPlan
extends RefCounted
## 풀숲의 순수 계산: 어느 풀숲 안인가, 기습 덤 피해, 숨음·기습 시간 흐름.

## 점 p가 든 풀숲 번호 (없으면 -1). 몸 반지름 r만큼 걸쳐도 안으로 본다 (가운데가 들어가야: r은 빼서 잰다).
static func inside(patches: PackedVector3Array, p: Vector2, r: float = 0.0) -> int:
	for i in patches.size():
		if p.distance_to(Vector2(patches[i].x, patches[i].y)) <= patches[i].z - r:
			return i
	return -1


## 기습 덤 피해: 원래 피해 amount에 더할 몫 (×mult가 되게). 최소 1.
static func ambush_extra(amount: int, mult: float) -> int:
	return maxi(roundi(amount * (mult - 1.0)), 1) if mult > 1.0 and amount > 0 else 0


## 숨음·기습 상태 (한 영웅).
class State extends RefCounted:
	var data: GrassData
	## 지금 풀숲 안인가 / 숨었나 (안이고 드러나지 않음) / 기습이 걸려 있나.
	var in_grass: bool = false
	var reveal_left: float = 0.0
	var ambush_left: float = 0.0

	func _init(d: GrassData) -> void:
		data = d

	func hidden() -> bool:
		return in_grass and reveal_left <= 0.0

	func ambush_ready() -> bool:
		return hidden() or ambush_left > 0.0

	## dt초 흐름. now_in = 이번 틀에 풀숲 안. 반환: 들어감(+1)·나옴(-1)·그대로(0).
	func step(dt: float, now_in: bool) -> int:
		reveal_left = maxf(reveal_left - dt, 0.0)
		ambush_left = maxf(ambush_left - dt, 0.0)
		var change := 0
		if now_in != in_grass:
			change = 1 if now_in else -1
			if not now_in and reveal_left <= 0.0:
				ambush_left = data.ambush_window  # 숨어 있다가 나왔다: 기습 시간
		in_grass = now_in
		return change

	## 기습을 썼다 (쳤다): 드러나고 기습은 끝.
	func spend() -> void:
		ambush_left = 0.0
		reveal_left = data.reveal_time
