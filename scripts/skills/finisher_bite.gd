class_name FinisherBite
extends RefCounted
## 넷째 탭 마무리의 칼 박힘 (BladeBiteData 마무리 칸, 지금은 순신 해룡참): 기술이 처음 닿는 순간 한 번
## 멈춤(finisher_stop·finisher_stop_scale) + 흔들림 + 무거운 소리 + 진동, 풀릴 때 쉭 (release_sfx).
## 휘감기 기술은 적마다 멈추지 않으므로(defer_stop) 예전엔 마무리 멈춤이 끝 0.3배 느려짐뿐이었다
## (폴드 7 0570b0b "4타가 진동이랑 타격감이 없다", 사용자 (가) 1<2<3<4).

static var _last_ms: int = -1000000


## 이 발동에서 처음 닿았을 때만 (SkillContext._thud_done 앞에서 부른다). 반환: 멈췄으면 true.
static func on_contact(ctx: SkillContext, en: Enemy) -> bool:
	var b := ctx.finisher_bite
	if b == null or ctx.bite_done:
		return false
	ctx.bite_done = true
	var fb := Feedback.instance
	if fb:
		fb.add_trauma(b.finisher_contact_trauma, en.global_position - ctx.player.global_position)
		if b.finisher_contact_sfx != &"":
			fb.play(b.finisher_contact_sfx, 0.0)
		fb.haptic(b.finisher_haptic_ms, b.finisher_haptic_amp)
	var now := Time.get_ticks_msec()
	if not ctx.hit_stop_enabled or not ctx.player.is_inside_tree() or not gap_ok(now, _last_ms, b.finisher_min_gap):
		return false
	_last_ms = now
	var tree := ctx.player.get_tree()
	GameTime.stop(tree, b.finisher_stop, b.finisher_stop_scale)
	if b.release_sfx != &"" and fb:
		var kind := b.release_sfx
		var pitch := b.release_pitch
		tree.create_timer(b.finisher_stop, true, false, true).timeout.connect(func() -> void:
			if Feedback.instance:
				Feedback.instance.play(kind, 0.03, pitch))
	return true


## 순수: 앞 마무리 멈춤에서 gap초(실제)가 지났는지.
static func gap_ok(now_ms: int, last_ms: int, gap: float) -> bool:
	return now_ms - last_ms >= int(gap * 1000.0)


## 휘감기 끝 느려짐을 뺄지 (칼 박힘 마무리면 닿을 때 멈춤으로 바꿨다).
static func skips_sweep_slow(ctx: SkillContext) -> bool:
	return ctx.finisher_bite != null and ctx.finisher_bite.finisher_skip_sweep_slow


static func reset() -> void:
	_last_ms = -1000000
