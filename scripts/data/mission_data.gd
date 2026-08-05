class_name MissionData
extends RefCounted
## Commande client chronométrée, typée par un trait.

const TRAIT_EPICUREAN := &"epicurean"
const TRAIT_GOURMAND := &"gourmand"
const TRAIT_IMPATIENT := &"impatient"

var id: String
var client_name: String
var title: String
## crop_id (StringName) -> quantité demandée
var requirements: Dictionary = {}
var coin_reward: int
var xp_reward: int
var client_trait: StringName = TRAIT_GOURMAND
var time_left: float = 0.0
var time_max: float = 0.0
var client_face: int = 0
## Emplacement stable dans la liste (0..cap-1) — survit aux echecs / refresh.
var board_slot: int = -1


func _init(
	p_id: String,
	p_client: String,
	p_reqs: Dictionary,
	p_coins: int,
	p_xp: int,
	p_trait: StringName = TRAIT_GOURMAND,
	p_time: float = 60.0
) -> void:
	id = p_id
	client_name = p_client
	requirements = p_reqs.duplicate()
	coin_reward = p_coins
	xp_reward = p_xp
	client_trait = p_trait
	time_max = p_time
	time_left = p_time
	client_face = absi(p_client.hash()) % 12
	title = "Commande — %s" % client_name


func trait_label() -> String:
	match client_trait:
		TRAIT_EPICUREAN:
			return "Épicurien"
		TRAIT_GOURMAND:
			return "Gourmand"
		TRAIT_IMPATIENT:
			return "Impatient"
		_:
			return "Client"


func trait_color() -> Color:
	match client_trait:
		TRAIT_EPICUREAN:
			return Color(0.58, 0.36, 0.72) # violet
		TRAIT_GOURMAND:
			return Color(0.78, 0.48, 0.18) # ambre
		TRAIT_IMPATIENT:
			return Color(0.86, 0.34, 0.28) # corail
		_:
			return Color(0.45, 0.52, 0.45)


func total_needed() -> int:
	var n := 0
	for v in requirements.values():
		n += int(v)
	return n


func stock_toward(crop_id: StringName, stock: Dictionary) -> int:
	var need: int = int(requirements.get(crop_id, 0))
	if need <= 0:
		return 0
	return mini(need, int(stock.get(crop_id, 0)))


func filled_count(stock: Dictionary) -> int:
	var n := 0
	for crop_id in requirements:
		n += stock_toward(crop_id, stock)
	return n


func is_fulfillable(stock: Dictionary) -> bool:
	for crop_id in requirements:
		var need: int = int(requirements[crop_id])
		if int(stock.get(crop_id, 0)) < need:
			return false
	return true


func progress_text(stock: Dictionary) -> String:
	return "%d / %d" % [filled_count(stock), total_needed()]
