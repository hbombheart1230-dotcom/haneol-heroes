class_name TapCombo
extends RefCounted
## 한 손 탭 연타 (A안, 순수 로직): 제자리 탭 = 근접 1타 (세종은 글자 던지기), 연계를 hits_needed번 이은 뒤
## 다음 탭 = 1번 기술(kit.tap)로 마무리. 연계는 window초 안에 다음 탭이 와야 이어진다.
## 너무 빨리 친 탭은 buffer초 동안 기억했다가 칠 수 있게 되면 나간다 (선입력).

enum Action { NONE, HIT, FINISH, BUFFERED }

## 손으로 이은 타 수 (마무리 전까지 hits_needed에서 멈춘다).
var streak: int = 0
## 근접 연계 동작 번호 (1·2·3 순환, 3이 강타).
var step: int = 0
var _since: float = INF
var _buffer: float = 0.0


func tick(delta: float, window: float) -> void:
	_since += delta
	_buffer = maxf(_buffer - delta, 0.0)
	if _since > window:
		streak = 0
		step = 0


## 이번 탭이 할 일. can_hit: 지금 칠 수 있음 (속도 상한·이전 타 진행 중이 아님), finisher_ready: 마무리 기술 준비됨.
func decide(hits_needed: int, can_hit: bool, finisher_ready: bool) -> Action:
	if streak >= hits_needed and finisher_ready:
		return Action.FINISH
	return Action.HIT if can_hit else Action.BUFFERED


## 손으로 한 타 냈다. 반환: 이번 타의 연계 동작 번호 (1·2·3).
func on_hit(hits_needed: int, chain_len: int) -> int:
	streak = mini(streak + 1, maxi(hits_needed, 1))
	step = step % maxi(chain_len, 1) + 1
	_since = 0.0
	_buffer = 0.0
	return step


## 자동 평타 (데이터가 셈에 넣으라고 할 때만 부른다).
func on_auto_hit(hits_needed: int) -> void:
	streak = mini(streak + 1, maxi(hits_needed, 1))
	_since = 0.0


func on_finish() -> void:
	streak = 0
	step = 0
	_since = 0.0
	_buffer = 0.0


func buffer(seconds: float) -> void:
	_buffer = seconds


func has_buffer() -> bool:
	return _buffer > 0.0


## 마무리로 나가는 기술: 피해 속성(이름에 damage가 있고 mult·ratio가 아닌 수)만 mult배 한 사본.
## 범위·개수는 그대로, 강화로 바뀐 현재 값에서 곱한다 (기술 파일은 건드리지 않는다).
static func scaled_def(d: SkillDef, mult: float) -> SkillDef:
	if d == null or is_equal_approx(mult, 1.0):
		return d
	var c := d.duplicate() as SkillDef
	for p in c.get_property_list():
		var n := String(p["name"])
		if not n.contains("damage") or n.contains("mult") or n.contains("ratio"):
			continue
		var v: Variant = c.get(n)
		if typeof(v) == TYPE_INT:
			c.set(n, maxi(roundi(v * mult), 1))
		elif typeof(v) == TYPE_FLOAT:
			c.set(n, v * mult)
	return c
