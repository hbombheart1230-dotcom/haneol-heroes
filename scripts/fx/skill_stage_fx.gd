class_name SkillStageFx
extends RefCounted
## 기술 연출 진입점 (SkillContext가 부른다). Feedback이 없으면 아무 일도 안 함 → 테스트 안전.
## 그리기는 Feedback.decals 아래의 VfxPieces·VfxGround, 수치는 SkillStageFeel.


static func _pieces() -> VfxPieces:
	var f := Feedback.instance
	return f.decals.pieces if f and f.decals else null


## 맞은 자리: 베인 자국 + 피해 비례로 화면을 맞은 방향으로 밀고 조금 흔든다 + 기술 타격 소리 층.
static func on_hit(d: SkillVfxData, pos: Vector2, dir: Vector2, damage: int, level: int, sfx: StringName = &"") -> void:
	var f := Feedback.instance
	if f == null:
		return
	if sfx != &"":
		f.play(sfx, 0.05)
	var p := _pieces()
	if p and d:
		p.hit_mark(d, pos, dir, level)
	var st := SkillStageFeel.get_default()
	f.kick(dir, st.kick_for(damage))
	var im := f.feel.impact_data()  # 여러 번 맞아도 흔들림이 쌓여 넘치지 않게 (ImpactFx.capped_trauma)
	f.add_trauma(ImpactFx.capped_trauma(f.trauma, st.trauma_for(damage), im.trauma_cap), dir)


## 발동 순간: 큰 기술 컷인 + 기술 소리 층.
static func on_cast(tree: SceneTree, d: SkillDef, hero: HeroData) -> void:
	if d == null:
		return
	SkillCutin.play(tree, d, hero)
	play_all(d.sfx_layers)


static func play_all(kinds: Array[StringName]) -> void:
	if Feedback.instance == null:
		return
	for k in kinds:
		Feedback.instance.play(k, 0.0)


static func play(kind: StringName, gap: float = 0.0) -> void:
	if Feedback.instance and kind != &"":
		Feedback.instance.play(kind, gap)


## 지연 기술의 예고: 기운이 가운데로 모인다.
static func gather(d: SkillVfxData, pos: Vector2, level: int) -> void:
	var p := _pieces()
	if p:
		p.gather(d, pos, level)


## 해시계 눈금 하나 번쩍 + 맑은 소리 (편경).
static func tick(d: SkillVfxData, center: Vector2, start: float, i: int, level: int) -> void:
	var p := _pieces()
	if p:
		p.tick_glint(d, center, start, i, level)
	if Feedback.instance and d.tick_sfx != &"":
		Feedback.instance.play(d.tick_sfx, 0.03)
