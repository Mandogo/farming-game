extends Node

signal money_changed(value: int)
signal xp_changed(current: int, required: int)
signal level_changed(level: int, skill_points: int)
signal prestige_points_changed(value: int)
signal missions_changed
signal boosts_changed
signal skills_changed
signal relics_changed
signal plots_changed
signal stock_changed
signal prestige_ready_changed(ready: bool)
signal toast(message: String)
signal harvested(plot_index: int, crop_id: StringName, amount: int)
signal combo_boost_changed
signal save_completed
signal tutorial_nudge(kind: StringName)
signal hard_reset_done
signal board_quests_changed

const GRID_W := 10
const GRID_H := 10
const MAX_PLOTS := GRID_W * GRID_H
const START_PLOTS := 1
const MAX_SPEED_LEVEL := 50
const MAX_CLICK_LEVEL := 40
const MAX_YIELD_LEVEL := 100
const SPEED_PER_LEVEL := 0.04
const DOUBLE_DROP_PER_LEVEL := 0.01
const CLICK_POWER_BASE := 1.0
const CLICK_POWER_PER_LEVEL := 0.1
const CLICK_POWER_TUTORIAL := 5.0
const AOE_CLICK_RATIO := 0.30
const MAX_ACTIVE_MISSIONS := 3
const ORDER_REFRESH_CD := 30.0
const ORDER_DURATION := 60.0
const ORDER_DURATION_IMPATIENT := 30.0
const TUTORIAL_ORDER_DURATION := 180.0
const PRESTIGE_LEVEL_REQUIRED := 10  # Seuil fixe à chaque prestige (plus de 20/30/…)
const PRESTIGE_LEVEL_STEP := 10  # legacy / docs
const PRESTIGE_POINTS_EARLY := 1  # P0→P9 : draft = récompense principale
const PRESTIGE_POINTS_AT_10 := 12  # 10ᵉ prestige : premier gros paquet reliques
const PRESTIGE_POINTS_LATE_BASE := 10  # P10+ : pts pour upgrader les reliques

## Courbe XP : ~8300 XP pour nv.10 → objectif 1er prestige ≈ 30 min (jeu engagé).
const XP_LEVEL_BASE := 200
const XP_LEVEL_GROWTH := 1.36
const RELIC_MAX_LEVEL := 5
const SAVE_PATH := "user://crop_express_save.json"
const SAVE_VERSION := 8
const FERTILIZER_GROW_MULT := 1.5
const FERTILIZER_BASE_COST := 180
const FERTILIZER_COST_GROWTH := 1.70
const FERTILIZER_MAX := 10
## Salve drone v1 — base : 8 cases autour (Chebyshev r=1) ; skills étendent via fertilizer_range()
const FERTILIZER_SALVO_INTERVAL := 2.0
const FERTILIZER_SALVO_SECONDS := 0.5
const GARDENER_BASE_COST := 260
const GARDENER_COST_GROWTH := 1.75
const GARDENER_MAX := 10
const GARDENER_INTERVAL_BASE := 2.0
const DELIVERY_COST := 2400
const DELIVERY_MAX := 1
const MACHINE_FERTILIZER := "fertilizer"
const MACHINE_GARDENER := "gardener"

## Combo livraisons — option A (seuil 4, fenêtre 12 s, boost 25 s ×2, CD ~105 s)
const COMBO_WINDOW := 12.0
const COMBO_WINDOW_WIDE := 16.0
const COMBO_NEEDED := 4
const COMBO_NEEDED_FLASH := 3
const COMBO_BOOST_DURATION := 25.0
const COMBO_BOOST_DURATION_LONG := 40.0
const COMBO_BOOST_MULT := 2.0
const COMBO_BOOST_MULT_POWER := 2.5
const COMBO_COOLDOWN := 105.0
const COMBO_COOLDOWN_FAST := 90.0
const COMBO_OVERFLOW_PER_HIT := 3.0
const COMBO_OVERFLOW_CAP := 15.0
const MONEY_START_BONUS := 50
const FREE_REFUSE_PER_RUN := 1
## Tuto : 0 actif · 3 terminé (étapes fines dérivées de l'état)
const TUTORIAL_ACTIVE := 0
const TUTORIAL_SELL := 1
const TUTORIAL_MISSIONS := 2
const TUTORIAL_DONE := 3
const TUTORIAL_CROP_IDS: Array[StringName] = [&"tomato", &"carrot", &"pepper"]
const TUTORIAL_ORDER_ID := "tut_intro"
const TUTORIAL_SELL_CROP := &"pepper"
const TUTORIAL_INTRO_QUEST_ID := "d_intro_sell"

var money: int = 40
var xp: int = 0
var xp_required: int = XP_LEVEL_BASE
var player_level: int = 1
var skill_points: int = 0
var skill_points_spent: int = 0
var prestige_level: int = 0
var prestige_points: int = 0

var speed_level: int = 0
var click_level: int = 0
var yield_level: int = 0
## Jetons terre possédés (placement libre sur grille 10×10)
var unlocked_plots: int = START_PLOTS
var fertilizer_owned: int = 0
var gardener_owned: int = 0
var delivery_owned: int = 0
var _gardener_timer: float = 0.0
var terrain_edit_seen: bool = false

## Compétences (arbre XP) — reset au prestige
var skills_owned: Dictionary = {}
var combo_overflow_gained: float = 0.0
var free_refuses_left: int = 0
var prestige_keep_pc: bool = false

## Reliques permanentes — id → niveau (1…RELIC_MAX_LEVEL)
var relic_levels: Dictionary = {}

var selected_crop_index: int = 0
var crops: Array[CropData] = []
var missions: Array[MissionData] = []
var mission_index: int = 0
var order_refresh_slots: Array = []

## Stats + missions board (onglet Missions)
var run_stats: Dictionary = {}
var lifetime_stats: Dictionary = {}
var board_quests: Array = []
var board_day_key: String = ""
var board_week_key: String = ""
const BOARD_BALANCE_VERSION := 4
var board_balance_version: int = 0
var stock: Dictionary = {}

var combo_count: int = 0
var combo_window_left: float = 0.0
var combo_boost_left: float = 0.0
var combo_cooldown_left: float = 0.0

var tutorial_step: int = TUTORIAL_ACTIVE
## Legacy save flag (migré vers tutorial_step)
var tutorial_grow_seen: bool = false

## Plot: unlocked (= terre placée), crop, grown, ready, auto_plant_id, machine
var plots: Array = []

var _boost_costs := {
	"speed": 30,
	"click": 40,
	"yield": 30,
	"plot": 10,
}

const _CLIENT_NAMES := [
	"Boulanger", "Carrossier", "Fleuriste", "Épicier", "Cuisinier",
	"Maraîcher", "Fromager", "Traiteur", "Poissonnier", "Pâtissier",
	"Jardinier", "Caviste", "Primeur", "Cantinier", "Barista",
	"Hôtelier", "Infirmier", "Professeur", "Mécanicien", "Pharmacien",
]

const _SKILL_ORDER := [
	"root_hub",
	"combo_flash", "combo_boost", "combo_cd", "combo_master",
	"xp_mission", "xp_curve", "xp_mission_2", "xp_prestige_prep",
	"order_time", "order_slots", "order_flow", "order_refuse",
	"money_mission", "money_shop", "money_start", "money_crit",
	"atelier_gears", "atelier_long_arms", "atelier_wide_tour", "atelier_live_chain", "atelier_network",
]

const _SKILL_DEFS := {
	"root_hub": {
		"title": "Serre ouverte", "short": "Serre",
		"desc": "Hub de run : +10 % or et +10 % XP sur les livraisons. Point de départ de ta spé.",
		"cost": 1, "icon": "ui_logo", "parent": "", "branch": "trunk", "hub": true,
	},
	## Combo — spé Rythme / burst
	"combo_flash": {
		"title": "Combo Flash", "short": "Flash",
		"desc": "Spé Combo : seuil 4 → 3 livraisons. Enchaîne plus vite la Frénésie.",
		"cost": 2, "icon": "ui_combo", "parent": "root_hub", "branch": "combo",
	},
	"combo_boost": {
		"title": "Frénésie", "short": "Frénésie",
		"desc": "Capstone burst : fenêtre 16 s · boost ×2,5 · durée 40 s.",
		"cost": 2, "icon": "ui_shop_speed", "parent": "combo_flash", "branch": "combo",
	},
	"combo_cd": {
		"title": "Relance rapide", "short": "Relance",
		"desc": "Spé Combo : cooldown 105 → 90 s. Plus de fenêtres par run.",
		"cost": 2, "icon": "ui_chrono", "parent": "combo_flash", "branch": "combo",
	},
	"combo_master": {
		"title": "Enchaînement", "short": "Enchaîne",
		"desc": "Capstone Combo : pendant le boost, +3 s / livraison (max +15 s).",
		"cost": 3, "icon": "ui_combo", "parent": "combo_flash", "branch": "combo",
	},
	## XP — spé Race prestige
	"xp_mission": {
		"title": "Savoir maraîcher", "short": "Savoir",
		"desc": "Spé XP : +20 % XP livraisons. Race vers le prochain prestige.",
		"cost": 2, "icon": "ui_xp", "parent": "root_hub", "branch": "xp",
	},
	"xp_curve": {
		"title": "Apprentissage", "short": "Courbe",
		"desc": "Spé XP : XP requise −15 %. Niveaux plus rapides.",
		"cost": 2, "icon": "ui_xp", "parent": "xp_mission", "branch": "xp",
	},
	"xp_mission_2": {
		"title": "Grand savoir", "short": "Grand",
		"desc": "Spé XP : +20 % XP encore. Stack avec Savoir.",
		"cost": 2, "icon": "ui_xp", "parent": "xp_mission", "branch": "xp",
	},
	"xp_prestige_prep": {
		"title": "Ambition", "short": "Ambition",
		"desc": "Capstone XP : au prestige, conserve 1 PC pour démarrer ta prochaine spé.",
		"cost": 3, "icon": "ui_coin_prestige", "parent": "xp_mission", "branch": "xp",
	},
	## Commandes — spé Logisticien
	"order_time": {
		"title": "Clients patients", "short": "Patients",
		"desc": "Spé Commandes : +30 % durée. Moins de stress chrono.",
		"cost": 2, "icon": "ui_chrono", "parent": "root_hub", "branch": "orders",
	},
	"order_slots": {
		"title": "Carnet rempli", "short": "Carnet",
		"desc": "Duo logisticien : +1 commande active max.",
		"cost": 2, "icon": "ui_mission", "parent": "order_time", "branch": "orders",
	},
	"order_flow": {
		"title": "Bouche à oreille", "short": "Flux",
		"desc": "Spé Commandes : refresh −25 %. Plus de volume.",
		"cost": 2, "icon": "ui_truck", "parent": "order_time", "branch": "orders",
	},
	"order_refuse": {
		"title": "File sélective", "short": "Refus",
		"desc": "Duo logisticien : 1 refus / run sans long refresh.",
		"cost": 1, "icon": "ui_btn_cancel", "parent": "order_time", "branch": "orders",
	},
	## Or — spé Marchand
	"money_mission": {
		"title": "Négociant", "short": "Négocé",
		"desc": "Spé Or : +20 % or livraisons. Snowball boutique.",
		"cost": 2, "icon": "ui_shop_money", "parent": "root_hub", "branch": "money",
	},
	"money_shop": {
		"title": "Soldeur", "short": "Soldeur",
		"desc": "Duo marchand : coûts boutique −8 %.",
		"cost": 2, "icon": "ui_tab_shop", "parent": "money_mission", "branch": "money",
	},
	"money_start": {
		"title": "Caisse de départ", "short": "Départ",
		"desc": "Spé Or : +50 or immédiatement à l’achat.",
		"cost": 2, "icon": "ui_coin", "parent": "money_mission", "branch": "money",
	},
	"money_crit": {
		"title": "Pourboire", "short": "Pourboire",
		"desc": "Capstone marchand : 10 % chance de doubler l’or d’une livraison.",
		"cost": 3, "icon": "ui_sparkle", "parent": "money_mission", "branch": "money",
	},
	## Atelier — spé Machines
	"atelier_gears": {
		"title": "Rouages", "short": "Rouages",
		"desc": "Spé Machines : coûts d’achat machines −12 %.",
		"cost": 2, "icon": "ui_auto_planter", "parent": "root_hub", "branch": "atelier",
	},
	"atelier_long_arms": {
		"title": "Bras longs", "short": "Bras",
		"desc": "Portée des fertiliseurs +1.",
		"cost": 2, "icon": "ui_fertilizer", "parent": "atelier_gears", "branch": "atelier",
	},
	"atelier_wide_tour": {
		"title": "Tournée large", "short": "Tournée",
		"desc": "Portée des jardiniers +1.",
		"cost": 2, "icon": "ui_auto_harvester", "parent": "atelier_gears", "branch": "atelier",
	},
	"atelier_live_chain": {
		"title": "Chaîne vive", "short": "Chaîne",
		"desc": "Jardiniers : délai de tournée −20 % (2,0 s → 1,6 s).",
		"cost": 2, "icon": "ui_chrono", "parent": "atelier_gears", "branch": "atelier",
	},
	"atelier_network": {
		"title": "Réseau", "short": "Réseau",
		"desc": "Capstone Atelier : +1 portée fertiliseurs et jardiniers.",
		"cost": 3, "icon": "ui_auto_delivery", "parent": "atelier_gears", "branch": "atelier",
	},
}

