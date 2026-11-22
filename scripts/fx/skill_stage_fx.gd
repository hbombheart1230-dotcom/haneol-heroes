class_name SkillStageFx
extends RefCounted
## 기술 연출 진입점 (SkillContext가 부른다). Feedback이 없으면 아무 일도 안 함 → 테스트 안전.
## 그리기는 Feedback.decals 아래의 VfxPieces·VfxGround, 수치는 SkillStageFeel.


static func _pieces() -> VfxPieces:
	var f := Feedback.instance
	return f.decals.pieces if f and f.decals else null


## 맞은 자리: 베인 자국 + 피해 비례로 화면을 맞은 방향으로 밀고 조금 흔든다.
static func on_hit(d: SkillVfxData, pos: Vector2, dir: Vector2, damage: int, level: int) -> void:
	var f := Feedback.instance
	if f == null:
		return
	var p := _pieces()
	if p and d:
		p.hit_mark(d, pos, dir, level)
	var st := SkillStageFeel.get_default()
	f.kick(dir, st.kick_for(damage))
	f.add_trauma(st.trauma_for(damage), dir)


## 지연 기술의 예고: 기운이 가운데로 모인다.
static func gather(d: SkillVfxData, pos: Vector2, level: int) -> void:
	var p := _pieces()
	if p:
		p.gather(d, pos, level)


## 해시계 눈금 하나 번쩍 + 맑은 소리.
static func tick(d: SkillVfxData, center: Vector2, start: float, i: int, level: int) -> void:
	var p := _pieces()
	if p:
		p.tick_glint(d, center, start, i, level)
	if Feedback.instance:
		Feedback.instance.play(&"mat_glyph", 0.03)
