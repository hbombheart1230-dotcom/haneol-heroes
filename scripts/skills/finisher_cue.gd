class_name FinisherCue
extends RefCounted
## 마무리 준비 표시 (SkillCaster가 부른다, 안 "가"): TapChain.finisher_armed — 실제로 다음 탭이 마무리인 조건 하나만 본다
## (표시가 뜨면 반드시 마무리가 나간다는 약속). 순신·광개토는 쿨타임 없이, 세종·사임당은 쿨타임 중이면 뜨지 않는다.

const DEFAULT := preload("res://data/feel/finisher_cue.tres")

var data: FinisherCueData = DEFAULT
var shown: bool = false
var _age: float = 0.0
var _fade: float = 0.0


## 매 물리 프레임. 반환: 이번에 켜졌으면 true (소리를 낸다).
func tick(c: SkillCaster, delta: float) -> bool:
	var want := data != null and data.enabled and c.player != null and not c.player.is_dead() \
		and c.kit != null and c.kit.tap_combo and TapChain.finisher_armed(c)
	_age += delta
	_fade = maxf(_fade - delta, 0.0)
	if want and not shown:
		shown = true
		_age = 0.0
		if data.sfx != &"" and Feedback.instance:
			Feedback.instance.play(data.sfx, 0.1, data.sfx_pitch)
		return true
	if not want and shown:
		shown = false
		_fade = data.fade_time if data else 0.0
	return false


## 발밑 고리 (SkillCaster._draw, 영웅 그림 아래).
func draw(c: SkillCaster) -> void:
	if data == null or (not shown and _fade <= 0.0):
		return
	var tex := data.art if data.art else Feedback.feel_data().ring_art
	var col := data.color
	if c.player and c.player.hero and data.hero_tint > 0.0:
		col = col.lerp(c.player.hero.body_color, data.hero_tint)
	var k := 1.0
	var a := data.alpha
	if shown:
		var pop := clampf(_age / maxf(data.pop_time, 0.001), 0.0, 1.0)
		k = lerpf(data.pop_scale, 1.0, 1.0 - pow(1.0 - pop, 2.0))
		var breath := sin(_age * TAU * data.pulse_hz) * data.pulse_amount
		k += breath
		a *= 1.0 + breath
	else:
		a *= _fade / maxf(data.fade_time, 0.001)
	var s := data.size * k
	var at := c.to_local(c.player.global_position) + data.offset
	if tex:
		for i in maxi(data.layers, 1):
			c.draw_texture_rect(tex, Rect2(at - Vector2(s, s * 0.5) * 0.5, Vector2(s, s * 0.5)), false, Color(col, a))
	else:
		c.draw_arc(at, s * 0.5, 0.0, TAU, 48, Color(col, a), 3.0)
