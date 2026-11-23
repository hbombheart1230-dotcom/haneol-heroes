class_name RunBuild
extends RefCounted
## 이번 판 전용 영웅 수치 사본. 성장(UpgradeDef)을 여기에 적용한다.
## 원본 .tres는 공유 리소스라 건드리지 않는다 (다음 판·다른 노드에 번지지 않게).

var hero: HeroData
var player: Player
var caster: SkillCaster
var attack: AutoAttack


## 영웅 데이터를 복사해 플레이어·기술·기본 공격이 사본을 쓰게 연결한다.
## 내부 하위 리소스(기술·기본 공격·구성)만 복사하고 텍스처·스프라이트 시트는 공유한다.
func begin(p_player: Player, p_caster: SkillCaster, p_attack: AutoAttack) -> void:
	player = p_player
	caster = p_caster
	attack = p_attack
	if player == null or player.hero == null:
		return
	hero = player.hero.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL) as HeroData
	player.hero = hero
	if caster:
		caster.apply_kit(hero.kit)
	if attack:
		attack.data = hero.attack


func target_of(name: StringName) -> Object:
	if hero == null:
		return null
	match name:
		&"hero":
			return hero
		&"attack":
			return hero.attack
		&"kit":
			return hero.kit
		&"tap", &"dash", &"charge", &"counter":
			return hero.kit.get(name) if hero.kit else null
	return null


## 성장 하나를 적용한다. 알 수 없는 대상·속성은 건너뛰고 false.
func apply(u: UpgradeDef) -> bool:
	var ok := true
	var old_max_hp := hero.max_hp if hero else 0
	var touches_hero := false
	var leveled := {}
	for m in u.mods:
		var obj := target_of(m.target)
		if obj == null or not (m.property in obj):
			push_error("RunBuild: %s.%s 없음 (%s)" % [m.target, m.property, u.id])
			ok = false
			continue
		obj.set(m.property, m.apply_to(obj.get(m.property)))
		touches_hero = touches_hero or m.target == &"hero"
		if obj is SkillDef and not leveled.has(obj):  # 강화한 기술은 이펙트도 한 단계 화려하게
			leveled[obj] = true
			(obj as SkillDef).vfx_level += u.vfx_level_gain
	if touches_hero and player:
		player.refresh_stats(old_max_hp)
	if caster:
		caster.apply_kit(hero.kit)  # 입력 판정 시간(충전 등)은 캐시되므로 다시 읽힌다
	return ok


## 레벨이 올려 준 기술 모습 단계 (판 안 레벨 → LevelRules.vfx_bonus). 강화로 오른 단계와 더해진다.
var level_vfx: int = 0


## 레벨 보너스를 bonus로 맞춘다: 모든 기술의 모습 단계(SkillDef.vfx_level)에 차이만큼 더한다.
func set_level_vfx(bonus: int) -> void:
	var d := bonus - level_vfx
	if d == 0 or hero == null or hero.kit == null:
		return
	level_vfx = bonus
	for slot in [&"tap", &"dash", &"charge", &"counter"]:
		var sk := hero.kit.get(slot) as SkillDef
		if sk:
			sk.vfx_level = maxi(sk.vfx_level + d, 0)