const _RELIC_ORDER := [
	"green_thumb", "fertile_soil", "bountiful", "deep_roots",
	"golden_receipt", "green_ledger", "pulse_tempo", "open_gate",
	"seed_bank", "machine_oil",
]

const _RELIC_DEFS := {
	"green_thumb": {
		"title": "Main Verte",
		"desc": "Puissance de clic permanente +10 % / niveau.",
		"icon": "ui_green_thumb", "tag": "Farm",
	},
	"fertile_soil": {
		"title": "Terre Fertile",
		"desc": "Vitesse de pousse permanente +6 % / niveau.",
		"icon": "ui_shop_speed", "tag": "Farm",
	},
	"bountiful": {
		"title": "Corne d’abondance",
		"desc": "Chance de double drop permanente +3 % / niveau.",
		"icon": "ui_shop_frenzy", "tag": "Farm",
	},
	"deep_roots": {
		"title": "Racines profondes",
		"desc": "+1 parcelle au départ (niv.1), encore +1 aux niv.3 et 5.",
		"icon": "ui_shop_plot", "tag": "Farm",
	},
	"golden_receipt": {
		"title": "Ticket doré",
		"desc": "Or des livraisons +5 % / niveau (permanent).",
		"icon": "ui_shop_money", "tag": "Livraison",
	},
	"green_ledger": {
		"title": "Carnet vert",
		"desc": "XP des livraisons +5 % / niveau (permanent).",
		"icon": "ui_xp", "tag": "Livraison",
	},
	"pulse_tempo": {
		"title": "Tempo de livraison",
		"desc": "+1 s de fenêtre combo / niv. Seuil −1 dès niv.2.",
		"icon": "ui_combo", "tag": "Livraison",
	},
	"open_gate": {
		"title": "Portail clients",
		"desc": "Durée commandes +4 % / niv (niv.1–2). +1 slot dès niv.3.",
		"icon": "ui_mission", "tag": "Livraison",
	},
	"seed_bank": {
		"title": "Banque de graines",
		"desc": "Cultures prestige débloquées 1 palier plus tôt.",
		"icon": "ui_logo", "tag": "Meta",
	},
	"machine_oil": {
		"title": "Huile de machine",
		"desc": "Coûts boutique −3 % / niv (puis rayon machines).",
		"icon": "ui_fertilizer", "tag": "Meta",
	},
}


func _ready() -> void:
	_init_crops()
	_init_stats()
	if not load_game():
		_reset_run(false)
		_refill_missions()
		ensure_board_quests(true)
	else:
		ensure_board_quests(false)
	call_deferred("_autosave_loop")


func _init_stats() -> void:
	run_stats = _empty_stats()
	lifetime_stats = _empty_stats()


func _empty_stats() -> Dictionary:
	return {
		"orders": 0,
		"harvested": 0,
		"sold_items": 0,
		"gold_orders": 0,
		"gold_sold": 0,
	}


func _autosave_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(12.0).timeout
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()


func _process(delta: float) -> void:
	_tick_plots(delta)
	_tick_gardeners(delta)
	_tick_auto_delivery()
	_tick_order_timers(delta)
	_tick_order_refresh(delta)
	_tick_combo_boost(delta)


func _init_crops() -> void:
	# 6 légumes — temps longs ; 1–3 libres, 4@P1, 5@P3, 6@P6
	# base_sell volontairement bas : la vente directe est un filet, les commandes restent plus rentables.
	crops = [
		CropData.make(&"tomato", "Tomate", 20.0, 4, Color(0.9, 0.28, 0.22), CropData.Rarity.COMMON, 0),
		CropData.make(&"carrot", "Carotte", 28.0, 6, Color(0.95, 0.55, 0.18), CropData.Rarity.UNCOMMON, 0),
		CropData.make(&"pepper", "Poivron", 36.0, 9, Color(0.96, 0.78, 0.16), CropData.Rarity.RARE, 0),
		CropData.make(&"eggplant", "Aubergine", 48.0, 14, Color(0.48, 0.22, 0.58), CropData.Rarity.EPIC, 1),
		CropData.make(&"mushroom", "Champignon", 60.0, 20, Color(0.85, 0.42, 0.32), CropData.Rarity.EPIC, 3),
		CropData.make(&"broccoli", "Brocoli", 75.0, 28, Color(0.35, 0.72, 0.38), CropData.Rarity.EPIC, 6),
	]


func is_crop_unlocked(crop: CropData) -> bool:
	var need := crop.unlock_prestige
	if get_relic_level("seed_bank") >= 1 and need > 0:
		need = maxi(0, need - 1)
	return prestige_level >= need


func is_crop_id_unlocked(crop_id: StringName) -> bool:
	for c in crops:
		if c.id == crop_id:
			return is_crop_unlocked(c)
	return false


func unlocked_crops() -> Array[CropData]:
	var out: Array[CropData] = []
	for c in crops:
		if is_crop_unlocked(c):
			out.append(c)
	return out


func crop_unlock_hint(crop: CropData) -> String:
	var need := crop.unlock_prestige
	if get_relic_level("seed_bank") >= 1 and need > 0:
		need = maxi(0, need - 1)
	if need <= 0:
		return ""
	return "Prestige %d" % need


func _reset_run(from_prestige: bool) -> void:
	money = 40 if not from_prestige else 0
	xp = 0
	player_level = 1
	skill_points = 1 if prestige_keep_pc else 0
	prestige_keep_pc = false
	skill_points_spent = 0
	speed_level = 0
	click_level = 0
	yield_level = 0
	unlocked_plots = start_plots()
	fertilizer_owned = 0
	gardener_owned = 0
	delivery_owned = 0
	_gardener_timer = 0.0
	skills_owned.clear()
	combo_overflow_gained = 0.0
	free_refuses_left = 0
	xp_required = _xp_for_player_level(1)
	selected_crop_index = 0
	_clamp_selected_crop()
	mission_index = 0
	order_refresh_slots.clear()
	combo_count = 0
	combo_window_left = 0.0
	combo_boost_left = 0.0
	combo_cooldown_left = 0.0
	stock.clear()
	run_stats = _empty_stats()
	_boost_costs = {
		"speed": 30,
		"click": 40,
		"yield": 30,
		"plot": 10,
	}
	_build_plots()
	_place_starting_lands()
	if from_prestige:
		toast.emit("Nouveau contrat !")
	_emit_economy()
	boosts_changed.emit()
	skills_changed.emit()
	plots_changed.emit()
	prestige_ready_changed.emit(can_prestige())
	combo_boost_changed.emit()
	board_quests_changed.emit()


func _clamp_selected_crop() -> void:
	if selected_crop_index < 0 or selected_crop_index >= crops.size():
		selected_crop_index = 0
	if not is_crop_unlocked(crops[selected_crop_index]):
		for i in crops.size():
			if is_crop_unlocked(crops[i]):
				selected_crop_index = i
				return


func _emit_economy() -> void:
	money_changed.emit(money)
	xp_changed.emit(xp, xp_required)
	level_changed.emit(player_level, skill_points)
	stock_changed.emit()


func _build_plots() -> void:
	plots.clear()
	for _i in MAX_PLOTS:
		plots.append(_empty_plot(false))


func _empty_plot(unlocked: bool) -> Dictionary:
	return {
		"unlocked": unlocked,
		"crop": null,
		"grown": 0.0,
		"ready": false,
		"auto_plant_id": &"",
		"machine": "",
	}


func _place_starting_lands() -> void:
	## Place les jetons de départ en bas-centre (anneaux Chebyshev).
	for p in plots:
		p["unlocked"] = false
		p["crop"] = null
		p["grown"] = 0.0
		p["ready"] = false
		p["auto_plant_id"] = &""
		p["machine"] = ""
	var origin := Vector2i(int(GRID_W / 2), GRID_H - 3)
	var placed := 0
	for ring in range(0, 8):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				if placed >= unlocked_plots:
					return
				var col := origin.x + dx
				var row := origin.y + dy
				var idx := rc_to_index(col, row)
				if idx < 0:
					continue
				plots[idx]["unlocked"] = true
				placed += 1


func land_placed() -> int:
	var n := 0
	for p in plots:
		if p["unlocked"]:
			n += 1
	return n


func land_unplaced() -> int:
	return maxi(0, unlocked_plots - land_placed())


func is_terrain_edit_unlocked() -> bool:
	## Bouton Éditer : après le 1er achat de parcelle (au-delà du départ de run).
	return unlocked_plots > start_plots()


func _auto_place_one_land() -> bool:
	## Place 1 terre adjacente au champ existant (fallback : spirale bas-centre).
	if land_placed() >= unlocked_plots:
		return false
	var candidates: Array[int] = []
	for i in plots.size():
		if not plots[i]["unlocked"]:
			continue
		for ni in adjacent_indices(i, true):
			if plots[ni]["unlocked"]:
				continue
			if not candidates.has(ni):
				candidates.append(ni)
	if not candidates.is_empty():
		## Préférer la case la plus proche du centroïde du champ (compact).
		var cx := 0.0
		var cy := 0.0
		var n := 0
		for i in plots.size():
			if not plots[i]["unlocked"]:
				continue
			var rc := index_to_rc(i)
			cx += float(rc.x)
			cy += float(rc.y)
			n += 1
		if n > 0:
			cx /= float(n)
			cy /= float(n)
		var best := candidates[0]
		var best_d := 1.0e9
		for ci in candidates:
			var rc2 := index_to_rc(ci)
			var d := absf(float(rc2.x) - cx) + absf(float(rc2.y) - cy)
			if d < best_d:
				best_d = d
				best = ci
		plots[best]["unlocked"] = true
		plots[best]["machine"] = ""
		return true
	## Aucune adjacence (grille vide) : spirale de départ.
	var origin := Vector2i(int(GRID_W / 2), GRID_H - 3)
	for ring in range(0, 12):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var idx := rc_to_index(origin.x + dx, origin.y + dy)
				if idx < 0 or plots[idx]["unlocked"]:
					continue
				plots[idx]["unlocked"] = true
				plots[idx]["machine"] = ""
				return true
	return false


func machine_placed_count(machine_id: String) -> int:
	var n := 0
	for p in plots:
		if str(p.get("machine", "")) == machine_id:
			n += 1
	return n


func fertilizer_unplaced() -> int:
	return maxi(0, fertilizer_owned - machine_placed_count(MACHINE_FERTILIZER))


func gardener_unplaced() -> int:
	return maxi(0, gardener_owned - machine_placed_count(MACHINE_GARDENER))


func clear_all_crops_memory() -> void:
	for p in plots:
		p["crop"] = null
		p["grown"] = 0.0
		p["ready"] = false
		p["auto_plant_id"] = &""
	plots_changed.emit()


func snapshot_terrain_layout() -> Dictionary:
	var cells: Array = []
	for i in plots.size():
		var p: Dictionary = plots[i]
		cells.append({
			"unlocked": bool(p["unlocked"]),
			"machine": str(p.get("machine", "")),
		})
	return {
		"cells": cells,
		"unlocked_plots": unlocked_plots,
		"fertilizer_owned": fertilizer_owned,
		"gardener_owned": gardener_owned,
		"delivery_owned": delivery_owned,
	}


func apply_terrain_layout(snap: Dictionary) -> void:
	var cells = snap.get("cells", [])
	if typeof(cells) != TYPE_ARRAY:
		return
	for i in mini(cells.size(), plots.size()):
		var c: Dictionary = cells[i]
		var p: Dictionary = plots[i]
		var has_land := bool(c.get("unlocked", false))
		p["unlocked"] = has_land
		var mid := str(c.get("machine", ""))
		if not has_land:
			mid = ""
		if mid != MACHINE_FERTILIZER and mid != MACHINE_GARDENER:
			mid = ""
		p["machine"] = mid
		if not has_land:
			p["crop"] = null
			p["grown"] = 0.0
			p["ready"] = false
			p["auto_plant_id"] = &""
		elif mid == MACHINE_GARDENER:
			## Jardinier occupe la case : pas de culture sous la machine.
			p["crop"] = null
			p["grown"] = 0.0
			p["ready"] = false
	_gardener_timer = 0.0
	plots_changed.emit()
	save_game()


func reset_terrain_to_stock() -> Dictionary:
	## Style CoC : tout au stock, grille vide (jetons / machines conservés en stock).
	var draft := snapshot_terrain_layout()
	var cells: Array = []
	for _i in MAX_PLOTS:
		cells.append({"unlocked": false, "machine": ""})
	draft["cells"] = cells
	return draft


func _xp_for_player_level(level: int) -> int:
	## Niveau N → N+1 : BASE × GROWTH^(N-1). Total nv.1→10 ≈ 8300 XP.
	return maxi(1, int(float(XP_LEVEL_BASE) * pow(XP_LEVEL_GROWTH, maxi(0, level - 1)) * xp_curve_mult()))


