class_name DeathCause
extends RefCounted
## "무엇에 죽었는가": 새 속성 시스템 없이 처치한 영웅(지금 영웅)으로 속성을, 마지막 피해로 크기를 정한다 (DeathStyleData).
## 큰 처치 = 정예·보스 마무리, 근접 3타 강타, 센 피해 (CombatFeelData.big_hit_damage 이상: 기술·강타 대부분).

static var _layer: DeathFx


static func element_of(fb: Feedback) -> StringName:
	var hero := fb.player.hero if fb and fb.player else null
	return DeathStyleData.get_default().element_of(hero.id) if hero else &""


static func is_big(e: Enemy, last_damage: int, finisher: bool, feel: CombatFeelData) -> bool:
	return finisher or (e != null and e.heavy_pending) or (feel != null and last_damage >= feel.big_hit_damage)


## 그림 층 (Feedback.fx 아래에 처음 쓸 때 한 번 만든다).
static func layer(fb: Feedback) -> DeathFx:
	if fb == null or fb.fx == null or not fb.fx.is_inside_tree():
		return null
	if _layer == null or not is_instance_valid(_layer) or _layer.get_parent() != fb.fx:
		_layer = DeathFx.new(DeathStyleData.get_default())
		fb.fx.add_child(_layer)
	return _layer


## 처치 한 번: 속성이 있으면 그 모습을 터뜨리고 true (군대별 연기·종이는 생략).
static func burst(fb: Feedback, e: Enemy, last_damage: int, finisher: bool) -> bool:
	var el := element_of(fb)
	if el == &"" or e == null:
		return false
	var l := layer(fb)
	if l:
		l.burst(e.global_position, el, is_big(e, last_damage, finisher, fb.feel))
	return true
