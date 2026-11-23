class_name LevelRules
extends Resource
## 한 판 안 레벨: 경험치 곡선(앞쪽에 몰림), 레벨업이 기술 모습을 올리는 간격, 숨 고르기의 카드 고르기 규칙.
## 판 안 레벨은 저장하지 않는다 (판마다 1부터). 데이터: data/runs/level_rules.tres.

## 레벨 n → n+1에 필요한 점수 (needs[n-1]). 배열을 넘으면 마지막 값 + tail_growth씩.
@export var needs: PackedInt32Array = PackedInt32Array([14, 18, 22, 26, 30, 34, 38, 42, 46])
@export var tail_growth: int = 4
## 모든 기술의 모습 단계(SkillDef.vfx_level) 보너스: vfx_first_level에 첫 +1 (기본 모습에 오래 머물지 않게,
## 첫 경지 오름 ≈ 10초), 그 뒤 vfx_every 레벨마다 +1. vfx_every 0이면 끔.
@export var vfx_first_level: int = 2
@export var vfx_every: int = 2
## 레벨이 이만큼 오를 때마다 영웅 능력치 상승(HeroData.level_up)을 한 번 적용. 0이면 끔.
@export var stats_every: int = 2

@export_group("패 (숨 고르기에서 고르기)")
## 숨 고르기 한 번에 고르는 최대 횟수 (연달아 카드가 너무 많이 뜨지 않게).
@export var picks_per_break: int = 2
## 숨 고르기 한 번에 쓰는 최대 카드 수. 고르는 횟수보다 많으면 마지막 고르기가 여러 단계를 올린다 (합침).
@export var cards_per_break: int = 3
## 보스 직전 숨 고르기: 남은 카드를 모두 쓴다. 이때 고르는 최대 횟수 (넘는 카드는 합침).
@export var last_break_picks: int = 3
## 숨 고르기에 카드가 이보다 적으면 채워 준다 (서툴러도 물결마다 최소 보장).
@export var min_cards_per_break: int = 1


func need(level: int) -> int:
	if needs.is_empty():
		return maxi(tail_growth * level, 1)
	var i := level - 1
	if i < needs.size():
		return maxi(needs[maxi(i, 0)], 1)
	return maxi(needs[needs.size() - 1] + tail_growth * (i - needs.size() + 1), 1)


## 이 레벨에서 기술 모습 단계 보너스 (레벨 1 = 0).
func vfx_bonus(level: int) -> int:
	if vfx_every <= 0 or level < vfx_first_level:
		return 0
	return 1 + (level - vfx_first_level) / vfx_every


## 이 레벨에 오른 순간 능력치 상승을 적용하는지.
func grants_stats(level: int) -> bool:
	return stats_every > 0 and level > 1 and (level - 1) % stats_every == 0


## 숨 고르기 하나의 고르기 계획: 고르기마다 오르는 단계 수 목록. banked = 적립된 카드, last = 보스 직전.
## 예 (기본값): 1장 → [1], 2장 → [1, 1], 4장 → [1, 2] (1장은 다음으로), 보스 직전 5장 → [2, 2, 1].
func plan(banked: int, last: bool) -> Array[int]:
	var cards := maxi(banked, min_cards_per_break)
	var picks := last_break_picks if last else picks_per_break
	if not last:
		cards = mini(cards, maxi(cards_per_break, 1))
	picks = clampi(picks, 1, maxi(cards, 1))
	var out: Array[int] = []
	if cards <= 0:
		return out
	for i in picks:
		out.append(cards / picks)
	for i in cards % picks:  # 나머지는 뒤쪽 고르기에 (합친 카드가 마지막에 크게)
		out[picks - 1 - i] += 1
	if last:
		out.sort()
		out.reverse()
	return out


## plan이 실제로 쓰는 카드 수 (보장으로 채운 몫 포함).
static func used(p: Array[int]) -> int:
	var n := 0
	for g in p:
		n += g
	return n