func get_selected_crop() -> CropData:
	_clamp_selected_crop()
	return crops[selected_crop_index]


func click_power() -> float:
	## Pendant le tuto : +5 s par clic pour comprendre vite la boucle.
	if not is_tutorial_done():
		return CLICK_POWER_TUTORIAL
	var base := CLICK_POWER_BASE + float(click_level) * CLICK_POWER_PER_LEVEL
	var gt := get_relic_level("green_thumb")
	if gt > 0:
		base *= 1.0 + 0.10 * float(gt)
	return base


func grow_speed_mult() -> float:
	var m := 1.0 + float(speed_level) * SPEED_PER_LEVEL
	var fs := get_relic_level("fertile_soil")
	if fs > 0:
		m *= 1.0 + 0.06 * float(fs)
	if is_combo_boost_active():
		m *= combo_boost_mult()
	return m


func combo_needed() -> int:
	var n := COMBO_NEEDED_FLASH if has_skill("combo_flash") else COMBO_NEEDED
	if get_relic_level("pulse_tempo") >= 2:
		n = maxi(2, n - 1)
	return n


func combo_window_sec() -> float:
	var t := COMBO_WINDOW_WIDE if has_skill("combo_boost") else COMBO_WINDOW
	t += float(get_relic_level("pulse_tempo"))
	return t


func combo_boost_mult() -> float:
	return COMBO_BOOST_MULT_POWER if has_skill("combo_boost") else COMBO_BOOST_MULT


func combo_boost_duration_sec() -> float:
	return COMBO_BOOST_DURATION_LONG if has_skill("combo_boost") else COMBO_BOOST_DURATION


func combo_cooldown_sec() -> float:
	return COMBO_COOLDOWN_FAST if has_skill("combo_cd") else COMBO_COOLDOWN


func combo_progress() -> int:
	return clampi(combo_count, 0, combo_needed())


func combo_window_ratio() -> float:
	if combo_window_left <= 0.0:
		return 0.0
	return clampf(combo_window_left / combo_window_sec(), 0.0, 1.0)


func is_combo_boost_active() -> bool:
	return combo_boost_left > 0.0


func is_combo_ready() -> bool:
	return combo_boost_left <= 0.0 and combo_cooldown_left <= 0.0


func mission_money_mult() -> float:
	var m := 1.0
	if has_skill("root_hub"):
		m *= 1.10
	if has_skill("money_mission"):
		m *= 1.20
	var gr := get_relic_level("golden_receipt")
	if gr > 0:
		m *= 1.0 + 0.05 * float(gr)
	return m


func mission_xp_mult() -> float:
	var m := 1.0
	if has_skill("root_hub"):
		m *= 1.10
	if has_skill("xp_mission"):
		m *= 1.20
	if has_skill("xp_mission_2"):
		m *= 1.20
	var gl := get_relic_level("green_ledger")
	if gl > 0:
		m *= 1.0 + 0.05 * float(gl)
	return m


func xp_curve_mult() -> float:
	return 0.85 if has_skill("xp_curve") else 1.0


func order_duration_mult() -> float:
	var m := 1.30 if has_skill("order_time") else 1.0
	var og := get_relic_level("open_gate")
	if og > 0 and og < 3:
		m *= 1.0 + 0.04 * float(og)
	return m


func max_active_missions() -> int:
	var n := MAX_ACTIVE_MISSIONS
	if has_skill("order_slots"):
		n += 1
	if get_relic_level("open_gate") >= 3:
		n += 1
	return n


func order_refresh_sec() -> float:
	var t := ORDER_REFRESH_CD
	if has_skill("order_flow"):
		t *= 0.75
	return t


func shop_cost_mult() -> float:
	var m := 0.92 if has_skill("money_shop") else 1.0
	var oil := get_relic_level("machine_oil")
	if oil > 0:
		m *= maxf(0.70, 1.0 - 0.03 * float(oil))
	return m


func double_drop_chance() -> float:
	var c := float(yield_level) * DOUBLE_DROP_PER_LEVEL
	c += 0.03 * float(get_relic_level("bountiful"))
	return minf(1.0, c)


func harvest_amount() -> int:
	if randf() < double_drop_chance():
		return 2
	return 1


func deep_roots_bonus_plots() -> int:
	var lvl := get_relic_level("deep_roots")
	var n := 0
	if lvl >= 1:
		n += 1
	if lvl >= 3:
		n += 1
	if lvl >= 5:
		n += 1
	return n


func machine_oil_power_mult() -> float:
	## Stub pour le sprint machines (rayon / efficacité).
	return 1.0 + 0.10 * float(get_relic_level("machine_oil"))


func get_stock(crop_id: StringName) -> int:
	return int(stock.get(crop_id, 0))


func add_stock(crop_id: StringName, amount: int) -> int:
	if amount <= 0:
		return 0
	stock[crop_id] = get_stock(crop_id) + amount
	stock_changed.emit()
	missions_changed.emit()
	return 0


func remove_stock(crop_id: StringName, amount: int) -> bool:
	if get_stock(crop_id) < amount:
		return false
	var left := get_stock(crop_id) - amount
	if left <= 0:
		stock.erase(crop_id)
	else:
		stock[crop_id] = left
	stock_changed.emit()
	missions_changed.emit()
	return true


func get_crop(crop_id: StringName) -> CropData:
	for c in crops:
		if c.id == crop_id:
			return c
	return null


func unit_sell_price(crop_id: StringName) -> int:
	var crop := get_crop(crop_id)
	if crop == null:
		return 1
	return maxi(1, crop.base_sell)


func preview_sell_gold(crop_id: StringName, amount: int) -> int:
	return unit_sell_price(crop_id) * maxi(0, amount)


func sell_quick_amounts(stock_amt: int) -> Array[int]:
	## Boutons adaptés au stock : 1, 5, 10, 25, 50, 100 + tout.
	var out: Array[int] = []
	if stock_amt <= 0:
		return out
	for n in [1, 5, 10, 25, 50, 100]:
		if stock_amt >= n:
			out.append(n)
	if stock_amt > 1 and (out.is_empty() or out[out.size() - 1] != stock_amt):
		out.append(stock_amt)
	return out


func sell_crop_amount(crop_id: StringName, amount: int) -> int:
	if is_tutorial_sell_step():
		## Tuto : forcer la vente d'au moins 1 légume offert.
		pass
	elif not is_tutorial_done():
		toast.emit("Termine le tutoriel avant de vendre.")
		return 0
	amount = mini(amount, get_stock(crop_id))
	if amount <= 0:
		toast.emit("Stock vide.")
		return 0
	var crop := get_crop(crop_id)
	if crop == null:
		return 0
	if not remove_stock(crop_id, amount):
		return 0
	var gold := amount * unit_sell_price(crop_id)
	add_money(gold)
	_track_stat("sold_items", amount)
	_track_stat("gold_sold", gold)
	toast.emit("Vendu %dx %s : +%d or" % [amount, crop.display_name, gold])
	if is_tutorial_sell_step():
		_advance_tutorial_on_sell()
	save_game()
	return gold


func can_sell_now() -> bool:
	## Vente autorisée dès l’étape vente (et après).
	return tutorial_step >= TUTORIAL_SELL


func start_plots() -> int:
	return START_PLOTS + deep_roots_bonus_plots()


func max_plot_upgrades() -> int:
	return MAX_PLOTS - start_plots()


func plot_level() -> int:
	return maxi(0, unlocked_plots - start_plots())


func speed_pct() -> int:
	return int(speed_level * SPEED_PER_LEVEL * 100.0)


func yield_pct() -> int:
	return int(double_drop_chance() * 100.0)


func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)


