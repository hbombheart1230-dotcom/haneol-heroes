class_name CritterSkill
extends SkillDef
## 사임당 · 풀벌레 부르기(가칭): 초충도 속 나비·방아깨비를 불러 알아서 적을 공격. 한 마리가 bites번 물면 사라진다.
## 사용자 2026-11-26 "사임당 풀벌레 너프해야되는데 초가 아니라 타격 횟수로": 끝을 시간이 아니라 무는 횟수로.

const GROUP := &"hero_critters"

@export var count: int = 2
## 한 마리가 무는 횟수 (다 물면 사라진다, 마지막 물기는 크게). 0이면 횟수 상한 없음 (시간으로만).
@export var bites: int = 6
## 안전용 긴 상한(초): 물 적이 없어 떠도는 풀벌레가 영원히 남지 않게. 끝은 보통 bites가 정한다.
@export var lifetime: float = 8.0
## 물 때 적이 멈칫하는 물기 (멈춤·움찔·예고 끊김). 사용자 2026-11-26 "짧게 멈추는거도 걸리고".
## 0 = 모든 물기, 1 = 마리마다 첫 물기와 마지막 큰 물기만 (사이는 피해만), 2 = 잡몹은 모든 물기·정예 이상은 마지막 큰 물기만.
## 사용자 결정 2026-11-26 "나로하자" → 2 (다 갖춘 판에서 우두머리가 풀벌레 때문에 서 있던 37% → 5%, 잡몹을 무는 맛은 그대로).
@export_range(0, 2) var flinch: int = 0
@export var damage: int = 8
@export var hit_interval: float = 0.5
@export var speed: float = 380.0
## 그려 넣은 나비·방아깨비 그림 (B안, 비면 꽃잎 모양으로 그림)과 크기(px).
@export var butterfly_art: Texture2D
@export var grasshopper_art: Texture2D
@export var critter_size: float = 64.0
@export_group("큰 변형 · 화접도")
## 소환 수에 더해지는 나비 수 (큰 변형).
@export var extra_butterflies: int = 0
@export_group("한꺼번에 남는 수")
## 0보다 크면 이 영웅의 풀벌레가 한꺼번에 이만큼까지만 남는다 (새로 부르면 가장 오래된 것부터 사라진다).
## 사용자 9e19cfb "사임당 나비 너무 세. 사기야": 수명(8초)보다 자주 불러 겹겹이 쌓였다 (성장하면 한 번에 7마리 × 쌓임).
@export var max_alive: int = 0
## 수명 상한: 다음 부르기(4타 마무리 간격 = cooldown × combo_finisher_cd_ratio)보다 이만큼(초) 먼저 사라진다.
## 사용자 결정 2026-11-26 (패 점검 #229): 긴 숨·빠른 붓 패로 수명이 간격을 넘어 다시 겹겹이 쌓이던 것을 막는다.
## 빠른 붓으로 간격이 줄면 상한도 같이 준다. 상한에 닿아 헛된 패는 후보에서 빠진다 (UpgradeEffect.useful).
## 무는 횟수로 끝나게 바꾸며 (2026-11-26) 기본은 끔: 켜면 안전 상한도 다음 마무리 간격 − lifetime_margin까지.
@export var cap_lifetime: bool = false
@export var lifetime_margin: float = 0.3
@export var lifetime_floor: float = 1.0


## 다음 부르기까지 (4타 마무리 간격, 단추로만 쓰면 쿨타임) 빼기 여유.
func lifetime_cap(kit: SkillKit) -> float:
	var gap := cooldown
	if kit and kit.tap_combo and not kit.combo_finisher_free:
		gap *= kit.combo_finisher_cd_ratio
	return maxf(gap - lifetime_margin, lifetime_floor)


func effective(prop: StringName, v: Variant, kit: SkillKit) -> Variant:
	if prop == &"lifetime" and cap_lifetime:
		return minf(float(v), lifetime_cap(kit))
	return v


func capped_props() -> Array[StringName]:
	return [&"lifetime"] if cap_lifetime else []


func cast(ctx: SkillContext, _charge: float) -> SkillRun:
	var kit: SkillKit = ctx.player.hero.kit if ctx.player and ctx.player.hero else null
	var life := float(effective(&"lifetime", lifetime, kit))
	var n := count + extra_butterflies
	if max_alive > 0:
		n = mini(n, max_alive)
		_trim(ctx, max_alive - n)
	for i in n:
		var c := SummonCritter.new()
		c.ctx = ctx
		c.owner_node = ctx.player
		c.kind = SummonCritter.Kind.GRASSHOPPER if i % 2 == 1 and i < count else SummonCritter.Kind.BUTTERFLY
		c.lifetime = life
		c.bites = bites
		c.flinch = flinch
		c.damage = damage
		c.hit_interval = hit_interval
		c.speed = speed
		c.color = fx_color
		c.art = grasshopper_art if c.kind == SummonCritter.Kind.GRASSHOPPER else butterfly_art
		c.art_size = critter_size
		c.add_to_group(GROUP)
		ctx.add_to_world(c, ctx.player.global_position + Vector2.from_angle(TAU * i / n) * 40.0)
	if ctx.fx:
		ctx.fx.add_ring(ctx.player.global_position, 70.0, 0.4, fx_color)
	return SkillRun.instant(0)


## 남아 있는 이 영웅의 풀벌레를 keep마리만 남기고 오래된 것부터 지운다.
func _trim(ctx: SkillContext, keep: int) -> void:
	if ctx.player == null or not ctx.player.is_inside_tree():
		return
	var mine: Array = ctx.player.get_tree().get_nodes_in_group(GROUP).filter(func(n: Node) -> bool:
		return n is SummonCritter and (n as SummonCritter).owner_node == ctx.player and not n.is_queued_for_deletion())
	mine.sort_custom(func(a: SummonCritter, b: SummonCritter) -> bool: return a.age() > b.age())
	for i in maxi(mine.size() - maxi(keep, 0), 0):
		(mine[i] as SummonCritter).queue_free()
