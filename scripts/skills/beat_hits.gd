class_name BeatHits
extends RefCounted
## 한 번에 끝나던 기술을 몇 타로 나눠 넣는다 (WaveRake standalone 위): 적마다 beats번, 간격 interval초,
## 총 피해는 그대로 나눠 마지막 타가 크게 (last_weight). 타마다 피해 한 번·명중음, 멈춤은 모든 타가 끝나면 한 번
## (SkillMultiHit.finale, #92·#96 규칙). 광개토 뇌진격·벽력돌파·정복자 (쿵-쿵-쾅), 사임당 매화 (꽃잎), 세종 성좌진 (별빛).


## targets 각각을 친다. delay_of.call(enemy) -> float 이 있으면 적마다 첫 타가 그만큼 늦다 (꽃잎이 바깥 적에 늦게 닿기).
## last_weight가 음수면 그 크기만큼 첫 타가 크다 (유성: 본 충격 뒤 여진).
## heavy: 앞 타들도 묵직한 한 타 충격. on_last.call(enemy): 마지막 타 뒤 (살아 있을 때, 날리기 등). 반환: 칠 적 수.
static func start(ctx: SkillContext, at: Vector2, targets: Array[Enemy], dmg: int, beats: int, interval: float,
		last_weight: float, heavy: bool = false, sfx: StringName = &"", on_last: Callable = Callable(),
		delay_of: Callable = Callable()) -> WaveRake:
	var rake := open(ctx, at, interval, heavy, sfx)
	rake.on_last = on_last
	var pl := WaveRake.plan(dmg, maxi(beats, 1), last_weight, 0.0, 0.0)
	if last_weight < 0.0:  # 음수면 첫 타가 크다 (본 충격 + 여진): 같은 나눔을 거꾸로
		pl = WaveRake.plan(dmg, maxi(beats, 1), -last_weight, 0.0, 0.0)
		var first: PackedInt32Array = pl[0]
		first.reverse()
		pl[0] = first
	for en in targets:
		if en == null or not is_instance_valid(en) or not en.health.is_alive():
			continue
		var delay: float = delay_of.call(en) if delay_of.is_valid() else 0.0
		var d := en.global_position - at
		rake.schedule(en, delay, pl[0], pl[1], d.normalized() if d.length_squared() > 0.01 else Vector2.DOWN)
	return rake


## 빈 긁기를 연다 (적은 뒤에 rake.schedule로: 별이 차례로 박히는 성좌진). 타 계획은 WaveRake.plan.
static func open(ctx: SkillContext, at: Vector2, interval: float, heavy: bool = false, sfx: StringName = &"") -> WaveRake:
	var rake := WaveRake.standalone(ctx, at, interval)
	rake.heavy_ticks = heavy
	rake.sfx = sfx
	rake.keep_cast_mult = true  # 나눠도 판정은 누른 순간 하나 (처벌·반격 배율 그대로)
	return rake


## 살아 있는 적만 (죽어서 지워지기 전인 적은 밀지도 세지도 않는다).
static func alive(list: Array) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in list:
		var en := e as Enemy
		if en and is_instance_valid(en) and en.health.is_alive():
			out.append(en)
	return out
