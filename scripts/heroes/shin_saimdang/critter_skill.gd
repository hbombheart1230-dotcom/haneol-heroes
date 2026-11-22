class_name CritterSkill
extends SkillDef
## 사임당 · 풀벌레 부르기(가칭): 초충도 속 나비·방아깨비를 불러 lifetime초 동안 알아서 적을 공격.

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


func cast(ctx: SkillContext, _charge: float) -> SkillRun:
	var n := count + extra_butterflies
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
		ctx.add_to_world(c, ctx.player.global_position + Vector2.from_angle(TAU * i / n) * 40.0)
	if ctx.fx:
		ctx.fx.add_ring(ctx.player.global_position, 70.0, 0.4, fx_color)
	return SkillRun.instant(0)
