class_name EnemyAnswer
extends RefCounted
## 정답 표 계산 (EnemyAnswerData): 피해를 넣는 곳(평타·돌진 타격·기술)이 자기 조작 종류를 알려 주면 배율을 돌려준다.
## 견본: 한산 적만 데이터가 있다 (docs/research/enemy_answers.md). enabled를 끄면 모두 1배 (시뮬 비교용).

const COMBO := "combo"
const DASH := "dash"
const CHARGE := "charge"
const COUNTER := "counter"

static var enabled: bool = true


## 기술 칸 → 조작 종류 (TAP = 4타 마무리라 연타 쪽).
static func of_slot(slot: int) -> String:
	match slot:
		SkillCaster.Slot.TAP:
			return COMBO
		SkillCaster.Slot.DASH:
			return DASH
		SkillCaster.Slot.CHARGE:
			return CHARGE
		SkillCaster.Slot.COUNTER:
			return COUNTER
	return ""


## en에게 kind 조작으로 dmg를 넣을 때 실제 피해.
static func scaled(en: Enemy, kind: String, dmg: int) -> int:
	if not enabled or en == null or en.data == null or en.data.answer == null or kind == "":
		return dmg
	var a := en.data.answer
	return maxi(roundi(dmg * (a.mult if a.kind == kind else a.others_mult)), 1)


## 피해를 넣는 곳이 부른다: 배율을 곱한 피해 (scaled) + 화면·소리 표시 (AnswerCue, "통!"·"튕김").
static func apply(en: Enemy, kind: String, dmg: int) -> int:
	var out := scaled(en, kind, dmg)
	if enabled:
		AnswerCue.show(en, kind)
	return out


## 이 적의 정답 조작 ("" = 없음).
static func answer_of(en: Enemy) -> String:
	return en.data.answer.kind if en and en.data and en.data.answer else ""
