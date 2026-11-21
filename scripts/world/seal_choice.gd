class_name SealChoice
extends Node2D
## 레벨업 강화 고르기: 게임을 멈추고 강화 카드 셋을 보여 준다 (UpgradeCards). 카드를 누르면 그 강화.
## 시간 제한 없음 (1차 시험 의견: "무슨 강화를 먹는지 모른다" → 걸어 들어가는 인장 대신 카드로).
## 큰 변형(정예 처치 보상)은 금빛 카드. 고르면 영웅 자리에서 터짐 + 강화 이름이 떠오른다 (RewardFx).

signal chosen(upgrade: UpgradeDef, major: bool)

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


func open(p_choices: Array[UpgradeDef], _center: Vector2, p_major: bool, p_stacks: Dictionary) -> void:
	if p_choices.is_empty():
		return
	if not is_open():
		_was_paused = get_tree().paused if is_inside_tree() else false
	choices = p_choices
	major = p_major
	stacks = p_stacks
	if is_inside_tree():
		get_tree().paused = true
	if cards:
		cards.open(choices, major, stacks)


func close() -> void:
	if not is_open():
		return
	choices = []
	if cards:
		cards.close()
	if is_inside_tree():
		get_tree().paused = _was_paused


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
		reward_fx.pickup(where, Ink.GOLD if was_major else u.color, u.title, u.description.split("\n")[0])
	if Feedback.instance:
		Feedback.instance.play(&"magic")
		Feedback.instance.haptic(60, 0.8)
	chosen.emit(u, was_major)
