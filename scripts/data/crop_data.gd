class_name CropData
extends Resource

enum Rarity { COMMON, UNCOMMON, RARE, EPIC }

@export var id: StringName = &"carrot"
@export var display_name: String = "Carotte"
@export var base_grow_time: float = 4.0
## Prix unitaire de référence pour la vente directe.
@export var base_sell: int = 12
@export var color: Color = Color(0.95, 0.55, 0.2)
@export var rarity: Rarity = Rarity.COMMON
@export var unlock_prestige: int = 0


static func make(
	p_id: StringName,
	p_name: String,
	grow: float,
	sell: int,
	col: Color,
	p_rarity: Rarity = Rarity.COMMON,
	p_unlock_prestige: int = 0
) -> CropData:
	var c := CropData.new()
	c.id = p_id
	c.display_name = p_name
	c.base_grow_time = grow
	c.base_sell = sell
	c.color = col
	c.rarity = p_rarity
	c.unlock_prestige = p_unlock_prestige
	return c


func rarity_label() -> String:
	match rarity:
		Rarity.UNCOMMON:
			return "Peu commun"
		Rarity.RARE:
			return "Rare"
		Rarity.EPIC:
			return "Epique"
		_:
			return "Commun"


func rarity_short() -> String:
	match rarity:
		Rarity.UNCOMMON:
			return "PC"
		Rarity.RARE:
			return "R"
		Rarity.EPIC:
			return "E"
		_:
			return "C"
