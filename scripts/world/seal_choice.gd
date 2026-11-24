class_name SealChoice
extends Node2D
## 레벨업 강화 고르기: 게임을 멈추고 강화 카드 셋을 보여 준다 (UpgradeCards). 카드를 누르면 그 강화.
## 시간 제한 없음 (1차 시험 의견: "무슨 강화를 먹는지 모른다" → 걸어 들어가는 인장 대신 카드로).
## 큰 변형(정예 처치 보상)은 금빛 카드. 고르면 영웅 자리에서 터짐 + 강화 이름이 떠오른다 (RewardFx).

signal chosen(upgrade: UpgradeDef, major: bool)

## 패 화면이 떠 있는 동안 숨기는 전투 글자 무리 (연타 글씨·영웅 대사·물결 알림 등이 _ready에서 들어온다).
## 피해 숫자는 FxLayer.numbers_hidden으로.
const BATTLE_TEXT := &"battle_text"

@export var player: Player
@export var fx: FxLayer
## 고른 뒤 영웅 자리에서 터짐·글자.
@export var reward_fx: RewardFx
## 카드 화면이 그려지는 층 (HUD 위).
@export var card_layer: int = 5

var choices: Array[UpgradeDef] = []
var major: bool = false
## UpgradeDef.id → 이미 고른 횟수 (카드 아래 표시).
var stacks: Dictionary = {}
var cards: UpgradeCards
var _was_paused := false
var _hidden: Array[CanvasItem] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = card_layer
	add_child(layer)
	cards = UpgradeCards.new()
	layer.add_child(cards)
	cards.card_picked.connect(pick)


func is_open() -> bool:
	return not choices.is_empty()


func open(p_choices: Array[UpgradeDef], _center: Vector2, p_major: bool, p_stacks: Dictionary, gain: int = 1) -> void:
	if p_choices.is_empty():
		return
	if not is_open():
		_was_paused = get_tree().paused if is_inside_tree() else false
	choices = p_choices
	major = p_major
	stacks = p_stacks
	if is_inside_tree():
		get_tree().paused = true
		_hide_battle_text(true)
	if cards:
		cards.open(choices, major, stacks, gain)


func close() -> void:
	if not is_open():
		return
	choices = []
	if cards:
		cards.close()
	if is_inside_tree():
		get_tree().paused = _was_paused
	_hide_battle_text(false)


## 전투 글자를 숨기거나 (우리가 숨긴 것만) 되돌린다.
func _hide_battle_text(on: bool) -> void:
	FxLayer.numbers_hidden = on
	if not on:
		for n in _hidden:
			if is_instance_valid(n):
				n.visible = true
		_hidden.clear()
		return
	for n in get_tree().get_nodes_in_group(BATTLE_TEXT):
		var ci := n as CanvasItem
		if ci and ci.visible and not _hidden.has(ci):
			ci.visible = false
			_hidden.append(ci)


func _exit_tree() -> void:
	FxLayer.numbers_hidden = false


func pick(i: int) -> void:
	if i < 0 or i >= choices.size():
		return
	var u := choices[i]
	var was_major := major
	close()
	var where := player.global_position if player else global_position
	if fx:
		fx.add_ring(where, 100.0, 0.35, Ink.GOLD if was_major else u.color)
	if reward_fx:
		reward_fx.pickup(where, Ink.GOLD if was_major else u.color, u.title, u.description.split("\n")[0],
			&"gugak_jing" if was_major else &"gugak_buk")  # 강화 고르기 = 북 한 번, 큰 변형(정예·보스 보상) = 징
	if Feedback.instance:
		Feedback.instance.play(&"magic")
		Feedback.instance.haptic(60, 0.8)
	chosen.emit(u, was_major)
