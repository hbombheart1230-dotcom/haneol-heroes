class_name FightRhythm
extends RefCounted
## 우두머리·중간 우두머리 싸움의 박자 확인 (test_boss_balance_sim, test_mid_boss): 막힘·묶임을 문제 목록으로 돌려준다.
## 막힘 = 휘청 시간을 뺀 공격 간격 (gaps_free). 그런데 휘청을 빼기만 하면 소환물이 우두머리를 계속 휘청이게 묶어도
## 통과하므로, 휘청 비율(boss_stun / time)과 맨 간격(gaps) 상한을 함께 둔다.

## 싸움 시간 중 우두머리가 휘청인 몫 상한.
const STUN_MAX := 0.35
## 휘청을 빼지 않은 공격 간격 상한(초): 이보다 길게 한 번도 치지 못하면 묶인 것.
const RAW_GAP_MAX := 15.0


static func stun_ratio(r: Dictionary) -> float:
	return float(r.get("boss_stun", 0.0)) / maxf(float(r["time"]), 0.1)


static func longest_gap(r: Dictionary) -> float:
	var g: Array = r.get("gaps", [])
	return 0.0 if g.is_empty() else float(g.max())


## 문제 목록 (비면 통과). free_max = 휘청을 뺀 간격 상한.
static func problems(r: Dictionary, label: String, free_max: float, raw_max: float = RAW_GAP_MAX, stun_max: float = STUN_MAX) -> Array[String]:
	var out: Array[String] = []
	for g in r.get("gaps_free", []):
		if float(g) >= free_max:
			out.append("%s stalled %.2fs" % [label, g])
	if longest_gap(r) >= raw_max:
		out.append("%s locked %.2fs" % [label, longest_gap(r)])
	if stun_ratio(r) > stun_max:
		out.append("%s stunned %.0f%%" % [label, stun_ratio(r) * 100.0])
	return out