func spend_money(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	money_changed.emit(money)
	return true


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	while xp >= xp_required:
		xp -= xp_required
		player_level += 1
		skill_points += 1
		xp_required = _xp_for_player_level(player_level)
		toast.emit("Niveau %d ! +1 Point de Compétence" % player_level)
	xp_changed.emit(xp, xp_required)
	level_changed.emit(player_level, skill_points)
	prestige_ready_changed.emit(can_prestige())


func plant_on_plot(index: int) -> bool:
	if index < 0 or index >= plots.size():
		return false
	var p: Dictionary = plots[index]
	if not p["unlocked"] or p["crop"] != null:
		return false
	if str(p.get("machine", "")) == MACHINE_GARDENER:
		toast.emit("Un jardinier occupe cette parcelle.")
		return false
	var crop := get_selected_crop()
	if not is_crop_unlocked(crop):
		toast.emit("Légume verrouillé.")
		return false
	if not is_tutorial_done():
		var need_id := tutorial_next_crop_id()
		if need_id == &"":
			toast.emit("Tuto — récolte ou livre la commande.")
			return false
		if crop.id != need_id:
			toast.emit("Tuto — plante uniquement : %s" % crop_display_name(need_id))
			return false
	p["crop"] = crop
	p["grown"] = 0.0
	p["ready"] = false
	p["auto_plant_id"] = crop.id
	plots_changed.emit()
	_advance_tutorial_on_plant(index)
	return true


func accelerate_plot(index: int, power_override: float = -1.0, from_player_click: bool = true, emit_change: bool = true) -> bool:
	if index < 0 or index >= plots.size():
		return false
	var p: Dictionary = plots[index]
	if not p["unlocked"]:
		return false
	if str(p.get("machine", "")) == MACHINE_GARDENER:
		return false
	if p["crop"] == null or p["ready"]:
		return false
	var power := click_power() if power_override < 0.0 else power_override
	var need := _plot_need(p, index)
	var was_ready := bool(p["ready"])
	p["grown"] = minf(need, float(p["grown"]) + power)
	if p["grown"] >= need:
		p["ready"] = true
		if not was_ready:
			_notify_first_crop_ready()
	if emit_change:
		plots_changed.emit()
	if from_player_click:
		_advance_tutorial_on_click()
	return true


func fertilizer_salvo_range() -> int:
	## Même portée que le passif (skills Bras longs / Réseau).
	return fertilizer_range()


func fertilizer_salvo_interval() -> float:
	return FERTILIZER_SALVO_INTERVAL


func fertilizer_salvo_seconds() -> float:
	return FERTILIZER_SALVO_SECONDS


func fertilizer_salvo_targets(source_index: int) -> Array[int]:
	## Toutes les terres en pousse dans le rayon Chebyshev (hors ancre machine).
	var out: Array[int] = []
	if source_index < 0 or source_index >= plots.size():
		return out
	var r := fertilizer_salvo_range()
	var rc_a := index_to_rc(source_index)
	for i in plots.size():
		if i == source_index:
			continue
		var p: Dictionary = plots[i]
		if not bool(p.get("unlocked", false)):
			continue
		if str(p.get("machine", "")) == MACHINE_GARDENER:
			continue
		if p.get("crop") == null or bool(p.get("ready", false)):
			continue
		var rc_b := index_to_rc(i)
		var d := maxi(absi(rc_a.x - rc_b.x), absi(rc_a.y - rc_b.y))
		if d > 0 and d <= r:
			out.append(i)
	return out


func harvest_plot(index: int) -> bool:
	if index < 0 or index >= plots.size():
		return false
	var p: Dictionary = plots[index]
	if p["crop"] == null or not p["ready"]:
		return false
	var crop: CropData = p["crop"]
	var amount := harvest_amount()
	add_stock(crop.id, amount)
	harvested.emit(index, crop.id, amount)
	_track_stat("harvested", amount)
	p["crop"] = null
	p["grown"] = 0.0
	p["ready"] = false
	plots_changed.emit()
	_advance_tutorial_on_harvest()
	return true


func harvest_all_ready() -> int:
	var count := 0
	for i in plots.size():
		if harvest_plot(i):
			count += 1
	return count


func grid_cols() -> int:
	return GRID_W


func index_to_rc(index: int) -> Vector2i:
	## x = col, y = row
	return Vector2i(index % GRID_W, int(index / GRID_W))


func rc_to_index(col: int, row: int) -> int:
	if col < 0 or row < 0 or col >= GRID_W or row >= GRID_H:
		return -1
	return row * GRID_W + col


func adjacent_indices(index: int, include_diag: bool = true) -> Array[int]:
	var rc := index_to_rc(index)
	var out: Array[int] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			if not include_diag and absi(dx) + absi(dy) != 1:
				continue
			var ni := rc_to_index(rc.x + dx, rc.y + dy)
			if ni >= 0:
				out.append(ni)
	return out


func chebyshev_ring_indices(center: int, range_r: int) -> Array[int]:
	## Anneau Chebyshev centre exclu : 0 < max(|dx|,|dy|) <= R
	var out: Array[int] = []
	if range_r <= 0 or center < 0 or center >= plots.size():
		return out
	var rc := index_to_rc(center)
	for dy in range(-range_r, range_r + 1):
		for dx in range(-range_r, range_r + 1):
			var d := maxi(absi(dx), absi(dy))
			if d <= 0 or d > range_r:
				continue
			var ni := rc_to_index(rc.x + dx, rc.y + dy)
			if ni >= 0:
				out.append(ni)
	return out


func fertilizer_range() -> int:
	var r := 1
	if has_skill("atelier_long_arms"):
		r += 1
	if has_skill("atelier_network"):
		r += 1
	return r


func gardener_range() -> int:
	var r := 1
	if has_skill("atelier_wide_tour"):
		r += 1
	if has_skill("atelier_network"):
		r += 1
	return r


func gardener_interval() -> float:
	var t := GARDENER_INTERVAL_BASE
	if has_skill("atelier_live_chain"):
		t *= 0.80
	return t


func machine_shop_cost_mult() -> float:
	var m := shop_cost_mult()
	if has_skill("atelier_gears"):
		m *= 0.88
	return m


func fertilizer_cover_mult(index: int) -> float:
	if index < 0 or index >= plots.size():
		return 1.0
	if not plots[index]["unlocked"]:
		return 1.0
	var r := fertilizer_range()
	for i in plots.size():
		if str(plots[i].get("machine", "")) != MACHINE_FERTILIZER:
			continue
		if not plots[i]["unlocked"]:
			continue
		var rc_a := index_to_rc(i)
		var rc_b := index_to_rc(index)
		var d := maxi(absi(rc_a.x - rc_b.x), absi(rc_a.y - rc_b.y))
		if d > 0 and d <= r:
			return FERTILIZER_GROW_MULT
	return 1.0


func range_overlay_flags(index: int) -> Dictionary:
	## Pour édition : {fertilizer: bool, gardener: bool} si la case terre est couverte.
	var flags := {"fertilizer": false, "gardener": false}
	if index < 0 or index >= plots.size() or not plots[index]["unlocked"]:
		return flags
	var fr := fertilizer_salvo_range()
	var gr := gardener_range()
	for i in plots.size():
		var mid := str(plots[i].get("machine", ""))
		if mid == "" or not plots[i]["unlocked"]:
			continue
		var rc_a := index_to_rc(i)
		var rc_b := index_to_rc(index)
		var d := maxi(absi(rc_a.x - rc_b.x), absi(rc_a.y - rc_b.y))
		if d <= 0:
			continue
		if mid == MACHINE_FERTILIZER and d <= fr:
			flags["fertilizer"] = true
		elif mid == MACHINE_GARDENER and d <= gr:
			flags["gardener"] = true
	return flags


func try_deliver_order(order_id: String, silent: bool = false) -> bool:
	for m in missions:
		if m.id != order_id:
			continue
		if not m.is_fulfillable(stock):
			if not silent:
				toast.emit("Stock insuffisant pour cette commande.")
			return false
		for crop_id in m.requirements:
			var need: int = int(m.requirements[crop_id])
			if not remove_stock(crop_id, need):
				if not silent:
					toast.emit("Erreur inventaire.")
				return false
		_claim_order(m, silent)
		return true
	return false


func cancel_order(order_id: String) -> bool:
	for i in missions.size():
		var m: MissionData = missions[i]
		if m.id != order_id:
			continue
		if is_tutorial_order(m):
			toast.emit("Termine d'abord la commande tutoriel.")
			return false
		missions.remove_at(i)
		if free_refuses_left > 0:
			free_refuses_left -= 1
			toast.emit("Refus gratuit — prochaine commande bientôt.")
			_refill_orders()
		else:
			_queue_order_refresh("refused")
			toast.emit("Commande refusee — prochaine dans %ds." % int(order_refresh_sec()))
		missions_changed.emit()
		return true
	return false


func _queue_order_refresh(reason: String) -> void:
	order_refresh_slots.append({
		"time": order_refresh_sec(),
		"reason": reason,
	})


func _tick_order_refresh(delta: float) -> void:
	if order_refresh_slots.is_empty():
		return
	var changed := false
	var i := 0
	while i < order_refresh_slots.size():
		order_refresh_slots[i]["time"] = float(order_refresh_slots[i]["time"]) - delta
		if float(order_refresh_slots[i]["time"]) <= 0.0:
			order_refresh_slots.remove_at(i)
			if _push_order():
				changed = true
		else:
			i += 1
	if changed:
		missions_changed.emit()


func _claim_order(m: MissionData, silent: bool = false) -> void:
	var money_gain := maxi(1, int(m.coin_reward * mission_money_mult()))
	var xp_gain := maxi(1, int(m.xp_reward * mission_xp_mult()))
	var tip := false
	if has_skill("money_crit") and randf() < 0.10:
		money_gain *= 2
		tip = true
	add_money(money_gain)
	add_xp(xp_gain)
	_track_stat("orders", 1)
	_track_stat("gold_orders", money_gain)
	if not silent:
		var tip_txt := "  ·  Pourboire !" if tip else ""
		toast.emit("Livre a %s (%s) : +%dor  ·  +%d xp%s" % [
			m.client_name, m.trait_label(), money_gain, xp_gain, tip_txt
		])
	var was_tutorial := is_tutorial_order(m)
	var remaining: Array[MissionData] = []
	for o in missions:
		if o.id != m.id:
			remaining.append(o)
	missions = remaining
	_register_delivery_for_combo()
	if was_tutorial and not is_tutorial_done():
		_advance_tutorial_on_deliver()
	else:
		_refill_orders()
	missions_changed.emit()


func _register_delivery_for_combo() -> void:
	if combo_boost_left > 0.0:
		if has_skill("combo_master") and combo_overflow_gained < COMBO_OVERFLOW_CAP:
			var add := minf(COMBO_OVERFLOW_PER_HIT, COMBO_OVERFLOW_CAP - combo_overflow_gained)
			combo_boost_left += add
			combo_overflow_gained += add
		combo_boost_changed.emit()
		return
	if combo_cooldown_left > 0.0:
		combo_boost_changed.emit()
		return
	combo_count = mini(combo_needed(), combo_count + 1)
	combo_window_left = combo_window_sec()
	if combo_count >= combo_needed():
		combo_count = 0
		combo_window_left = 0.0
		combo_boost_left = combo_boost_duration_sec()
		combo_cooldown_left = combo_cooldown_sec()
		combo_overflow_gained = 0.0
		toast.emit("Combo ! Pousse x%.1f pendant %ds" % [
			combo_boost_mult(), int(combo_boost_duration_sec())
		])
	combo_boost_changed.emit()


func _tick_combo_boost(delta: float) -> void:
	var was_active := combo_boost_left > 0.0
	var was_cd := combo_cooldown_left > 0.0
	var was_window := combo_window_left > 0.0
	var prev_count := combo_count

	if combo_boost_left > 0.0:
		combo_boost_left = maxf(0.0, combo_boost_left - delta)
	if combo_cooldown_left > 0.0:
		combo_cooldown_left = maxf(0.0, combo_cooldown_left - delta)
	if combo_window_left > 0.0 and combo_boost_left <= 0.0:
		combo_window_left = maxf(0.0, combo_window_left - delta)
		if combo_window_left <= 0.0 and combo_count > 0:
			combo_count = 0

	if (
		(was_active and combo_boost_left <= 0.0)
		or (was_cd and combo_cooldown_left <= 0.0)
		or (was_window and combo_window_left <= 0.0)
		or prev_count != combo_count
	):
		combo_boost_changed.emit()


func _plot_need(p: Dictionary, index: int = -1) -> float:
	if p["crop"] == null:
		return 1.0
	var crop: CropData = p["crop"]
	var speed := grow_speed_mult()
	if index >= 0:
		speed *= fertilizer_cover_mult(index)
	return crop.base_grow_time / maxf(0.01, speed)


func _tick_plots(delta: float) -> void:
	var changed := false
	for i in plots.size():
		var p: Dictionary = plots[i]
		if not p["unlocked"]:
			continue
		if str(p.get("machine", "")) == MACHINE_GARDENER:
			continue
		if p["crop"] == null or p["ready"]:
			continue
		var need: float = _plot_need(p, i)
		p["grown"] = minf(need, float(p["grown"]) + delta)
		if p["grown"] >= need:
			p["ready"] = true
			changed = true
			_notify_first_crop_ready()
	if changed:
		plots_changed.emit()


func _tick_gardeners(delta: float) -> void:
	if machine_placed_count(MACHINE_GARDENER) <= 0:
		_gardener_timer = 0.0
		return
	_gardener_timer += delta
	var interval := gardener_interval()
	var acted := false
	while _gardener_timer >= interval:
		_gardener_timer -= interval
		if _gardener_do_one_action():
			acted = true
		else:
			## Rien à faire — garder un léger surplus pour réagir vite
			_gardener_timer = minf(_gardener_timer, interval * 0.25)
			break
	if acted:
		plots_changed.emit()


func _gardener_do_one_action() -> bool:
	## 1 récolte+replante sur une terre PRÊTE dans la portée d'un jardinier.
	var gr := gardener_range()
	for gi in plots.size():
		if str(plots[gi].get("machine", "")) != MACHINE_GARDENER:
			continue
		if not plots[gi]["unlocked"]:
			continue
		for ti in chebyshev_ring_indices(gi, gr):
			var tp: Dictionary = plots[ti]
			if not tp["unlocked"] or str(tp.get("machine", "")) == MACHINE_GARDENER:
				continue
			if tp["crop"] == null or not tp["ready"]:
				continue
			var crop: CropData = tp["crop"]
			var amount := harvest_amount()
			add_stock(crop.id, amount)
			harvested.emit(ti, crop.id, amount)
			_track_stat("harvested", amount)
			var replant_id: StringName = tp.get("auto_plant_id", &"")
			tp["crop"] = null
			tp["grown"] = 0.0
			tp["ready"] = false
			if replant_id != &"":
				for c in crops:
					if c.id == replant_id and is_crop_unlocked(c):
						tp["crop"] = c
						tp["auto_plant_id"] = c.id
						break
			return true
	return false


func _tick_auto_delivery() -> void:
	if delivery_owned < 1:
		return
	var ids: Array[String] = []
	for m in missions:
		if m.is_fulfillable(stock):
			ids.append(m.id)
	if ids.is_empty():
		return
	var n := 0
	for oid in ids:
		if try_deliver_order(oid, true):
			n += 1
	if n > 0:
		toast.emit("Livreur auto : %d commande%s livrée%s." % [n, "s" if n > 1 else "", "s" if n > 1 else ""])
		missions_changed.emit()


func plot_remaining_seconds(index: int) -> float:
	if index < 0 or index >= plots.size():
		return 0.0
	var p: Dictionary = plots[index]
	if p["crop"] == null:
		return 0.0
	if p["ready"]:
		return 0.0
	var need := _plot_need(p, index)
	return maxf(0.0, need - float(p["grown"]))


func _advance_tutorial_on_plant(_index: int) -> void:
	if is_tutorial_done():
		return
	_emit_tutorial_guidance()


func _advance_tutorial_on_click() -> void:
	if is_tutorial_done():
		return
	_emit_tutorial_guidance()


func _notify_first_crop_ready() -> void:
	if is_tutorial_done():
		return
	tutorial_grow_seen = true
	_emit_tutorial_guidance()


func _advance_tutorial_on_harvest() -> void:
	if is_tutorial_done():
		return
	tutorial_grow_seen = true
	## Ne pas auto-sélectionner : le joueur doit changer de graine lui-même.
	_emit_tutorial_guidance()
	save_game()


func _advance_tutorial_on_deliver() -> void:
	if is_tutorial_done() or is_tutorial_sell_step() or is_tutorial_missions_step():
		return
	## Offre 1 poivron (dernière graine du tuto) à vendre via Stock.
	tutorial_step = TUTORIAL_SELL
	tutorial_grow_seen = true
	add_stock(TUTORIAL_SELL_CROP, 1)
	for i in crops.size():
		if crops[i].id == TUTORIAL_SELL_CROP:
			selected_crop_index = i
			break
	toast.emit("Tuto — Voici 1 %s : clique Stock sous le poivron pour vendre." % crop_display_name(TUTORIAL_SELL_CROP))
	tutorial_nudge.emit(&"sell")
	save_game()


func _advance_tutorial_on_sell() -> void:
	if not is_tutorial_sell_step():
		return
	## Après vente : montrer l’onglet Missions + claim de la quête intro.
	tutorial_step = TUTORIAL_MISSIONS
	tutorial_grow_seen = true
	_refill_orders()
	missions_changed.emit()
	board_quests_changed.emit()
	toast.emit("Tuto — Ouvre l’onglet Missions pour récupérer ta récompense.")
	tutorial_nudge.emit(&"missions_tab")
	save_game()


func _advance_tutorial_on_intro_claim() -> void:
	if not is_tutorial_missions_step():
		return
	tutorial_step = TUTORIAL_DONE
	tutorial_grow_seen = true
	## Mission découverte = tuto uniquement : on la retire du board.
	_remove_intro_board_quest()
	## Remet les commandes normales (vidées pendant le tuto).
	_refill_orders()
	missions_changed.emit()
	board_quests_changed.emit()
	toast.emit("Tutoriel terminé — bonne culture !")
	tutorial_nudge.emit(&"tutorial_done")
	save_game()


func _remove_intro_board_quest() -> void:
	var kept: Array = []
	for q in board_quests:
		if str(q.get("id", "")) != TUTORIAL_INTRO_QUEST_ID:
			kept.append(q)
	board_quests = kept


func is_tutorial_done() -> bool:
	return tutorial_step >= TUTORIAL_DONE


func is_tutorial_sell_step() -> bool:
	return tutorial_step == TUTORIAL_SELL


func is_tutorial_missions_step() -> bool:
	return tutorial_step == TUTORIAL_MISSIONS


func is_tutorial_order(m: MissionData) -> bool:
	return m != null and (m.id == TUTORIAL_ORDER_ID or m.id.begins_with("tut_"))


func has_tutorial_order() -> bool:
	for m in missions:
		if is_tutorial_order(m):
			return true
	return false


func get_tutorial_order() -> MissionData:
	for m in missions:
		if is_tutorial_order(m):
			return m
	return null


func tutorial_crop_growing_count(crop_id: StringName) -> int:
	var n := 0
	for p in plots:
		if not p["unlocked"]:
			continue
		var crop: CropData = p["crop"]
		if crop != null and crop.id == crop_id:
			n += 1
	return n


func tutorial_next_crop_id() -> StringName:
	## Prochaine des 3 graines manquantes pour la commande tuto.
	for crop_id in TUTORIAL_CROP_IDS:
		var have := get_stock(crop_id)
		var growing := tutorial_crop_growing_count(crop_id)
		if have + growing < 1:
			return crop_id
	return &""


func tutorial_has_ready_plot() -> bool:
	for p in plots:
		if p["unlocked"] and p["crop"] != null and p["ready"]:
			return true
	return false


func tutorial_has_growing_plot() -> bool:
	for p in plots:
		if p["unlocked"] and p["crop"] != null and not p["ready"]:
			return true
	return false


func tutorial_guidance_kind() -> StringName:
	if is_tutorial_done():
		return &""
	if is_tutorial_sell_step():
		return &"sell"
	if is_tutorial_missions_step():
		return &"missions_tab"
	_ensure_tutorial_order()
	var order := get_tutorial_order()
	if order != null and order.is_fulfillable(stock):
		return &"deliver"
	if tutorial_has_ready_plot():
		return &"harvest"
	if tutorial_has_growing_plot():
		return &"accelerate"
	var next_id := tutorial_next_crop_id()
	if next_id == &"":
		return &"deliver"
	_clamp_selected_crop()
	if crops[selected_crop_index].id != next_id:
		return &"switch_seed"
	return &"plant"


func _ensure_selected_tutorial_crop() -> void:
	var next_id := tutorial_next_crop_id()
	if next_id == &"":
		return
	for i in crops.size():
		if crops[i].id == next_id and is_crop_unlocked(crops[i]):
			selected_crop_index = i
			return


func crop_display_name(crop_id: StringName) -> String:
	for c in crops:
		if c.id == crop_id:
			return c.display_name
	return String(crop_id)


func _emit_tutorial_guidance() -> void:
	if is_tutorial_done():
		return
	var kind := tutorial_guidance_kind()
	if kind != &"":
		tutorial_nudge.emit(kind)


func maybe_emit_tutorial_start() -> void:
	if is_tutorial_done():
		return
	_ensure_tutorial_order()
	_emit_tutorial_guidance()


func _ensure_tutorial_order() -> void:
	if is_tutorial_done() or is_tutorial_sell_step() or is_tutorial_missions_step():
		return
	## Purge toute commande non-tuto + files d'attente.
	order_refresh_slots.clear()
	var kept: Array[MissionData] = []
	for m in missions:
		if is_tutorial_order(m):
			kept.append(m)
	missions = kept
	if has_tutorial_order():
		return
	_push_tutorial_order()


func unlock_next_plot() -> bool:
	## Achète + place auto une terre (réorga possible via Éditer ensuite).
	if unlocked_plots >= MAX_PLOTS:
		return false
	unlocked_plots += 1
	if not _auto_place_one_land():
		## Ne devrait pas arriver si MAX_PLOTS cohérent — rollback soft.
		unlocked_plots = maxi(start_plots(), unlocked_plots - 1)
		return false
	plots_changed.emit()
	return true


func buy_boost(boost_id: String) -> bool:
	if not _boost_costs.has(boost_id):
		return false
	var cost: int = get_boost_cost(boost_id)
	if not spend_money(cost):
		toast.emit("Pas assez d'argent.")
		return false
	var base_cost: int = int(_boost_costs[boost_id])
	match boost_id:
		"speed":
			if speed_level >= MAX_SPEED_LEVEL:
				add_money(cost)
				return false
			speed_level += 1
			_boost_costs[boost_id] = int(base_cost * 1.45)
		"click":
			if click_level >= MAX_CLICK_LEVEL:
				add_money(cost)
				return false
			click_level += 1
			_boost_costs[boost_id] = int(base_cost * 1.50)
		"yield":
			if yield_level >= MAX_YIELD_LEVEL:
				add_money(cost)
				return false
			yield_level += 1
			_boost_costs[boost_id] = int(base_cost * 1.45)
		"plot":
			if unlocked_plots >= MAX_PLOTS:
				add_money(cost)
				return false
			var first_extra := unlocked_plots <= start_plots()
			if not unlock_next_plot():
				add_money(cost)
				return false
			_sync_plot_boost_cost()
			toast.emit("Parcelle placée (%d/%d) — réorganise via Éditer si tu veux." % [land_placed(), unlocked_plots])
			if first_extra and not terrain_edit_seen:
				tutorial_nudge.emit(&"terrain_edit")
		_:
			add_money(cost)
			return false
	boosts_changed.emit()
	return true


func get_machine_cost(machine_id: String) -> int:
	var base := 0
	var owned := 0
	match machine_id:
		MACHINE_FERTILIZER:
			owned = fertilizer_owned
			if owned >= FERTILIZER_MAX:
				return 0
			base = int(round(float(FERTILIZER_BASE_COST) * pow(FERTILIZER_COST_GROWTH, float(owned))))
		MACHINE_GARDENER:
			owned = gardener_owned
			if owned >= GARDENER_MAX:
				return 0
			base = int(round(float(GARDENER_BASE_COST) * pow(GARDENER_COST_GROWTH, float(owned))))
		"delivery":
			if delivery_owned >= DELIVERY_MAX:
				return 0
			base = DELIVERY_COST
		_:
			return 0
	return maxi(1, int(ceil(float(base) * machine_shop_cost_mult())))


func can_buy_machine(machine_id: String) -> bool:
	match machine_id:
		MACHINE_FERTILIZER:
			return prestige_level >= 1 and fertilizer_owned < FERTILIZER_MAX
		MACHINE_GARDENER:
			return prestige_level >= 3 and gardener_owned < GARDENER_MAX
		"delivery":
			return prestige_level >= 5 and delivery_owned < DELIVERY_MAX
		_:
			return false


func buy_machine(machine_id: String) -> bool:
	if not can_buy_machine(machine_id):
		toast.emit("Machine verrouillée ou au maximum.")
		return false
	var cost := get_machine_cost(machine_id)
	if cost <= 0 or not spend_money(cost):
		toast.emit("Pas assez d'argent.")
		return false
	match machine_id:
		MACHINE_FERTILIZER:
			fertilizer_owned += 1
			toast.emit("Fertiliseur +1 — place-le via Éditer (%d/%d)" % [
				machine_placed_count(MACHINE_FERTILIZER), fertilizer_owned
			])
		MACHINE_GARDENER:
			gardener_owned += 1
			toast.emit("Jardinier +1 — place-le via Éditer (%d/%d)" % [
				machine_placed_count(MACHINE_GARDENER), gardener_owned
			])
		"delivery":
			delivery_owned += 1
			toast.emit("Livreur auto acquis — livre dès que le stock suffit.")
		_:
			add_money(cost)
			return false
	boosts_changed.emit()
	save_game()
	return true


func get_boost_cost(boost_id: String) -> int:
	return maxi(1, int(ceil(float(_boost_costs.get(boost_id, 9999)) * shop_cost_mult())))


func _sync_plot_boost_cost() -> void:
	## Courbe douce : 10 → 40, puis montée progressive qui se tasse en fin de grille.
	## Évite l’explosion endgame (×1.28^n devenait monstrueux vers 60+).
	var bought := maxi(0, unlocked_plots - START_PLOTS)
	if bought <= 0:
		_boost_costs["plot"] = 10
	elif bought == 1:
		_boost_costs["plot"] = 40
	else:
		## 40 + 18n + 1.2 n²  → ~p10≈340, p40≈2.7k, p60≈5.5k, p99≈14k
		var n := float(bought)
		_boost_costs["plot"] = maxi(40, int(40.0 + 18.0 * n + 1.2 * n * n))


func get_skill_def(skill_id: String) -> Dictionary:
	return _SKILL_DEFS.get(skill_id, {})


func skill_ids() -> Array:
	return _SKILL_ORDER.duplicate()


func skill_prerequisite(skill_id: String) -> String:
	return str(get_skill_def(skill_id).get("parent", ""))


func skill_prerequisites(skill_id: String) -> Array:
	var def := get_skill_def(skill_id)
	if def.has("parents_any"):
		return def["parents_any"]
	var p := str(def.get("parent", ""))
	if p.is_empty():
		return []
	return [p]


func skill_children(parent_id: String) -> Array:
	var out: Array = []
	for sid in _SKILL_ORDER:
		var def: Dictionary = _SKILL_DEFS[sid]
		if str(def.get("parent", "")) == parent_id:
			out.append(sid)
			continue
		if def.has("parents_any") and parent_id in def["parents_any"]:
			if not out.has(sid):
				out.append(sid)
	return out


func is_skill_branch_unlocked(skill_id: String) -> bool:
	if not _SKILL_DEFS.has(skill_id):
		return false
	var def: Dictionary = _SKILL_DEFS[skill_id]
	if def.has("parents_any"):
		for p in def["parents_any"]:
			if has_skill(str(p)):
				return true
		return false
	var prev := skill_prerequisite(skill_id)
	if prev.is_empty():
		return true
	return has_skill(prev)


func has_skill(skill_id: String) -> bool:
	return bool(skills_owned.get(skill_id, false))


func buy_skill(skill_id: String) -> bool:
	if has_skill(skill_id):
		return false
	if not is_skill_branch_unlocked(skill_id):
		var reqs := skill_prerequisites(skill_id)
		var names: PackedStringArray = []
		for p in reqs:
			names.append(str(get_skill_def(str(p)).get("title", p)))
		toast.emit("Débloque d'abord : %s" % " / ".join(names))
		return false
	var def: Dictionary = get_skill_def(skill_id)
	if def.is_empty():
		return false
	var cost: int = int(def.get("cost", 1))
	if skill_points < cost:
		toast.emit("Pas assez de Points de Compétence.")
		return false
	skill_points -= cost
	skill_points_spent += cost
	skills_owned[skill_id] = true
	_apply_skill_purchase(skill_id)
	level_changed.emit(player_level, skill_points)
	skills_changed.emit()
	boosts_changed.emit()
	prestige_ready_changed.emit(can_prestige())
	save_game()
	return true


func _apply_skill_purchase(skill_id: String) -> void:
	match skill_id:
		"combo_flash":
			toast.emit("Combo Flash : 3 livraisons suffisent !")
		"money_start":
			add_money(MONEY_START_BONUS)
			toast.emit("+%d or de caisse !" % MONEY_START_BONUS)
		"order_refuse":
			free_refuses_left = FREE_REFUSE_PER_RUN
		"order_slots":
			_refill_orders()
			missions_changed.emit()
		"xp_curve":
			xp_required = _xp_for_player_level(player_level)
			while xp >= xp_required:
				xp -= xp_required
				player_level += 1
				skill_points += 1
				xp_required = _xp_for_player_level(player_level)
				toast.emit("Niveau %d ! +1 Point de Compétence" % player_level)
			xp_changed.emit(xp, xp_required)
			level_changed.emit(player_level, skill_points)
			prestige_ready_changed.emit(can_prestige())
		_:
			pass


func can_prestige() -> bool:
	return player_level >= prestige_level_required()


func prestige_level_required() -> int:
	## Toujours nv.10 — accessible et prévisible à chaque run.
	return PRESTIGE_LEVEL_REQUIRED


func prestige_unlock_progress() -> String:
	return "Nv.%d / %d" % [player_level, prestige_level_required()]


func prestige_unlock_ratio() -> float:
	return clampf(
		float(player_level) / float(maxi(1, prestige_level_required())),
		0.0,
		1.0
	)


func calc_prestige_points_gain() -> int:
	if not can_prestige():
		return 0
	## Avant le 10ᵉ : 1 pt (le draft de relique compte le plus).
	## Au 10ᵉ (P9→P10) : gros bonus — collection souvent complète → upgrader.
	## Ensuite : paquet solide pour monter les niveaux de reliques.
	if prestige_level < 9:
		return PRESTIGE_POINTS_EARLY
	if prestige_level == 9:
		return PRESTIGE_POINTS_AT_10
	var gain := PRESTIGE_POINTS_LATE_BASE + (prestige_level - 10) * 2
	gain += maxi(0, (unlocked_plots - START_PLOTS) / 10)
	return maxi(PRESTIGE_POINTS_LATE_BASE, gain)


func do_prestige() -> void:
	## Legacy : prestige sans draft (tests). Préférer do_prestige_with_relic.
	if not can_prestige():
		toast.emit("Atteins le niveau %d pour débloquer le Prestige." % prestige_level_required())
		return
	var draft := build_relic_draft(1)
	var pick := draft[0] if not draft.is_empty() else "green_thumb"
	do_prestige_with_relic(pick)


func do_prestige_with_relic(relic_id: String) -> bool:
	if not can_prestige():
		toast.emit("Atteins le niveau %d pour débloquer le Prestige." % prestige_level_required())
		return false
	if not _RELIC_DEFS.has(relic_id):
		toast.emit("Relique invalide.")
		return false
	var points := calc_prestige_points_gain()
	prestige_keep_pc = has_skill("xp_prestige_prep")
	prestige_points += points
	prestige_level += 1
	var granted := grant_relic_from_draft(relic_id)
	prestige_points_changed.emit(prestige_points)
	toast.emit("+%d points de prestige !" % points)
	_reset_run(true)
	_refill_missions()
	missions_changed.emit()
	relics_changed.emit()
	_bump_board_on_prestige()
	save_game()
	if granted:
		var def: Dictionary = _RELIC_DEFS[relic_id]
		toast.emit("Relique : %s (niv.%d)" % [def.get("title", relic_id), get_relic_level(relic_id)])
	return true


## Remet toute la partie à zéro (run + prestige + reliques + tuto). Pour tests / plus tard joueurs.
func hard_reset_game() -> void:
	prestige_level = 0
	prestige_points = 0
	relic_levels.clear()
	prestige_keep_pc = false
	tutorial_step = TUTORIAL_ACTIVE
	tutorial_grow_seen = false
	run_stats = _empty_stats()
	lifetime_stats = _empty_stats()
	board_quests.clear()
	board_day_key = ""
	board_week_key = ""
	_reset_run(false)
	_refill_missions()
	ensure_board_quests(true)
	missions_changed.emit()
	relics_changed.emit()
	board_quests_changed.emit()
	prestige_points_changed.emit(prestige_points)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	save_game()
	toast.emit("Partie réinitialisée.")
	hard_reset_done.emit()


## ——— Debug cheats (F1 / build debug) ———

func debug_add_money(amount: int) -> void:
	if amount == 0:
		return
	add_money(amount)
	toast.emit("[Debug] Or %+d → %d" % [amount, money])
	save_game()


func debug_add_xp(amount: int) -> void:
	if amount <= 0:
		return
	## Level-ups silencieux pour gros dumps (évite spam toast).
	xp += amount
	var levels := 0
	while xp >= xp_required:
		xp -= xp_required
		player_level += 1
		skill_points += 1
		xp_required = _xp_for_player_level(player_level)
		levels += 1
	xp_changed.emit(xp, xp_required)
	level_changed.emit(player_level, skill_points)
	prestige_ready_changed.emit(can_prestige())
	if levels > 0:
		toast.emit("[Debug] +%d XP · +%d niv. → nv.%d (%d PC)" % [amount, levels, player_level, skill_points])
	else:
		toast.emit("[Debug] +%d XP" % amount)
	save_game()


func debug_set_player_level(target: int) -> void:
	target = maxi(1, target)
	if target == player_level:
		return
	if target > player_level:
		while player_level < target:
			player_level += 1
			skill_points += 1
			xp_required = _xp_for_player_level(player_level)
		xp = 0
	else:
		player_level = target
		xp = 0
		xp_required = _xp_for_player_level(player_level)
	xp_changed.emit(xp, xp_required)
	level_changed.emit(player_level, skill_points)
	prestige_ready_changed.emit(can_prestige())
	toast.emit("[Debug] Niveau → %d (%d PC)" % [player_level, skill_points])
	save_game()


func debug_add_skill_points(amount: int) -> void:
	if amount == 0:
		return
	skill_points = maxi(0, skill_points + amount)
	level_changed.emit(player_level, skill_points)
	toast.emit("[Debug] PC %+d → %d" % [amount, skill_points])
	save_game()


func debug_add_prestige_points(amount: int) -> void:
	if amount == 0:
		return
	prestige_points = maxi(0, prestige_points + amount)
	prestige_points_changed.emit(prestige_points)
	toast.emit("[Debug] Pts prestige %+d → %d" % [amount, prestige_points])
	save_game()


func debug_set_prestige_level(level: int) -> void:
	prestige_level = maxi(0, level)
	prestige_ready_changed.emit(can_prestige())
	toast.emit("[Debug] Prestige → P%d" % prestige_level)
	_clamp_selected_crop()
	plots_changed.emit()
	stock_changed.emit()
	save_game()


func debug_add_prestige_level(delta: int = 1) -> void:
	debug_set_prestige_level(prestige_level + delta)


func debug_unlock_all_plots() -> void:
	unlocked_plots = MAX_PLOTS
	for i in plots.size():
		plots[i]["unlocked"] = true
	_sync_plot_boost_cost()
	boosts_changed.emit()
	plots_changed.emit()
	toast.emit("[Debug] Toutes les parcelles débloquées")
	save_game()


func debug_max_shop() -> void:
	speed_level = MAX_SPEED_LEVEL
	click_level = MAX_CLICK_LEVEL
	yield_level = MAX_YIELD_LEVEL
	boosts_changed.emit()
	toast.emit("[Debug] Boutique maxée (vitesse / clic / yield)")
	save_game()


func debug_grant_relic(relic_id: String, to_level: int = 1) -> void:
	if not _RELIC_DEFS.has(relic_id):
		return
	to_level = clampi(to_level, 0, RELIC_MAX_LEVEL)
	if to_level <= 0:
		relic_levels.erase(relic_id)
	else:
		relic_levels[relic_id] = to_level
	relics_changed.emit()
	## deep_roots peut changer le départ — pas de reset run ici
	toast.emit("[Debug] %s → niv.%d" % [_RELIC_DEFS[relic_id].get("title", relic_id), to_level])
	save_game()


func debug_grant_all_relics(level: int = 1) -> void:
	level = clampi(level, 1, RELIC_MAX_LEVEL)
	for id in _RELIC_ORDER:
		relic_levels[id] = level
	relics_changed.emit()
	toast.emit("[Debug] Toutes les reliques au niv.%d" % level)
	save_game()


func debug_fill_stock(amount: int = 20) -> void:
	amount = maxi(1, amount)
	for c in crops:
		if is_crop_unlocked(c):
			add_stock(c.id, amount)
	toast.emit("[Debug] Stock +%d / culture débloquée" % amount)
	save_game()


func debug_skip_tutorial() -> void:
	tutorial_step = TUTORIAL_DONE
	tutorial_grow_seen = true
	toast.emit("[Debug] Tutoriel terminé")
	tutorial_nudge.emit(&"tutorial_done")
	save_game()


func debug_ready_all_plots() -> void:
	for i in plots.size():
		var p: Dictionary = plots[i]
		if not p["unlocked"] or p["crop"] == null:
			continue
		var need := _plot_need(p, i)
		p["grown"] = need
		p["ready"] = true
	plots_changed.emit()
	toast.emit("[Debug] Toutes les cultures prêtes")
	save_game()


func debug_instant_grow_field() -> void:
	## Plante (si vide) + mature instantanément toutes les parcelles débloquées.
	var crop := get_selected_crop()
	for i in plots.size():
		var p: Dictionary = plots[i]
		if not p["unlocked"]:
			continue
		if str(p.get("machine", "")) == MACHINE_GARDENER:
			continue
		if p["crop"] == null and crop != null and is_crop_unlocked(crop):
			p["crop"] = crop
			p["grown"] = 0.0
			p["ready"] = false
			p["auto_plant_id"] = crop.id
		if p["crop"] != null:
			var need := _plot_need(p, i)
			p["grown"] = need
			p["ready"] = true
	plots_changed.emit()
	toast.emit("[Debug] Champ mature instantané")
	save_game()


func debug_refill_orders() -> void:
	_refill_missions()
	missions_changed.emit()
	toast.emit("[Debug] Commandes rechargées")
	save_game()


func roll_relic() -> String:
	## Legacy — plus utilisé (draft prestige). Conservé pour compat.
	return ""


func build_relic_draft(count: int = 3) -> Array[String]:
	var unowned: Array[String] = []
	var owned_up: Array[String] = []
	var owned_max: Array[String] = []
	for id in _RELIC_ORDER:
		var lvl := get_relic_level(id)
		if lvl <= 0:
			unowned.append(id)
		elif lvl < RELIC_MAX_LEVEL:
			owned_up.append(id)
		else:
			owned_max.append(id)
	unowned.shuffle()
	owned_up.shuffle()
	owned_max.shuffle()
	var out: Array[String] = []
	for id in unowned:
		if out.size() >= count:
			break
		out.append(id)
	for id in owned_up:
		if out.size() >= count:
			break
		out.append(id)
	for id in owned_max:
		if out.size() >= count:
			break
		out.append(id)
	return out


func grant_relic_from_draft(relic_id: String) -> bool:
	if not _RELIC_DEFS.has(relic_id):
		return false
	if get_relic_level(relic_id) >= RELIC_MAX_LEVEL:
		toast.emit("%s est déjà au niveau max." % _RELIC_DEFS[relic_id].get("title", relic_id))
		return false
	_add_relic_level(relic_id)
	return true


func relic_upgrade_cost(relic_id: String) -> int:
	var lvl := get_relic_level(relic_id)
	if lvl <= 0 or lvl >= RELIC_MAX_LEVEL:
		return 0
	return lvl + 1


func upgrade_relic(relic_id: String) -> bool:
	var lvl := get_relic_level(relic_id)
	if lvl <= 0:
		toast.emit("Obtiens d’abord cette relique au prestige.")
		return false
	if lvl >= RELIC_MAX_LEVEL:
		toast.emit("Niveau maximum atteint.")
		return false
	var cost := relic_upgrade_cost(relic_id)
	if prestige_points < cost:
		toast.emit("Pas assez de points de prestige.")
		return false
	prestige_points -= cost
	prestige_points_changed.emit(prestige_points)
	_add_relic_level(relic_id)
	var def: Dictionary = _RELIC_DEFS.get(relic_id, {})
	toast.emit("%s améliorée (niv.%d)" % [def.get("title", relic_id), get_relic_level(relic_id)])
	relics_changed.emit()
	save_game()
	return true


func _add_relic_level(relic_id: String) -> void:
	if not _RELIC_DEFS.has(relic_id):
		return
	var cur := get_relic_level(relic_id)
	if cur >= RELIC_MAX_LEVEL:
		return
	relic_levels[relic_id] = cur + 1


func get_relic_level(relic_id: String) -> int:
	return int(relic_levels.get(relic_id, 0))


func relic_defs() -> Dictionary:
	return _RELIC_DEFS


func relic_order() -> Array:
	return _RELIC_ORDER


func relic_effect_summary(relic_id: String, level: int = -1) -> String:
	var lvl := level if level >= 0 else get_relic_level(relic_id)
	if lvl <= 0:
		var def: Dictionary = _RELIC_DEFS.get(relic_id, {})
		return str(def.get("desc", ""))
	match relic_id:
		"green_thumb":
			return "Clic ×%.0f %%" % (100.0 * (1.0 + 0.10 * float(lvl)))
		"fertile_soil":
			return "Pousse ×%.0f %%" % (100.0 * (1.0 + 0.06 * float(lvl)))
		"bountiful":
			return "Double drop +%d %%" % int(3 * lvl)
		"deep_roots":
			var bonus := 0
			if lvl >= 1:
				bonus += 1
			if lvl >= 3:
				bonus += 1
			if lvl >= 5:
				bonus += 1
			return "+%d parcelle%s au départ" % [bonus, "s" if bonus > 1 else ""]
		"golden_receipt":
			return "Or livraisons +%d %%" % int(5 * lvl)
		"green_ledger":
			return "XP livraisons +%d %%" % int(5 * lvl)
		"pulse_tempo":
			var extra := " · seuil −1" if lvl >= 2 else ""
			return "+%d s fenêtre combo%s" % [lvl, extra]
		"open_gate":
			if lvl >= 3:
				return "+1 commande max"
			return "Durée commandes +%d %%" % int(4 * lvl)
		"seed_bank":
			return "Cultures unlock −1 prestige"
		"machine_oil":
			return "Boutique −%d %% · machines +%d %%" % [int(3 * lvl), int(10 * lvl)]
		_:
			return ""

func _active_order_count() -> int:
	return missions.size()


func _tick_order_timers(delta: float) -> void:
	var changed := false
	var kept: Array[MissionData] = []
	var lost_tutorial := false
	for m in missions:
		m.time_left -= delta
		if m.time_left <= 0.0:
			if is_tutorial_order(m):
				lost_tutorial = true
			else:
				_queue_order_refresh("failed")
			changed = true
			continue
		kept.append(m)
	if changed:
		missions = kept
		if lost_tutorial and not is_tutorial_done():
			toast.emit("Temps écoulé — nouvelle commande tutoriel !")
			_push_tutorial_order()
		_refill_orders()
		missions_changed.emit()
		if not is_tutorial_done():
			_emit_tutorial_guidance()


func _refill_missions() -> void:
	missions.clear()
	order_refresh_slots.clear()
	_refill_orders()
	missions_changed.emit()


func _refill_orders() -> void:
	if not is_tutorial_done():
		## Tuto : une seule commande (Tuteur), rien d'autre.
		order_refresh_slots.clear()
		var kept: Array[MissionData] = []
		for m in missions:
			if is_tutorial_order(m):
				kept.append(m)
		missions = kept
		_ensure_tutorial_order()
		return
	var guard := 0
	var cap := max_active_missions()
	while _active_order_count() + order_refresh_slots.size() < cap and guard < 10:
		guard += 1
		if not _push_order():
			break


func _push_tutorial_order() -> bool:
	if has_tutorial_order():
		return false
	## 1 de chaque des 3 premières graines, chrono limité (Impatient).
	var reqs: Dictionary = {
		&"tomato": 1,
		&"carrot": 1,
		&"pepper": 1,
	}
	var rewards := _reward_for_reqs(reqs, MissionData.TRAIT_IMPATIENT)
	var m := MissionData.new(
		TUTORIAL_ORDER_ID,
		"Tuteur",
		reqs,
		rewards.x,
		rewards.y,
		MissionData.TRAIT_IMPATIENT,
		TUTORIAL_ORDER_DURATION
	)
	missions.append(m)
	return true


func _random_client() -> String:
	return _CLIENT_NAMES[randi() % _CLIENT_NAMES.size()]


func _unlocked_crop_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for c in unlocked_crops():
		ids.append(c.id)
	return ids


func _crop_tier_weight(crop_id: StringName) -> int:
	for c in crops:
		if c.id == crop_id:
			return 1 + c.unlock_prestige * 2
	return 1


func _random_trait() -> StringName:
	var traits: Array[StringName] = [
		MissionData.TRAIT_EPICUREAN,
		MissionData.TRAIT_GOURMAND,
		MissionData.TRAIT_IMPATIENT,
	]
	return traits[randi() % traits.size()]


func _reqs_for_trait(trait_id: StringName) -> Dictionary:
	var pool := _unlocked_crop_ids()
	if pool.is_empty():
		return {}
	pool.shuffle()
	var reqs: Dictionary = {}
	match trait_id:
		MissionData.TRAIT_EPICUREAN:
			var n := mini(3, pool.size())
			for i in n:
				reqs[pool[i]] = 2 + randi() % 2
		MissionData.TRAIT_GOURMAND:
			reqs[pool[0]] = 6 + randi() % 4
		MissionData.TRAIT_IMPATIENT:
			var n := mini(2, pool.size())
			for i in n:
				reqs[pool[i]] = 3 + randi() % 2
		_:
			reqs[pool[0]] = 3
	return reqs


func _time_for_trait(trait_id: StringName) -> float:
	var t := ORDER_DURATION_IMPATIENT if trait_id == MissionData.TRAIT_IMPATIENT else ORDER_DURATION
	return t * order_duration_mult()


func _reward_for_reqs(reqs: Dictionary, trait_id: StringName) -> Vector2i:
	## L'or de commande est toujours > vente directe des mêmes légumes.
	var sell_value := 0
	var weight := 0
	for crop_id in reqs:
		var amt: int = int(reqs[crop_id])
		sell_value += amt * unit_sell_price(crop_id)
		weight += amt * _crop_tier_weight(crop_id)
	## ~×1,8 la vente dump + petit flat prestige (les traits ajoutent encore).
	var coins := maxi(sell_value + 6, int(ceil(float(sell_value) * 1.8))) + prestige_level * 2
	var xp_r := 10 + weight * 5 + prestige_level * 2
	var mult := 1.0
	match trait_id:
		MissionData.TRAIT_EPICUREAN:
			mult = 1.15
		MissionData.TRAIT_GOURMAND:
			mult = 1.20
		MissionData.TRAIT_IMPATIENT:
			mult = 1.35
	coins = maxi(sell_value + 1, int(coins * mult))
	xp_r = maxi(1, int(xp_r * mult))
	return Vector2i(coins, xp_r)


func _push_order() -> bool:
	if not is_tutorial_done():
		return _push_tutorial_order()
	if _active_order_count() >= max_active_missions():
		return false
	var pool := _unlocked_crop_ids()
	if pool.is_empty():
		return false
	mission_index += 1
	var trait_id := _random_trait()
	var reqs := _reqs_for_trait(trait_id)
	if reqs.is_empty():
		return false
	for crop_id in reqs.keys():
		if not is_crop_id_unlocked(crop_id):
			reqs.erase(crop_id)
	if reqs.is_empty():
		return false
	var rewards := _reward_for_reqs(reqs, trait_id)
	var duration := _time_for_trait(trait_id)
	var m := MissionData.new(
		"m%d" % mission_index,
		_random_client(),
		reqs,
		rewards.x,
		rewards.y,
		trait_id,
		duration
	)
	missions.append(m)
	return true


func plot_progress(index: int) -> float:
	var p: Dictionary = plots[index]
	if p["crop"] == null:
		return 0.0
	if p["ready"]:
		return 1.0
	var need: float = _plot_need(p, index)
	if need <= 0.0:
		return 1.0
	return clampf(float(p["grown"]) / need, 0.0, 1.0)


## ——— Missions board (daily / weekly / all) ———

func _day_key() -> String:
	var t := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [int(t.year), int(t.month), int(t.day)]


func _week_key() -> String:
	## Semaine UTC glissante (7 jours).
	var week := int(Time.get_unix_time_from_system() / 604800.0)
	return "w%d" % week


func seconds_until_daily_reset() -> int:
	var t := Time.get_datetime_dict_from_system()
	var secs_today := int(t.hour) * 3600 + int(t.minute) * 60 + int(t.second)
	return maxi(1, 86400 - secs_today)


func seconds_until_weekly_reset() -> int:
	var now := int(Time.get_unix_time_from_system())
	var week_len := 604800
	return maxi(1, week_len - (now % week_len))


func format_reset_countdown(seconds: int) -> String:
	var s := maxi(0, seconds)
	var h := int(s / 3600)
	var m := int((s % 3600) / 60)
	if h >= 48:
		var d := int(h / 24)
		var rh := h % 24
		return "%dj %dh" % [d, rh]
	if h > 0:
		return "%dh %02dm" % [h, m]
	return "%dm" % maxi(1, m)


func ensure_board_quests(force: bool = false) -> void:
	var dk := _day_key()
	var wk := _week_key()
	var changed := false
	var rebalance := board_balance_version != BOARD_BALANCE_VERSION
	if force or rebalance or board_day_key != dk:
		board_day_key = dk
		_replace_scope_quests("daily", _make_daily_quests())
		changed = true
	if force or rebalance or board_week_key != wk:
		board_week_key = wk
		_replace_scope_quests("weekly", _make_weekly_quests())
		changed = true
	if force or rebalance or _all_quests().is_empty():
		_replace_scope_quests("all", _make_all_quests())
		changed = true
	if rebalance:
		board_balance_version = BOARD_BALANCE_VERSION
		changed = true
	_sync_board_progress()
	if changed:
		board_quests_changed.emit()


func _replace_scope_quests(scope: String, fresh: Array) -> void:
	var kept: Array = []
	for q in board_quests:
		if str(q.get("scope", "")) != scope:
			kept.append(q)
	for q in fresh:
		kept.append(q)
	board_quests = kept


func _all_quests() -> Array:
	var out: Array = []
	for q in board_quests:
		if str(q.get("scope", "")) == "all":
			out.append(q)
	return out


func _make_quest(id: String, scope: String, title: String, desc: String, kind: String, goal: int, reward: int) -> Dictionary:
	return {
		"id": id,
		"scope": scope,
		"title": title,
		"desc": desc,
		"kind": kind,
		"goal": goal,
		"progress": 0,
		"reward_gold": reward,
		"claimed": false,
	}


func _make_daily_quests() -> Array:
	var out: Array = []
	## Mission découverte : uniquement pendant le tuto (pas après).
	if not is_tutorial_done():
		out.append(_make_quest("d_intro_sell", "daily", "Découverte vente", "Vendre 1 légume en vente directe.", "sold_items", 1, 40))
	out.append(_make_quest("d_orders", "daily", "Livreur du jour", "Livrer 8 commandes.", "orders", 8, 120))
	out.append(_make_quest("d_harvest", "daily", "Récolte matinale", "Récolter 35 légumes.", "harvested", 35, 110))
	out.append(_make_quest("d_sell", "daily", "Petit marché", "Gagner 80 or en vente directe.", "gold_sold", 80, 100))
	return out


func _make_weekly_quests() -> Array:
	return [
		_make_quest("w_orders", "weekly", "Semaine chargée", "Livrer 55 commandes.", "orders", 55, 480),
		_make_quest("w_harvest", "weekly", "Serre productive", "Récolter 220 légumes.", "harvested", 220, 420),
		_make_quest("w_sell", "weekly", "Marché hebdo", "Vendre 120 légumes.", "sold_items", 120, 400),
	]


func _make_all_quests() -> Array:
	return [
		_make_quest("a_prestige1", "all", "Premier contrat", "Atteindre Prestige 1.", "prestige_level", 1, 100),
		_make_quest("a_orders50", "all", "Fidèle livreur", "Livrer 50 commandes (carrière).", "orders", 50, 120),
		_make_quest("a_sold200", "all", "Commerçant", "Vendre 200 légumes (carrière).", "sold_items", 200, 110),
	]


func _stat_for_kind(kind: String, scope: String) -> int:
	match kind:
		"prestige_level":
			return prestige_level
		_:
			if scope == "all":
				return int(lifetime_stats.get(kind, 0))
			## daily / weekly : progression stockée sur la quête (incréments session)
			return -1


func _sync_board_progress() -> void:
	var changed := false
	for q in board_quests:
		if bool(q.get("claimed", false)):
			continue
		var kind := str(q.get("kind", ""))
		var scope := str(q.get("scope", ""))
		var from_stat := _stat_for_kind(kind, scope)
		if from_stat >= 0:
			var goal := int(q.get("goal", 1))
			var next_p := mini(goal, from_stat)
			if int(q.get("progress", 0)) != next_p:
				q["progress"] = next_p
				changed = true
	if changed:
		board_quests_changed.emit()


func _bump_board_progress(kind: String, amount: int) -> void:
	## Incrémente les quêtes daily/weekly liées à ce kind.
	if amount <= 0:
		return
	var changed := false
	for q in board_quests:
		if bool(q.get("claimed", false)):
			continue
		if str(q.get("kind", "")) != kind:
			continue
		var scope := str(q.get("scope", ""))
		if scope != "daily" and scope != "weekly":
			continue
		var goal := int(q.get("goal", 1))
		var prev := int(q.get("progress", 0))
		var next_p := mini(goal, prev + amount)
		if next_p != prev:
			q["progress"] = next_p
			changed = true
	if changed:
		board_quests_changed.emit()


func _track_stat(key: String, amount: int) -> void:
	if amount <= 0:
		return
	run_stats[key] = int(run_stats.get(key, 0)) + amount
	lifetime_stats[key] = int(lifetime_stats.get(key, 0)) + amount
	_bump_board_progress(key, amount)
	_sync_board_progress()


func _bump_board_on_prestige() -> void:
	_sync_board_progress()
	board_quests_changed.emit()


func get_board_quests(scope: String = "") -> Array:
	ensure_board_quests(false)
	if scope.is_empty():
		return board_quests.duplicate(true)
	var out: Array = []
	for q in board_quests:
		if str(q.get("scope", "")) == scope:
			out.append(q)
	return out


func count_claimable_board_quests() -> int:
	ensure_board_quests(false)
	var n := 0
	for q in board_quests:
		if bool(q.get("claimed", false)):
			continue
		var goal := maxi(1, int(q.get("goal", 1)))
		if int(q.get("progress", 0)) >= goal:
			n += 1
	return n


func claim_board_quest(quest_id: String) -> int:
	ensure_board_quests(false)
	for q in board_quests:
		if str(q.get("id", "")) != quest_id:
			continue
		if bool(q.get("claimed", false)):
			toast.emit("Déjà réclamé.")
			return 0
		var goal := int(q.get("goal", 1))
		if int(q.get("progress", 0)) < goal:
			toast.emit("Objectif pas encore atteint.")
			return 0
		q["claimed"] = true
		var gold := int(q.get("reward_gold", 0))
		add_money(gold)
		toast.emit("Mission terminée : +%d or" % gold)
		if quest_id == TUTORIAL_INTRO_QUEST_ID:
			_advance_tutorial_on_intro_claim()
		board_quests_changed.emit()
		save_game()
		return gold
	toast.emit("Mission introuvable.")
	return 0


## ——— Save / Load ———

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"money": money,
		"xp": xp,
		"xp_required": xp_required,
		"player_level": player_level,
		"skill_points": skill_points,
		"skill_points_spent": skill_points_spent,
		"prestige_level": prestige_level,
		"prestige_points": prestige_points,
		"speed_level": speed_level,
		"click_level": click_level,
		"yield_level": yield_level,
		"unlocked_plots": unlocked_plots,
		"fertilizer_owned": fertilizer_owned,
		"gardener_owned": gardener_owned,
		"delivery_owned": delivery_owned,
		"terrain_edit_seen": terrain_edit_seen,
		"skills_owned": skills_owned.duplicate(),
		"free_refuses_left": free_refuses_left,
		"combo_overflow_gained": combo_overflow_gained,
		"relic_levels": relic_levels.duplicate(),
		"selected_crop_index": selected_crop_index,
		"stock": _stock_to_save(),
		"boost_costs": _boost_costs.duplicate(),
		"tutorial_step": tutorial_step,
		"tutorial_first_ready_seen": tutorial_grow_seen or is_tutorial_done(),
		"plots": _plots_to_save(),
		"missions": _missions_to_save(),
		"mission_index": mission_index,
		"order_refresh_slots": order_refresh_slots.duplicate(true),
		"combo_count": combo_count,
		"combo_window_left": combo_window_left,
		"combo_boost_left": combo_boost_left,
		"combo_cooldown_left": combo_cooldown_left,
		"run_stats": run_stats.duplicate(),
		"lifetime_stats": lifetime_stats.duplicate(),
		"board_quests": board_quests.duplicate(true),
		"board_day_key": board_day_key,
		"board_week_key": board_week_key,
		"board_balance_version": board_balance_version,
	}
	var json := JSON.stringify(data)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Save failed: %s" % FileAccess.get_open_error())
		return
	f.store_string(json)
	save_completed.emit()


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	## Pas de migrateur : anciennes saves (grille packing) invalidées.
	if int(data.get("version", 0)) != SAVE_VERSION:
		push_warning("Save version mismatch (got %s, need %d) — starting fresh." % [
			str(data.get("version", "?")), SAVE_VERSION
		])
		return false
	money = int(data.get("money", 40))
	xp = int(data.get("xp", 0))
	player_level = int(data.get("player_level", 1))
	skill_points = int(data.get("skill_points", 0))
	skill_points_spent = int(data.get("skill_points_spent", 0))
	prestige_level = int(data.get("prestige_level", 0))
	prestige_points = int(data.get("prestige_points", 0))
	speed_level = int(data.get("speed_level", 0))
	click_level = int(data.get("click_level", 0))
	yield_level = int(data.get("yield_level", 0))
	unlocked_plots = clampi(int(data.get("unlocked_plots", START_PLOTS)), 1, MAX_PLOTS)
	fertilizer_owned = clampi(int(data.get("fertilizer_owned", 0)), 0, FERTILIZER_MAX)
	gardener_owned = clampi(int(data.get("gardener_owned", 0)), 0, GARDENER_MAX)
	delivery_owned = clampi(int(data.get("delivery_owned", 0)), 0, DELIVERY_MAX)
	terrain_edit_seen = bool(data.get("terrain_edit_seen", false))
	skills_owned.clear()
	var owned = data.get("skills_owned", {})
	if typeof(owned) == TYPE_DICTIONARY:
		var migrate := {
			"root_orders": "root_hub", "root_xp": "root_hub", "root_money": "root_hub",
			"combo_window": "combo_boost", "combo_power": "combo_boost", "combo_duration": "combo_boost",
			"combo_cooldown": "combo_cd", "combo_overflow": "combo_master",
			"xp_curve_2": "xp_curve",
			"order_refresh": "order_flow", "order_value": "order_slots",
			"money_mission_2": "money_mission",
		}
		for k in owned:
			var kid := str(k)
			if not bool(owned[k]):
				continue
			if migrate.has(kid):
				skills_owned[str(migrate[kid])] = true
			elif _SKILL_DEFS.has(kid):
				skills_owned[kid] = true
	else:
		## Migration anciennes compétences booléennes
		if bool(data.get("skill_combo_flash", false)):
			skills_owned["combo_flash"] = true
		if bool(data.get("skill_long_orders", false)):
			skills_owned["order_time"] = true
		if bool(data.get("skill_xp_boost", false)):
			skills_owned["xp_mission"] = true
		if bool(data.get("skill_money_boost", false)):
			skills_owned["money_mission"] = true
		if not skills_owned.is_empty():
			skills_owned["root_hub"] = true
	## Toujours recalculer depuis la formule (courbe peut changer entre versions).
	xp_required = _xp_for_player_level(player_level)
	free_refuses_left = int(data.get("free_refuses_left", 0))
	if has_skill("order_refuse") and free_refuses_left <= 0 and not data.has("free_refuses_left"):
		free_refuses_left = FREE_REFUSE_PER_RUN
	combo_overflow_gained = float(data.get("combo_overflow_gained", 0.0))
	relic_levels.clear()
	var saved_relics = data.get("relic_levels", {})
	if typeof(saved_relics) == TYPE_DICTIONARY:
		for k in saved_relics:
			var rid := str(k)
			if _RELIC_DEFS.has(rid):
				relic_levels[rid] = clampi(int(saved_relics[k]), 0, RELIC_MAX_LEVEL)
	## Migration saves v6 : anciennes clés individuelles.
	var legacy_gt := int(data.get("relic_green_thumb", 0))
	var legacy_fs := int(data.get("relic_fertile_soil", 0))
	if legacy_gt > 0:
		relic_levels["green_thumb"] = maxi(int(relic_levels.get("green_thumb", 0)), clampi(legacy_gt, 0, RELIC_MAX_LEVEL))
	if legacy_fs > 0:
		relic_levels["fertile_soil"] = maxi(int(relic_levels.get("fertile_soil", 0)), clampi(legacy_fs, 0, RELIC_MAX_LEVEL))
	selected_crop_index = int(data.get("selected_crop_index", 0))
	tutorial_grow_seen = bool(data.get("tutorial_first_ready_seen", false))
	if data.has("tutorial_step"):
		var raw_step := int(data.get("tutorial_step", TUTORIAL_ACTIVE))
		## 0 = actif, 1 = vente, 2 = missions, ≥3 = terminé
		if raw_step >= TUTORIAL_DONE:
			tutorial_step = TUTORIAL_DONE
		elif raw_step == TUTORIAL_MISSIONS:
			tutorial_step = TUTORIAL_MISSIONS
		elif raw_step == TUTORIAL_SELL:
			tutorial_step = TUTORIAL_SELL
		else:
			tutorial_step = TUTORIAL_ACTIVE
	elif tutorial_grow_seen:
		tutorial_step = TUTORIAL_DONE
	else:
		tutorial_step = TUTORIAL_ACTIVE
	if is_tutorial_done():
		tutorial_grow_seen = true
	elif is_tutorial_missions_step():
		tutorial_grow_seen = true
	elif is_tutorial_sell_step():
		tutorial_grow_seen = true
		if get_stock(TUTORIAL_SELL_CROP) <= 0:
			add_stock(TUTORIAL_SELL_CROP, 1)
		for i in crops.size():
			if crops[i].id == TUTORIAL_SELL_CROP:
				selected_crop_index = i
				break
	elif not has_tutorial_order():
		## Remplace d'éventuelles commandes random d'anciennes saves
		missions.clear()
		order_refresh_slots.clear()
		_push_tutorial_order()
	_boost_costs = {
		"speed": 30,
		"click": 40,
		"yield": 30,
		"plot": 10,
	}
	var bc = data.get("boost_costs", {})
	if typeof(bc) == TYPE_DICTIONARY:
		for k in bc:
			var key := str(k)
			if _boost_costs.has(key):
				_boost_costs[key] = int(bc[k])
	## Recalcule le coût parcelle (corrige anciennes saves trop chères).
	_sync_plot_boost_cost()
	_stock_from_save(data.get("stock", {}))
	_plots_from_save(data.get("plots", []))
	_missions_from_save(data.get("missions", []))
	mission_index = int(data.get("mission_index", 0))
	order_refresh_slots = data.get("order_refresh_slots", [])
	if typeof(order_refresh_slots) != TYPE_ARRAY:
		order_refresh_slots = []
	combo_count = int(data.get("combo_count", 0))
	combo_window_left = float(data.get("combo_window_left", 0.0))
	combo_boost_left = float(data.get("combo_boost_left", 0.0))
	combo_cooldown_left = float(data.get("combo_cooldown_left", 0.0))
	run_stats = _empty_stats()
	lifetime_stats = _empty_stats()
	var rs = data.get("run_stats", {})
	if typeof(rs) == TYPE_DICTIONARY:
		for k in rs:
			run_stats[str(k)] = int(rs[k])
	var ls = data.get("lifetime_stats", {})
	if typeof(ls) == TYPE_DICTIONARY:
		for k in ls:
			lifetime_stats[str(k)] = int(ls[k])
	board_quests = []
	var bq = data.get("board_quests", [])
	if typeof(bq) == TYPE_ARRAY:
		for item in bq:
			if typeof(item) == TYPE_DICTIONARY:
				board_quests.append((item as Dictionary).duplicate(true))
	board_day_key = str(data.get("board_day_key", ""))
	board_week_key = str(data.get("board_week_key", ""))
	board_balance_version = int(data.get("board_balance_version", 0))
	_clamp_selected_crop()
	if is_tutorial_done():
		_remove_intro_board_quest()
	if missions.is_empty():
		_refill_missions()
	elif is_tutorial_done() and _active_order_count() == 0:
		## Saves bloquées après tuto (commandes non refillées).
		_refill_orders()
	ensure_board_quests(false)
	if is_tutorial_done():
		_remove_intro_board_quest()
	_emit_economy()
	prestige_points_changed.emit(prestige_points)
	boosts_changed.emit()
	skills_changed.emit()
	relics_changed.emit()
	plots_changed.emit()
	missions_changed.emit()
	board_quests_changed.emit()
	prestige_ready_changed.emit(can_prestige())
	combo_boost_changed.emit()
	return true


