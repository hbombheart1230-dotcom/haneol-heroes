class_name AnswerCue
extends RefCounted
## 정답 표 표시 (AnswerCueData): EnemyAnswer.apply가 피해를 넣은 뒤 부른다. 맞는 수면 "통!", 갑옷이 덜 받으면 "튕김".
## 판정은 hit_kind (순수 함수, 시험), 그리기·소리는 Feedback이 있을 때만 (시뮬에서는 아무것도 안 한다).

const DEFAULT := preload("res://data/feel/answer_cue.tres")
enum Kind { NONE, HIT, DEFLECT }
const META := &"answer_cue_t"

static var data: AnswerCueData = DEFAULT
static var _layer: AnswerCueLayer


## kind 조작으로 en을 쳤을 때 보일 표시.
static func hit_kind(a: EnemyAnswerData, kind: String, d: AnswerCueData) -> Kind:
	if a == null or kind == "" or d == null or not d.enabled:
		return Kind.NONE
	if a.kind == kind:
		return Kind.HIT if a.mult > 1.0 else Kind.NONE
	return Kind.DEFLECT if a.others_mult < d.deflect_below else Kind.NONE


static func show(en: Enemy, kind: String) -> void:
	var fb := Feedback.instance
	if fb == null or fb.fx == null or en == null or not is_instance_valid(en) or en.data == null:
		return
	var k := hit_kind(en.data.answer, kind, data)
	if k == Kind.NONE:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var key := "%s_%d" % [META, k]
	if en.has_meta(key) and now - float(en.get_meta(key)) < data.per_enemy_gap:
		return
	en.set_meta(key, now)
	var pos := en.global_position + Vector2(0, -26)
	if k == Kind.HIT:
		layer(fb).add(pos, data.hit_label, data.hit_color, data.hit_size_mult)
		fb.fx.add_spark(pos + Vector2(0, -34), data.hit_color)
		fb.play(data.hit_sfx, 0.08, data.hit_pitch)
		fb.add_trauma(data.hit_trauma)
	else:
		layer(fb).add(pos, data.deflect_label, data.deflect_color, 1.0)
		fb.play(data.deflect_sfx, 0.1, data.deflect_pitch)


## 글자 층 (FxLayer 밑에 하나, 판이 바뀌면 새로).
static func layer(fb: Feedback) -> AnswerCueLayer:
	if _layer == null or not is_instance_valid(_layer) or _layer.get_parent() != fb.fx:
		_layer = AnswerCueLayer.new(data)
		_layer.name = "AnswerCueLayer"
		fb.fx.add_child(_layer)
	return _layer
