class_name EnemyDeathPose
extends Node
## 쓰러지는 죽음 (우두머리·정예부터): 체력 0 → 죽는 동작 → 잠깐 누워 있다가 → 군대별 죽음 모양(연기·종이 + 먹 자국)으로 사라진다.
## 죽는 동작("death": 3D 리그의 클립 또는 구운 시트)이 있는 적만. 없으면 지금처럼 바로 날아가 사라진다.
## 죽는 순간의 일(killed 신호·처치 소리·느린 시간·처치 연출·승리·패 고르기)은 그대로 그 순간에 일어난다 — 몸만 남는다.
## 남은 몸은 판정·공격·움직임·이름표가 없고, 무리 수(alive_count)에도 들지 않는다.
## 시간은 GameTime.now_ms (시뮬레이션은 판 시각): 처치 느린 시간과 상관없이 정해진 길이에 쓰러짐이 끝난다.
## 수치는 EnemyData.death_hold·death_rest·death_fade. death_hold가 음수면 처치 연출(boss_feel.finale_time) 안에 다 사라지게 맞춘다.

const ANIM := "death"
const META := &"death_pose"
## 처치 연출 끝보다 이만큼(초) 먼저 다 사라진다 (승리 화면·물결 끝과 겹치지 않게).
const FINALE_TAIL := 0.1

var enemy: Enemy
var _start_ms: int = 0
## 쓰러짐(동작) 길이·누워 있기·사라짐 (ms).
var _fall_ms: int = 0
var _rest_ms: int = 0
var _fade_ms: int = 0
var _rig: Node
var _clip_len: float = 0.0
var _dir: int = 0
var _burst := false


## 죽는 동작을 쓸 수 있으면 시작하고 true. 아니면 false (부른 쪽이 지금처럼 지운다).
static func begin(e: Enemy) -> bool:
	var hold := hold_time(e.data)
	if hold <= 0.0:
		return false
	var rig := EnemySprite3D.rig_of(e)
	var clip_len := -1.0
	if rig:
		var c: Dictionary = (rig.data as Live3DHeroData).clip(ANIM)
		if not c.is_empty() and rig.has_anim(ANIM):
			clip_len = maxf(float(c.get("end", 0.0)) - float(c.get("start", 0.0)), 0.0)
	elif e.sprite and e.data.sprite_sheet and e.data.sprite_sheet.has_anim(ANIM):
		clip_len = 0.0  # 구운 칸은 진행 비율로 고른다
	if clip_len < 0.0:
		return false
	var p := EnemyDeathPose.new()
	p.name = "DeathPose"
	p.enemy = e
	p._rig = rig
	p._clip_len = clip_len
	p._start_ms = GameTime.now_ms()
	var rest := clampf(e.data.death_rest, 0.0, hold)
	p._rest_ms = int(rest * 1000.0)
	p._fall_ms = maxi(int((hold - rest) * 1000.0), 1)
	p._fade_ms = maxi(int(e.data.death_fade * 1000.0), 1)
	p._dir = _dir_of(e)
	e.set_meta(META, p)
	e.add_child(p)
	p._still(e)
	return true


## 처치부터 사라지기 시작까지(초). 0 이하 = 죽는 동작 없음.
static func hold_time(d: EnemyData) -> float:
	if d == null or d.death_hold == 0.0:
		return 0.0
	if d.death_hold > 0.0:
		return d.death_hold
	if d.boss_feel == null:
		return 0.0
	return d.boss_feel.finale_time - d.death_fade - FINALE_TAIL


## 처치부터 다 사라질 때까지(초): 물결이 이만큼 기다린다.
static func total_time(d: EnemyData) -> float:
	var h := hold_time(d)
	return h + d.death_fade if h > 0.0 else 0.0


static func of(e: Enemy) -> EnemyDeathPose:
	return e.get_meta(META) as EnemyDeathPose if e and is_instance_valid(e) and e.has_meta(META) else null


## 진행: 0 → 1 = 쓰러짐, 그 뒤 누워 있기, 사라짐 (순수 계산, 시험용).
static func phase_at(elapsed_ms: int, fall_ms: int, rest_ms: int, fade_ms: int) -> Vector2:
	var fall := clampf(float(elapsed_ms) / maxf(fall_ms, 1), 0.0, 1.0)
	var fade := clampf(float(elapsed_ms - fall_ms - rest_ms) / maxf(fade_ms, 1), 0.0, 1.0)
	return Vector2(fall, fade)


## 남은 몸은 움직이지도, 치지도, 맞지도 않는다.
func _still(e: Enemy) -> void:
	e.set_physics_process(false)
	e.velocity = Vector2.ZERO
	e.collision_layer = 0
	e.collision_mask = 0
	for n in e.find_children("*", "Area2D", true, false):
		(n as Area2D).set_deferred("monitoring", false)
		(n as Area2D).set_deferred("monitorable", false)
	if e.sprite:
		e.sprite.speed_scale = 0.0
		var sheet := e.data.sprite_sheet
		if _rig == null and sheet.has_anim(ANIM):
			e.sprite.play(StringName("%s_%d" % [ANIM, _dir]))
			e.sprite.speed_scale = 0.0
		e.sprite.rotation = 0.0
		e.sprite.modulate = Color.WHITE
	if _rig:
		_rig.widen((_rig.data as Live3DHeroData).wide_view)  # 누운 몸이 3D 칸 밖으로 잘리지 않게
		if e.sprite:  # 스프라이트는 화면 크기가 바뀐 것을 모른다 (옛 크기 사각형에 그려 확대·잘림) → 칸을 다시 단다
			var an := e.sprite.animation
			e.sprite.sprite_frames = EnemySprite3D.PV3D.single_frames(e.data.sprite_sheet, _rig.texture())
			e.sprite.play(an)
			e.sprite.speed_scale = 0.0
	e.queue_redraw()  # 이름표·막대 지우기 (Enemy._draw가 남은 몸은 그림자만)
	_apply(0.0, 0.0)


func _process(_delta: float) -> void:
	if not is_instance_valid(enemy):
		return
	var ph := phase_at(GameTime.now_ms() - _start_ms, _fall_ms, _rest_ms, _fade_ms)
	if ph.y > 0.0 and not _burst:
		_burst = true
		Feedback.enemy_dissolved(enemy)
	_apply(ph.x, ph.y)
	if ph.y >= 1.0:
		enemy.queue_free()


func _apply(fall: float, fade: float) -> void:
	if _rig:
		_rig.play_body(ANIM, false, fall * _clip_len, 0.0)
	elif enemy.sprite:
		var n := enemy.data.sprite_sheet.frame_count(ANIM)
		enemy.sprite.frame = mini(int(fall * n), n - 1)
	if enemy.sprite:
		enemy.sprite.modulate.a = 1.0 - fade


## 지금 보는 방향 번호 (애니메이션 이름 끝 "_<번호>").
static func _dir_of(e: Enemy) -> int:
	if e.sprite == null:
		return 0
	var n := String(e.sprite.animation)
	var i := n.rfind("_")
	return int(n.substr(i + 1)) if i >= 0 and n.substr(i + 1).is_valid_int() else 0
