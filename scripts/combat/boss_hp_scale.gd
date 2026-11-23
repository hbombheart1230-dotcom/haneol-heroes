class_name BossHpScale
extends RefCounted
## 영웅별 보스 체력 (HeroData.boss_hp_mult): 화력이 센 영웅은 보스 체력이 많게, 어느 영웅이 어느 무대에 가도 보스전 길이가 비슷하게.
## 난이도 단계(DifficultyCurve.scaled)와는 곱으로 겹친다. 원본 .tres는 건드리지 않고 사본을 돌려준다.


static func for_hero(boss: EnemyData, hero: HeroData) -> EnemyData:
	var k := mult(boss, hero)
	if is_equal_approx(k, 1.0):
		return boss
	var c := boss.duplicate() as EnemyData
	c.max_hp = maxi(1, roundi(boss.max_hp * k))
	return c


## 영웅 배율 × 보스별 궁합 (보스가 아니거나 영웅이 없으면 1).
static func mult(boss: EnemyData, hero: HeroData) -> float:
	if boss == null or hero == null or not (boss.is_boss or boss.boss_feel):  # 보스·중간 보스
		return 1.0
	return hero.boss_hp_mult * float(boss.boss_hp_by_hero.get(String(hero.id), 1.0))