func _stock_to_save() -> Dictionary:
	var out := {}
	for k in stock:
		out[String(k)] = int(stock[k])
	return out


func _stock_from_save(data) -> void:
	stock.clear()
	if typeof(data) != TYPE_DICTIONARY:
		return
	for k in data:
		var cid := StringName(str(k))
		stock[cid] = int(data[k]) + int(stock.get(cid, 0))


func _plots_to_save() -> Array:
	var out: Array = []
	for i in plots.size():
		var p: Dictionary = plots[i]
		var crop: CropData = p["crop"]
		out.append({
			"unlocked": p["unlocked"],
			"crop_id": String(crop.id) if crop != null else "",
			"grown": float(p["grown"]),
			"ready": bool(p["ready"]),
			"auto_plant_id": String(p.get("auto_plant_id", &"")),
			"machine": str(p.get("machine", "")),
		})
	return out


func _plots_from_save(arr) -> void:
	_build_plots()
	if typeof(arr) != TYPE_ARRAY:
		_place_starting_lands()
		return
	for i in mini(arr.size(), plots.size()):
		var s: Dictionary = arr[i]
		var p: Dictionary = plots[i]
		if bool(s.get("has_sprinkler", false)):
			p["unlocked"] = bool(s.get("unlocked", false))
			p["crop"] = null
			p["grown"] = 0.0
			p["ready"] = false
			p["machine"] = ""
			continue
		p["unlocked"] = bool(s.get("unlocked", false))
		p["grown"] = float(s.get("grown", 0.0))
		p["ready"] = bool(s.get("ready", false))
		p["auto_plant_id"] = StringName(str(s.get("auto_plant_id", "")))
		var mid := str(s.get("machine", ""))
		if mid != MACHINE_FERTILIZER and mid != MACHINE_GARDENER:
			mid = ""
		p["machine"] = mid
		var cid := str(s.get("crop_id", ""))
		p["crop"] = null
		if cid != "" and mid != MACHINE_GARDENER:
			for c in crops:
				if String(c.id) == cid:
					p["crop"] = c
					break
	fertilizer_owned = maxi(fertilizer_owned, machine_placed_count(MACHINE_FERTILIZER))
	gardener_owned = maxi(gardener_owned, machine_placed_count(MACHINE_GARDENER))
	var land_count := land_placed()
	unlocked_plots = maxi(unlocked_plots, maxi(START_PLOTS, land_count))
	if land_count <= 0:
		_place_starting_lands()


