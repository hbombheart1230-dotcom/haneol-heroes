class_name EnemyLaunch
extends RefCounted
## 큰 기술의 "크게 날리기" (사용자: 3타에서 크게 날리면 넷째 탭 기술이 허공을 친다 → 큰 밀림은 마무리·큰 기술에만).
## 정해진 거리를 정해진 곡선으로: 맞고 hold초는 거의 제자리(멈춤 느낌), 그 뒤 빠르게 튀어 time초에 걸쳐 감속해 선다
## (하데스 3타 실측: 약 3칸 멈춤 → 칸마다 35~45px → 약 8칸에 걸쳐 줄어 0.4초쯤 멈춤). 벽·다른 적은 move_and_slide가 막는다.
## 순수 계산 (속도만 돌려준다), Enemy가 매 물리 프레임 tick을 더한다.

var _dir: Vector2 = Vector2.ZERO
var _dist: float = 0.0
var _hold: float = 0.0
var _time: float = 0.3
var _t: float = -1.0
var _hold_share: float = 0.04


## dir 쪽으로 dist px (hold_share = 멈춤 동안 갈 비율). 이미 날아가는 중이면 새 것으로 처음부터 다시.
func start(dir: Vector2, dist: float, hold: float = 0.05, time: float = 0.3, hold_share: float = 0.04) -> void:
	if dist <= 0.0 or dir.length_squared() < 0.0001:
		return
	_dir = dir.normalized()
	_dist = dist
	_hold = maxf(hold, 0.0)
	_time = maxf(time, 0.02)
	_hold_share = clampf(hold_share, 0.0, 1.0)
	_t = 0.0


func active() -> bool:
	return _t >= 0.0


## 0~1 날아간 진행 (날아가지 않으면 0), 날아가는 방향.
func progress() -> float:
	return clampf(_t / maxf(_hold + _time, 0.001), 0.0, 1.0) if _t >= 0.0 else 0.0


func dir() -> Vector2:
	return _dir


## 이번 프레임 속도 (px/s). 곡선: 남은 거리가 (1-u)^3 로 줄어든다 (처음 빠르고 끝에서 부드럽게 선다).
func tick(delta: float) -> Vector2:
	if _t < 0.0:
		return Vector2.ZERO
	var before := _covered(_t)
	_t += delta
	var after := _covered(_t)
	if _t >= _hold + _time:
		_t = -1.0
	return _dir * ((after - before) / maxf(delta, 0.0001))


## 지금까지 간 거리 (멈춤 구간엔 전체의 _hold_share만).
func _covered(t: float) -> float:
	if t <= _hold:
		return _dist * _hold_share * (t / maxf(_hold, 0.001))
	var u := clampf((t - _hold) / _time, 0.0, 1.0)
	return _dist * (_hold_share + (1.0 - _hold_share) * (1.0 - pow(1.0 - u, 3.0)))
