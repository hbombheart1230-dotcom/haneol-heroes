class_name TutorialDriver
extends RefCounted
## 조작 안내를 실제 손가락 입력(TouchController.handle_event)으로 끝까지 해 보는 도우미 (테스트 전용).
## 단계 event마다 사람이 할 동작을 낸다. 막히면 그 단계 이름을 돌려준다.

var suite: Node
var main: Node
var tc: TouchController
## 단계마다 걸린 시간(초)과 결과.
var log: Array = []
## 이번 단계에서 몇 번째 시도인지 (막히면 사람처럼 다른 쪽으로 피한다).
var tries: int = 0


func _init(s: Node, m: Node) -> void:
	suite = s
	main = m
	tc = m.get_node("TouchController") as TouchController


func _now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0


func _touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = pos
	e.pressed = pressed
	tc.handle_event(e, _now())


func _drag(pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = pos
	tc.handle_event(e, _now())


func frames(n: int) -> void:
	for i in n:
		await suite.get_tree().physics_frame


func seconds(s: float) -> void:
	var end := _now() + s
	while _now() < end:
		await suite.get_tree().physics_frame


func center() -> Vector2:
	return tc.viewport_size() * Vector2(0.5, 0.45)


func tap() -> void:
	_touch(center(), true)
	await frames(2)
	_touch(center(), false)


func hold(s: float) -> void:
	_touch(center(), true)
	await seconds(s)
	_touch(center(), false)


func flick(dir: Vector2) -> void:
	var p := center()
	_touch(p, true)
	await frames(1)
	_drag(p + dir * 60.0)
	await frames(1)
	_drag(p + dir * 140.0)
	_touch(p + dir * 140.0, false)


## 손가락을 대고 천천히 끈다 (걷기).
func walk(dir: Vector2, s: float) -> void:
	var p := center()
	_touch(p, true)
	await frames(2)
	var end := _now() + s
	var t := 0.0
	while _now() < end:
		t += 1.0
		_drag(p + dir * minf(t * 4.0, 90.0))
		await frames(1)
	_touch(p + dir * 90.0, false)


func step() -> TutorialStep:
	return main.tutorial_director.run.current()


## 연습 상대의 예고가 시작될 때까지 (최대 s초).
func wait_windup(s: float) -> bool:
	var end := _now() + s
	while _now() < end:
		var e: Enemy = main.tutorial_director.sparring.enemy
		if e and is_instance_valid(e) and e.attack and e.attack.state == EnemyAttack.State.WINDUP:
			return true
		await frames(1)
	return false


func _away_dir() -> Vector2:
	var e: Enemy = main.tutorial_director.sparring.enemy
	if e == null or not is_instance_valid(e):
		return Vector2.DOWN
	var d: Vector2 = (main.player.global_position - e.global_position).normalized()
	d = d if d != Vector2.ZERO else Vector2.DOWN
	return d.rotated(PI * 0.5 * tries)  # 벽·장애물에 막혔으면 옆으로


## 연습 상대 쪽 (내닫아 치기: 닿아야 둘째 기술). 상대가 아직 없으면 위.
func _toward_dir() -> Vector2:
	var e: Enemy = main.tutorial_director.sparring.enemy
	if e == null or not is_instance_valid(e):
		return Vector2.UP
	var d: Vector2 = (e.global_position - main.player.global_position).normalized()
	return d if d != Vector2.ZERO else Vector2.UP


## 지금 단계를 한 번 해 본다.
func act(ev: StringName) -> void:
	match ev:
		&"move":
			await walk(Vector2.RIGHT, 1.2)
		&"dash":
			await flick(Vector2.LEFT)
			await seconds(0.5)
		&"combo":
			for i in 3:
				await tap()
				await seconds(0.5)
		&"skill_tap":
			await tap()
			await seconds(0.5)
		&"skill_dash":  # 내닫아 치기: 연습 상대 쪽으로 튕겨 닿게 (DashAutoSkill)
			await flick(_toward_dir())
			await seconds(0.6)
		&"skill_charge":
			await hold(1.2)
			await seconds(0.4)
		&"evade":
			if await wait_windup(5.0):
				await flick(_away_dir())
			await seconds(0.3)
		&"skill_counter":
			if await wait_windup(5.0):
				await flick(_away_dir())
				await frames(3)
				await tap()
			await seconds(0.5)
		&"upgrade":
			var end := _now() + 3.0  # 연습 패는 단계가 시작되고 enter_delay(1.5초) 뒤에 열린다
			while not main.seal_choice.is_open() and _now() < end:
				await frames(2)
			if main.seal_choice.is_open():
				main.seal_choice.pick(0)
			await frames(2)
		_:
			await seconds(0.5)


## 처음부터 끝까지. 반환: 막힌 단계 event (다 되면 &"").
func play_all(max_tries: int = 6) -> StringName:
	var run: TutorialProgress = main.tutorial_director.run
	while not run.is_done():
		var s := step()
		var start := _now()
		var i := run.index
		tries = 0
		while run.index == i and not run.is_done() and tries < max_tries:
			await act(s.event)
			tries += 1
		log.append([String(s.event), snappedf(_now() - start, 0.1), tries])
		if run.index == i and not run.is_done():
			return s.event
	return &""


## 단계를 차례로 알려 ev 단계까지 건너간다 (판정 없이, 단위 테스트용).
static func skip_to(run: TutorialProgress, ev: StringName) -> void:
	while not run.is_done() and run.current().event != ev:
		run.elapse(60.0)  # 읽힐 시간(min_show)을 기다리는 단계도 건너간다
		run.notify(run.current().event, run.current().amount)
