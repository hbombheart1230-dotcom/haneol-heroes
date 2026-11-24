class_name HeroVictory
extends Node
## 우두머리 처치 연출이 끝난 뒤 영웅 승리 동작 → 결과 화면 (우두머리 쓰러짐(EnemyDeathPose)은 연출 안에 끝난다).
## 그동안 조작 잠금(손가락 잊기·입력 끄기)과 무적. 길이는 HeroData.victory_time (1.5초 안쪽), 판 시각(GameTime.now_ms)으로 잰다.
## 시트에 victory가 없거나 길이가 0이면, 또는 영웅·그림이 없으면(시뮬·시험) 바로 done.
## 그림은 PlayerView.play_oneshot("victory") — 구운 칸과 3D(PlayerView3D가 같은 동작을 리그에 넘김) 모두.

const ANIM := "victory"
## 결과 화면이 너무 늦게 뜨지 않게 (지금 흐름 + 이 안쪽).
const MAX_TIME := 1.5
## 동작은 기다림보다 조금 더 길게 둔다: 결과 화면이 멈추는 순간 대기 자세로 돌아가 있지 않게.
const HOLD_PAST := 0.3

var done: Callable
var _until_ms: int = 0
var _input: Node


## 승리 동작을 틀고 끝나면 done. 틀 수 없으면 바로 done. 튼 노드를 돌려준다 (없으면 null).
static func play(host: Node, player: Player, finished: Callable) -> HeroVictory:
	var t := time_for(player)
	if t <= 0.0 or host == null or not host.is_inside_tree():
		finished.call()
		return null
	var v := HeroVictory.new()
	v.name = "HeroVictory"
	v.done = finished
	v._until_ms = GameTime.now_ms() + int(t * 1000.0)
	v._input = host.get_node_or_null("TouchController")
	host.add_child(v)
	v._lock(player, t)
	return v


## 이 영웅의 승리 동작 길이(초). 0 = 없음.
static func time_for(player: Player) -> float:
	if player == null or player.hero == null or player.is_dead():
		return 0.0
	var view := player.get_node_or_null("PlayerView") as PlayerView
	var sheet := player.hero.sprite_sheet
	if view == null or sheet == null or not sheet.has_anim(ANIM):
		return 0.0
	return clampf(player.hero.victory_time, 0.0, MAX_TIME)


func _lock(player: Player, t: float) -> void:
	if _input:
		if _input.has_method("cancel_all"):
			_input.cancel_all()
		_input.set_process_unhandled_input(false)
		_input.set_physics_process(false)
	player.set_move_input(Vector2.ZERO)
	player.grant_invulnerability(t)  # 처치 연출의 무적(finale_time + 1초)을 승리 동작 끝까지
	var view := player.get_node_or_null("PlayerView") as PlayerView
	view.play_oneshot(ANIM, t + HOLD_PAST)


func is_playing() -> bool:
	return GameTime.now_ms() < _until_ms


func _process(_delta: float) -> void:
	if is_playing():
		return
	set_process(false)
	if done.is_valid():
		done.call()
	queue_free()
