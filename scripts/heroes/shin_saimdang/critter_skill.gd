class_name CritterSkill
extends SkillDef
## 사임당 · 풀벌레 부르기(가칭): 초충도 속 나비·방아깨비를 불러 lifetime초 동안 알아서 적을 공격.

const GROUP := &"hero_critters"

@export var count: int = 2
@export var lifetime: float = 8.0
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


func cast(ctx: SkillContext, _charge: float) -> SkillRun:
	var n := count + extra_butterflies
	if max_alive > 0:
		n = mini(n, max_alive)
		_trim(ctx, max_alive - n)
	for i in n:
		var c := SummonCritter.new()
		c.ctx = ctx
		c.owner_node = ctx.player
		c.kind = SummonCritter.Kind.GRASSHOPPER if i % 2 == 1 and i < count else SummonCritter.Kind.BUTTERFLY
		c.lifetime = lifetime
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
