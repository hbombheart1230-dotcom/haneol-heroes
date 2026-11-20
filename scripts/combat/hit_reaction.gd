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
## 마지막 움찔 뒤 흐른 시간 (개별 멈춤 중에는 흐르지 않음 → 멈춤 동안 가장 크게 젖힌 채 떤다).
var _age: float = INF
## 맞은 방향 (때린 쪽 → 적)과 움찔 크기 배율.
var _dir: Vector2 = Vector2.ZERO
var _k: float = 1.0


func _init(p_data: HitReactionData = null, p_tier: Tier = Tier.TRASH) -> void:
	data = p_data if p_data else HitReactionData.new()
	tier = p_tier


static func tier_of(d: EnemyData, has_affix: bool) -> Tier:
	if d and d.is_boss:
		return Tier.BOSS
	if (d and d.is_elite) or has_affix:
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
		stagger_left = maxf(stagger_left, data.stagger_time)
	var plays := tier == Tier.TRASH \
		or (tier == Tier.ELITE and applied >= maxi(max_hp, 1) * data.elite_flinch_hp_frac) \
		or (tier == Tier.BOSS and data.boss_flinch)
	if plays:
		anim_left = data.hit_anim_time
	return plays


## 밀쳐짐 (영웅의 숨 돌릴 틈 등): 잡몹만 잠깐 경직.
func on_shove() -> void:
	if tier == Tier.TRASH:
		stagger_left = maxf(stagger_left, data.stagger_time)


func tick(delta: float) -> void:
	anim_left = maxf(anim_left - delta, 0.0)
	stagger_left = maxf(stagger_left - delta, 0.0)
	_age += delta


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
	if flash_left > flash_time - peak_time:
		return data.flash_white
	return data.flash_white_tail * clampf(flash_left / maxf(flash_time - peak_time, 0.001), 0.0, 1.0)


## 0~1: 움찔 직후 1에서 duration 동안 0으로 (부드럽게 감속).
func _fade(duration: float) -> float:
	if duration <= 0.0 or _age >= duration:
		return 0.0
	var t := 1.0 - _age / duration
	return t * t
