class_name ScoreFeed
extends RefCounted
## 점수(경험치)원을 모아 RunProgress에 넣는다: 처치 + 잘한 행동 (연타 마무리·회피·반격 명중·충전 기술 다 모아 맞힘).
## 행동마다 간격·물결당 상한 (ScoreTable). 시간은 clock(판 시간)으로 재서 멈춤·느린 시간에 흔들리지 않는다.
## 노드 연결은 connect_to, 판정은 award (테스트는 award를 직접 부른다).

var progress: RunProgress
var table: ScoreTable
## 판 시간 (초). 비우면 0.
var clock: Callable
## 점수를 받을 수 있는 때인지 (판 진행 중). 비우면 늘.
var active: Callable
var _last := {}
var _count := {}
var _caster: SkillCaster


func _init(p_progress: RunProgress, p_table: ScoreTable) -> void:
	progress = p_progress
	table = p_table


func now() -> float:
	return float(clock.call()) if clock.is_valid() else 0.0


## 행동 점수 하나. 상한에 걸리면 0. 반환: 받은 점수.
func award(kind: StringName) -> int:
	if table == null or progress == null or (active.is_valid() and not bool(active.call())):
		return 0
	var v := table.value_of(kind)
	if v <= 0:
		return 0
	var t := now()
	if _last.has(kind) and t - float(_last[kind]) < table.gap_of(kind):
		return 0
	if table.per_wave_cap > 0 and int(_count.get(kind, 0)) >= table.per_wave_cap:
		return 0
	_last[kind] = t
	_count[kind] = int(_count.get(kind, 0)) + 1
	progress.add_xp(v, kind)
	return v


## 처치 점수 (EnemyData.xp × 무대 배율 × kill_mult).
func kill(e: Enemy, stage_mult: float) -> int:
	if e == null or e.data == null:
		return 0
	var form := e.formation.data.xp_mult if e.formation and e.formation.data else 1.0  # 대형 구성원 몫 (FormationData.xp_mult)
	var v := roundi(e.data.xp * stage_mult * form * (table.kill_mult if table else 1.0))
	if v > 0:
		progress.add_xp(v, &"elite" if e.data.is_elite else &"kill")
	return v


## 숨 고르기마다: 물결당 상한을 다시 센다.
func new_wave() -> void:
	_count.clear()


func connect_to(player: Player, caster: SkillCaster) -> void:
	_caster = caster
	if player and not player.evaded.is_connected(_on_evaded):
		player.evaded.connect(_on_evaded)
	if caster:
		if not caster.combo_count.is_connected(_on_combo):
			caster.combo_count.connect(_on_combo)
		if not caster.skill_cast.is_connected(_on_cast):
			caster.skill_cast.connect(_on_cast)


func _on_evaded() -> void:
	award(&"evade")


func _on_combo(n: int) -> void:
	if _caster and _caster.kit and n == _caster.kit.combo_hits + 1:  # 마무리까지 이어 감
		award(&"combo")


func _on_cast(slot: SkillCaster.Slot, hits: int) -> void:
	if hits <= 0:
		return
	if slot == SkillCaster.Slot.COUNTER:
		award(&"counter")
	elif slot == SkillCaster.Slot.CHARGE and _caster and table and _caster.last_charge >= table.full_charge_ratio:
		award(&"charge")