func _missions_to_save() -> Array:
	var out: Array = []
	for m in missions:
		var reqs := {}
		for k in m.requirements:
			reqs[String(k)] = int(m.requirements[k])
		out.append({
			"id": m.id,
			"client": m.client_name,
			"reqs": reqs,
			"coins": m.coin_reward,
			"xp": m.xp_reward,
			"trait": String(m.client_trait),
			"time_left": m.time_left,
			"time_max": m.time_max,
		})
	return out


func _missions_from_save(arr) -> void:
	missions.clear()
	if typeof(arr) != TYPE_ARRAY:
		return
	for item in arr:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var reqs_raw = item.get("reqs", {})
		var reqs: Dictionary = {}
		if typeof(reqs_raw) == TYPE_DICTIONARY:
			for k in reqs_raw:
				var cid := StringName(str(k))
				if is_crop_id_unlocked(cid):
					reqs[cid] = int(reqs_raw[k])
		if reqs.is_empty():
			continue
		var m := MissionData.new(
			str(item.get("id", "m")),
			str(item.get("client", "Client")),
			reqs,
			int(item.get("coins", 1)),
			int(item.get("xp", 1)),
			StringName(str(item.get("trait", MissionData.TRAIT_GOURMAND))),
			float(item.get("time_max", ORDER_DURATION))
		)
		m.time_left = float(item.get("time_left", m.time_max))
		missions.append(m)
