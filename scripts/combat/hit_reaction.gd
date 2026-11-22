class_name HitReaction
extends RefCounted
## 적 하나의 맞는 반응 상태 (순수 로직, 노드 없음 → 테스트 가능).
## 맞는 동작 시간·잡몹 경직·그림 움찔(눌림·젖힘·기울기)·흰 번쩍임 세기를 계산한다. 그리기는 EnemySprite가.

enum Tier { TRASH, ELITE, BOSS }

var data: HitReactionData
var tier: Tier = Tier.TRASH
## 맞는 동작을 더 보여 줄 시간, 경직 남은 시간(초).
var anim_left: float = 0.0
var stagger_left: float = 0.0
## 적별 경직 길이 (EnemyData.stagger_time, 음수 = 공통값).
var stagger_override: float = -1.0
## 마지막 움찔 뒤 흐른 시간 (개별 멈춤 중에는 흐르지 않음 → 멈춤 동안 가장 크게 젖힌 채 떤다).
var _age: float = INF
## 맞은 방향 (때린 쪽 → 적)과 움찔 크기 배율.
var _dir: Vector2 = Vector2.ZERO
var _k: float = 1.0
## 넘어짐 (B8): 남은 시간·전체 시간·떠오르는 높이·그 시간, 다시 넘어지지 않는 남은 시간.
var down_left: float = 0.0
var down_total: float = 0.0
var _down_lift_px: float = 0.0
var _down_lift_time: float = 0.0
var _down_guard: float = 0.0


func _init(p_data: HitReactionData = null, p_tier: Tier = Tier.TRASH) -> void:
	data = p_data if p_data else HitReactionData.new()
	tier = p_tier


## hp_mult < 1 (분열로 나온 작은 적 등)은 정예 데이터여도 잡몹.
static func tier_of(d: EnemyData, has_affix: bool, hp_mult: float = 1.0) -> Tier:
	if d and d.is_boss:
		return Tier.BOSS
	if ((d and d.is_elite) or has_affix) and hp_mult >= 1.0:
		return Tier.ELITE
	return Tier.TRASH


## 피해를 받았을 때. 반환: 맞는 동작을 (다시) 시작하면 true.
func on_hit(applied: int, max_hp: int, dir: Vector2) -> bool:
	if applied <= 0:
		return false
	_age = 0.0
	if dir.length_squared() > 0.0001:
		_dir = dir.normalized()
	_k = 1.0 if tier == Tier.TRASH else data.heavy_flinch_scale
	if tier == Tier.TRASH:
		stagger_left = maxf(stagger_left, stagger_time())
	var plays := tier == Tier.TRASH \
		or (tier == Tier.ELITE and applied >= maxi(max_hp, 1) * data.elite_flinch_hp_frac) \
		or (tier == Tier.BOSS and data.boss_flinch)
	if plays:
		anim_left = data.hit_anim_time
	return plays


## 밀쳐짐 (영웅의 숨 돌릴 틈 등): 잡몹만 잠깐 경직.
func on_shove() -> void:
	if tier == Tier.TRASH:
		stagger_left = maxf(stagger_left, stagger_time())


## 잡몹 경직 길이: 적 데이터 값(0 이상)이 있으면 그것, 없으면 공통값.
func stagger_time() -> float:
	return stagger_override if stagger_override >= 0.0 else data.stagger_time


func tick(delta: float) -> void:
	anim_left = maxf(anim_left - delta, 0.0)
	stagger_left = maxf(stagger_left - delta, 0.0)
	if down_left > 0.0:
		down_left = maxf(down_left - delta, 0.0)
	else:
		_down_guard = maxf(_down_guard - delta, 0.0)
	_age += delta


## 넘어뜨리기 (잡몹만, 일어난 직후는 아님). 넘어졌으면 true.
func knock_down(d: ImpactFeelData) -> bool:
	if tier != Tier.TRASH or down_left > 0.0 or _down_guard > 0.0 or d.down_time <= 0.0:
		return false
	down_left = d.down_time
	down_total = d.down_time
	_down_lift_px = d.down_lift_px
	_down_lift_time = minf(d.down_lift_time, d.down_time)
	_down_guard = d.down_rearm
	return true


func is_down() -> bool:
	return down_left > 0.0


## 0~1 넘어짐 진행 (넘어져 있지 않으면 0).
func down_progress() -> float:
	return clampf(1.0 - down_left / maxf(down_total, 0.001), 0.0, 1.0) if down_left > 0.0 else 0.0


## 넘어짐 동작이 없을 때 눕히는 기울기(라디안): 맞은 방향 쪽으로 처음 20% 동안 넘어가 누웠다가 마지막 20%에 일어난다.
func down_tilt(max_deg: float) -> float:
	if down_left <= 0.0:
		return 0.0
	var k := down_progress()
	var env := minf(minf(k / 0.2, (1.0 - k) / 0.2), 1.0)
	return deg_to_rad(max_deg) * (1.0 if _dir.x >= 0.0 else -1.0) * env


## 떠오른 높이(px): 처음 lift_time 동안 포물선.
func down_lift() -> float:
	var t := down_total - down_left
	if down_left <= 0.0 or _down_lift_time <= 0.0 or t >= _down_lift_time:
		return 0.0
	var k := t / _down_lift_time
	return 4.0 * _down_lift_px * k * (1.0 - k)


func is_staggered() -> bool:
	return stagger_left > 0.0


func shows_hit_anim() -> bool:
	return anim_left > 0.0


## 그림 배율 (발 기준 눌림). 맞은 순간 squash → 원래대로.
func squash_mult() -> Vector2:
	var w := _fade(data.squash_time)
	return Vector2.ONE.lerp(data.squash, w * _k) if w > 0.0 else Vector2.ONE


## 그림 오프셋 (맞은 방향으로 젖혀짐).
func lean_offset() -> Vector2:
	return _dir * data.lean_px * _k * _fade(data.lean_time)


## 그림 기울기(라디안): 맞은 방향 쪽으로 넘어가듯.
func tilt() -> float:
	var side := 1.0 if _dir.x >= 0.0 else -1.0
	return deg_to_rad(data.tilt_deg) * _k * side * _fade(data.lean_time)


## 개별 멈춤 중 떨림 폭: 크게 시작해 멈춤이 끝날 때 0 (스매시식).
static func shake_px(base_px: float, freeze_left: float, freeze_total: float) -> float:
	if freeze_total <= 0.0 or freeze_left <= 0.0:
		return 0.0
	return base_px * clampf(freeze_left / freeze_total, 0.0, 1.0)


## 흰색 섞는 비율 (셰이더 flash). flash_left: 남은 번쩍임, 전체·처음 밝은 구간은 CombatFeelData.
func flash_amount(flash_left: float, flash_time: float, peak_time: float) -> float:
	if flash_left <= 0.0 or flash_time <= 0.0:
		return 0.0
	if data.flash_blinks > 1:  # 켜짐 · 꺼짐 · 켜짐 … (마지막 칸까지)
		var seg := flash_time / float(2 * data.flash_blinks - 1)
		var idx := int((flash_time - flash_left) / maxf(seg, 0.001))
		return 0.0 if idx % 2 == 1 else data.flash_white
	if flash_left > flash_time - peak_time:
		return data.flash_white
	return data.flash_white_tail * clampf(flash_left / maxf(flash_time - peak_time, 0.001), 0.0, 1.0)


## 0~1: 움찔 직후 1에서 duration 동안 0으로 (부드럽게 감속).
func _fade(duration: float) -> float:
	if duration <= 0.0 or _age >= duration:
		return 0.0
	var t := 1.0 - _age / duration
	return t * t
