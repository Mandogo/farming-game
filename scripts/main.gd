extends Control

const SellModalScript := preload("res://scripts/ui/sell_modal.gd")
const PrestigeConfirmScript := preload("res://scripts/ui/prestige_confirm.gd")
const RelicDraftModalScript := preload("res://scripts/ui/relic_draft_modal.gd")
const DebugCheatPanelScript := preload("res://scripts/ui/debug_cheat_panel.gd")
const MissionsPanelScript := preload("res://scripts/ui/missions_panel.gd")
const TerrainEditModalScript := preload("res://scripts/ui/terrain_edit_modal.gd")

const PLOT_SCENE := preload("res://scenes/plot_tile.tscn")
const UiThemeFactory = preload("res://scripts/ui_theme_factory.gd")
const IsoBlockBuilder = preload("res://scripts/iso_block_builder.gd")

# Losange 2:1 exact (tile 104x52 de dessus)
const ISO_W := 52
const ISO_H := 26

@onready var money_label: Label = %MoneyLabel
@onready var xp_bar: ProgressBar = %XpBar
@onready var xp_label: Label = %XpLabel
@onready var toast_label: Label = %ToastLabel
@onready var field_host: Control = %FieldHost
@onready var seed_row: HBoxContainer = %SeedRow
@onready var mission_list: VBoxContainer = %MissionList
@onready var side_content: VBoxContainer = %SideContent
@onready var skill_tree_button: Button = %SkillTreeButton
@onready var settings_button: Button = %SettingsButton
@onready var settings_overlay: ColorRect = %SettingsOverlay
@onready var settings_vbox: VBoxContainer = %SettingsVBox
@onready var player_level_label: Label = %PlayerLevelLabel
@onready var player_avatar: TextureRect = %PlayerAvatar
@onready var sp_label: Label = %SpLabel
@onready var sp_badge: PanelContainer = %SpBadge
@onready var skill_tree_overlay: ColorRect = %SkillTreeOverlay
@onready var skill_tree_vbox: VBoxContainer = %SkillTreeVBox
@onready var cur_money_label: Label = %CurMoneyLabel
@onready var cur_skill_label: Label = %CurSkillLabel
@onready var cur_prestige_label: Label = %CurPrestigeLabel
@onready var cur_money_icon: TextureRect = %CurMoneyIcon
@onready var cur_skill_icon: TextureRect = %CurSkillIcon
@onready var cur_prestige_icon: TextureRect = %CurPrestigeIcon

var prestige_bar: ProgressBar = null
var prestige_label: Label = null

var _toast_timer: float = 0.0
var _plot_tiles: Array[PlotTile] = []
var _mission_refresh: float = 0.0
var _textures: Dictionary = {}
var _seed_buttons: Array[Control] = []
var _current_tab: String = "boosts"
var _shown_unlocked: int = -1
var _edit_terrain_btn: Button
var _edit_terrain_badge: Control
var _active_terrain_modal: Control = null
var _plot_base_positions: Array[Vector2] = []
var _rebuilding_ui: bool = false
var _drag_done: Dictionary = {}
var _theme: Theme
var _card_style: StyleBoxFlat
var _chip_style: StyleBoxFlat
var _field_style: StyleBoxFlat
var _pulse_t: float = 0.0
var _plot_vis_accum: float = 0.0
var _last_centered_land: int = -1
var _combo_ui_accum: float = 0.0
var _finger_tutorial: Control = null
var _finger_plot_index: int = -1
var _finger_anim: Control = null
var _finger_label: Label = null
var _finger_hotspot: Vector2 = Vector2(10, 9)  # bout de l'index (haut-gauche de l'ic?ne)
var _finger_target_nudge := Vector2(-2, -2)  # aligne le bout de l'index sur la cible
var _finger_aura: Control = null
var _tut_deliver_btn: Control = null
var _active_sell_modal = null
var _debug_panel = null
var _field_layer: Control = null
var _field_zoom: float = 1.0
var _hovered_plot: PlotTile = null
var _tutorial_mode: StringName = &""
var _last_tutorial_nudge: StringName = &""
var _skill_tip: PanelContainer = null
var _skill_tip_skill_id: String = ""
var _skill_tip_anchor: Control = null
var _skill_nodes: Array[Control] = []
## Tooltip survol uniquement (pas d'?pinglage).
var _combo_status_l: Label = null
var _combo_reward_l: Label = null
var _combo_goal_l: Label = null
var _combo_segments: Array = []
var _combo_window_bar: ProgressBar = null
var _combo_markers_row: Control = null
var _combo_panel_built: bool = false
var _tab_buttons: Dictionary = {}
var _selected_relic_id: String = ""
var _last_relic_draft: String = ""
var _last_relic_draft_t: float = 0.0

const RIGHT_TABS: Array = [
	{
		"id": "boosts",
		"title": "Boutique",
		"hint": "Ameliore cette run (reset au Prestige).",
		"icon": "ui_coin",
		"header_icon": "ui_coin",
		"accent": Color(0.86, 0.62, 0.14, 1.0),
		"locked": false,
	},
	{
		"id": "missions",
		"title": "Missions",
		"hint": "Quotidien, hebdo et carriere - recompenses en or.",
		"icon": "ui_mission",
		"header_icon": "ui_mission",
		"accent": Color(0.32, 0.52, 0.82, 1.0),
		"locked": false,
	},
	{
		"id": "relics",
		"title": "Reliques",
		"hint": "Bonus permanents via points de Prestige.",
		"icon": "ui_tab_prestige",
		"header_icon": "ui_tab_prestige",
		"accent": Color(0.72, 0.28, 0.52, 1.0),
		"locked": false,
	},
]


func _ready() -> void:
	_theme = UiThemeFactory.build()
	theme = _theme
	_card_style = _theme.get_stylebox("panel", "Card") as StyleBoxFlat
	_chip_style = _theme.get_stylebox("panel", "Chip") as StyleBoxFlat
	_field_style = _theme.get_stylebox("panel", "FieldFrame") as StyleBoxFlat
	_apply_panel_styles()

	_load_textures()
	_assign_ui_textures()
	_build_iso_field()
	_build_seed_bar()
	_connect_signals()
	_bind_tabs()
	if skill_tree_button:
		skill_tree_button.pressed.connect(_open_skill_tree)
	_setup_settings()
	_setup_skill_tree_modal()
	_setup_player_bar()
	_setup_combo_boost_chip()
	_ensure_combo_panel()
	_setup_edit_terrain_button()
	field_host.resized.connect(_center_field)
	field_host.mouse_filter = Control.MOUSE_FILTER_STOP
	field_host.gui_input.connect(_on_field_host_gui_input)
	_show_tab("boosts")
	_clamp_side_panels()
	get_viewport().size_changed.connect(_clamp_side_panels)
	var mission_scroll := get_node_or_null("%MissionScroll") as Control
	if mission_scroll:
		mission_scroll.resized.connect(_fit_scroll_widths)
	var side_scroll := get_node_or_null("%SideScroll") as Control
	if side_scroll:
		side_scroll.resized.connect(_fit_scroll_widths)
	_refresh_all()
	_hide_hint_labels()
	call_deferred("_boot_tutorial")


func _boot_tutorial() -> void:
	GameState.maybe_emit_tutorial_start()


func _setup_settings() -> void:
	if settings_button:
		settings_button.tooltip_text = "Parametres"
		settings_button.pressed.connect(_open_settings)
		_apply_settings_button_icon()
	if settings_overlay:
		settings_overlay.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				# Clic hors panneau = fermer
				var panel := get_node_or_null("%SettingsPanel") as Control
				if panel and not panel.get_global_rect().has_point(ev.global_position):
					_close_settings()
		)
	_build_settings_content()


var _settings_reset_armed: bool = false


func _build_settings_content() -> void:
	if settings_vbox == null:
		return
	for c in settings_vbox.get_children():
		c.queue_free()
	_settings_reset_armed = false

	var title := Label.new()
	title.text = "Parametres"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(title)
	head.add_child(_make_ui_close_button(_close_settings, false))
	settings_vbox.add_child(head)

	var hint := Label.new()
	hint.text = "Options a venir - placeholders pour l'instant."
	hint.modulate = Color(0.75, 0.85, 0.78)
	hint.add_theme_font_size_override("font_size", 12)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_vbox.add_child(hint)

	for row in [
		["Langue", "Fran?ais"],
		["Son", "100%"],
		["Musique", "80%"],
		["Touches", "1 2 3 4"],
	]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var lab := Label.new()
		lab.text = row[0]
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.add_theme_font_size_override("font_size", 14)
		line.add_child(lab)
		var val := Button.new()
		val.text = row[1]
		val.disabled = true
		val.custom_minimum_size = Vector2(110, 0)
		line.add_child(val)
		settings_vbox.add_child(line)

	var sep := HSeparator.new()
	sep.modulate = Color(0.45, 0.55, 0.48, 0.5)
	settings_vbox.add_child(sep)

	var danger_title := Label.new()
	danger_title.text = "Zone de test"
	danger_title.add_theme_font_size_override("font_size", 13)
	danger_title.add_theme_color_override("font_color", Color(0.55, 0.28, 0.22))
	settings_vbox.add_child(danger_title)

	var reset_hint := Label.new()
	reset_hint.text = "Efface la sauvegarde, le prestige, les reliques et relance le tutoriel."
	reset_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reset_hint.add_theme_font_size_override("font_size", 11)
	reset_hint.modulate = Color(0.55, 0.42, 0.38)
	settings_vbox.add_child(reset_hint)

	var reset_btn := Button.new()
	reset_btn.name = "ResetGameBtn"
	reset_btn.focus_mode = Control.FOCUS_NONE
	reset_btn.text = "Reset partie"
	reset_btn.custom_minimum_size = Vector2(0, 40)
	reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_btn.theme_type_variation = &"BtnCancel"
	reset_btn.pressed.connect(_on_settings_reset_pressed.bind(reset_btn))
	settings_vbox.add_child(reset_btn)


func _on_settings_reset_pressed(btn: Button) -> void:
	if not _settings_reset_armed:
		_settings_reset_armed = true
		btn.text = "Confirmer le reset ?"
		# S?curit? : d?sarme apr?s quelques secondes
		get_tree().create_timer(4.0).timeout.connect(func():
			if not is_instance_valid(btn):
				return
			if _settings_reset_armed:
				_settings_reset_armed = false
				btn.text = "Reset partie"
		)
		return
	_settings_reset_armed = false
	_close_settings()
	_rebuilding_ui = true
	GameState.hard_reset_game()
	_rebuilding_ui = false
	_apply_hard_reset_ui()


func _apply_hard_reset_ui() -> void:
	_reload_run_ui(true)


func _reload_run_ui(restart_tutorial: bool = false) -> void:
	## Rebuild UI apr?s prestige / hard reset ? une seule passe, sans d?rive de layout.
	if _rebuilding_ui:
		return
	_rebuilding_ui = true
	_clear_finger_tutorial()
	_tutorial_mode = &""
	_last_tutorial_nudge = &""
	_combo_panel_built = false
	_shown_unlocked = -1
	_hovered_plot = null
	_drag_done.clear()
	# Remet les transforms au neutre (?vite le ? gros zoom ? fant?me)
	scale = Vector2.ONE
	var root := get_node_or_null("Root") as Control
	if root:
		root.scale = Vector2.ONE
		root.modulate = Color.WHITE
	if field_host:
		field_host.scale = Vector2.ONE
	var left := get_node_or_null("%LeftPanel") as Control
	if left:
		left.modulate = Color.WHITE
	_close_settings()
	_close_skill_tree()
	_build_iso_field()
	_build_seed_bar()
	_ensure_combo_panel()
	_show_tab("boosts" if restart_tutorial else _current_tab)
	_refresh_all()
	_clamp_side_panels()
	_rebuilding_ui = false
	if restart_tutorial:
		call_deferred("_boot_tutorial")
	else:
		call_deferred("_center_field")


func _open_settings() -> void:
	_settings_reset_armed = false
	_build_settings_content()
	if settings_overlay:
		settings_overlay.visible = true
		settings_overlay.move_to_front()


func _close_settings() -> void:
	_settings_reset_armed = false
	if settings_overlay:
		settings_overlay.visible = false


func _hide_hint_labels() -> void:
	for n in [%TabHint, %UpgradeHint, %NextHint, %ControlsHint]:
		if n:
			n.visible = false
	var seed_title_row := get_node_or_null("Root/Body/Center/SeedPanel/SeedMargin/SeedVBox/SeedTitleRow")
	if seed_title_row:
		seed_title_row.visible = false


func _apply_panel_styles() -> void:
	if _chip_style:
		%MoneyChip.add_theme_stylebox_override("panel", _chip_style)
		var combo_chip := get_node_or_null("%ComboBoostChip") as PanelContainer
		if combo_chip:
			combo_chip.add_theme_stylebox_override("panel", _chip_style)
	if _field_style:
		%FieldFrame.add_theme_stylebox_override("panel", _field_style)
	if _theme:
		var seed_style := _theme.get_stylebox("panel", "SeedCard") as StyleBoxFlat
		if seed_style and %SeedPanel:
			%SeedPanel.add_theme_stylebox_override("panel", seed_style)
		var player_bar := get_node_or_null("%PlayerBar") as PanelContainer
		if player_bar:
			var top_style := _theme.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
			if top_style:
				player_bar.add_theme_stylebox_override("panel", top_style)
		var settings_panel := get_node_or_null("%SettingsPanel") as PanelContainer
		if settings_panel and _card_style:
			settings_panel.add_theme_stylebox_override("panel", _card_style)
		var tab_strip := get_node_or_null("%TabStrip") as PanelContainer
		if tab_strip:
			var strip_style := _theme.get_stylebox("panel", "TabStrip") as StyleBoxFlat
			if strip_style:
				tab_strip.add_theme_stylebox_override("panel", strip_style)
	if _card_style:
		var left_p := get_node_or_null("%LeftPanel") as PanelContainer
		var right_p := get_node_or_null("%RightPanel") as PanelContainer
		if left_p:
			left_p.add_theme_stylebox_override("panel", _card_style)
		if right_p:
			right_p.add_theme_stylebox_override("panel", _card_style)
	_apply_atmosphere()


func _apply_atmosphere() -> void:
	## Ambiance serre soft : ciel att?nu?, prairie moss, pas de glare blanc.
	var sky_tint := get_node_or_null("SkyTint") as ColorRect
	if sky_tint:
		sky_tint.color = Color(0.28, 0.42, 0.30, 0.22)
	var money := get_node_or_null("%MoneyLabel") as Label
	if money:
		money.add_theme_color_override("font_color", Color(0.48, 0.34, 0.06))
		money.add_theme_constant_override("outline_size", 0)
		money.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	var field_grass := get_node_or_null("%FieldGrass") as CanvasItem
	if field_grass:
		if field_grass is TextureRect:
			var tr := field_grass as TextureRect
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.modulate = Color(0.94, 0.97, 0.92, 1.0)
		elif field_grass is ColorRect:
			(field_grass as ColorRect).color = Color(0.52, 0.66, 0.48, 1.0)
	_ensure_vignette()
	_ensure_field_sheen()


func _ensure_vignette() -> void:
	if get_node_or_null("Vignette") != null:
		return
	var v := ColorRect.new()
	v.name = "Vignette"
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.color = Color(0.12, 0.18, 0.12, 0.0)
	# D?grad? approximatif via shader-less : 4 coins plus sombres via modulate static
	# (ColorRect plein trop plat) ? on utilise un StyleBox via Panel pour soft edge
	add_child(v)
	move_child(v, mini(2, get_child_count() - 1))
	var g := Gradient.new()
	g.colors = PackedColorArray([
		Color(0.10, 0.16, 0.10, 0.0),
		Color(0.08, 0.12, 0.08, 0.28),
	])
	g.offsets = PackedFloat32Array([0.55, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 64
	gt.height = 64
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.45)
	gt.fill_to = Vector2(1.0, 0.95)
	var tr := TextureRect.new()
	tr.name = "VignetteTex"
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture = gt
	tr.modulate = Color(1, 1, 1, 0.55)
	add_child(tr)
	# Sous le Root UI, au-dessus du ciel
	move_child(tr, 2)
	v.queue_free()


func _ensure_field_sheen() -> void:
	var stack := get_node_or_null("Root/Body/Center/FieldFrame/FieldStack") as Control
	if stack == null or stack.get_node_or_null("FieldSheen") != null:
		return
	var sheen := ColorRect.new()
	sheen.name = "FieldSheen"
	sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheen.color = Color(0.35, 0.48, 0.32, 0.12)
	stack.add_child(sheen)
	stack.move_child(sheen, 1)


func _load_textures() -> void:
	# Blocs iso assembl?s par le moteur (top.png + side.png) ? variantes pour le champ
	_textures["soil_a"] = IsoBlockBuilder.build_block_dir("res://assets/textures/blocks/soil_a")
	_textures["soil_b"] = IsoBlockBuilder.build_block_dir("res://assets/textures/blocks/soil_b")
	_textures["soil_c"] = IsoBlockBuilder.build_block_dir("res://assets/textures/blocks/soil_c")

	# Cultures : 6 stages de pousse (crops/<id>/stage_1..6.png)
	for crop_id in ["tomato", "carrot", "pepper", "eggplant", "mushroom", "broccoli"]:
		for stage in range(1, 7):
			var key := "%s_%d" % [crop_id, stage]
			var path := "res://assets/textures/crops/%s/stage_%d.png" % [crop_id, stage]
			var tex := _load_tex(path)
			if tex:
				_textures[key] = tex
			elif stage > 4 and _textures.has("%s_4" % crop_id):
				# Fallback si stage 5/6 absents
				_textures[key] = _textures["%s_4" % crop_id]

	# Ic?nes cultures
	for crop_id in ["tomato", "carrot", "pepper", "eggplant", "mushroom", "broccoli"]:
		var path := "res://assets/textures/icons/%s.png" % crop_id
		var tex := _load_tex(path)
		if tex:
			_textures["icon_%s" % crop_id] = tex

	# UI
	var ui_keys := [
		"coin", "coin_skill", "coin_prestige",
		"logo", "mission", "prestige",
		"sparkle", "mouse_left",
		"shop_speed", "shop_plot", "shop_frenzy", "shop_money", "shop_click",
		"btn_check", "btn_cancel", "xp", "chrono", "truck",
		"tab_shop", "tab_prestige", "combo", "target",
		"skill_tree", "click_hand", "lock", "settings",
		"fertilizer", "gardener", "gardener_claw", "auto_planter", "auto_harvester", "auto_delivery",
		"player_avatar", "green_thumb", "edit_pen",
	]
	for n in ui_keys:
		var path := "res://assets/textures/ui/%s.png" % n
		var tex := _load_tex(path)
		if tex:
			_textures["ui_%s" % n] = tex
	if _textures.has("ui_gardener"):
		## Priorit? au redesign jardinier pour boutique / terrain / machine.
		_textures["ui_auto_planter"] = _textures["ui_gardener"]
	## Sprites de vol du fertiliseur (angles distincts ? pas une rotation plate).
	for fi in 4:
		var fpath := "res://assets/textures/ui/fertilizer_fly_%d.png" % fi
		var ftex := _load_tex(fpath)
		if ftex:
			_textures["ui_fertilizer_fly_%d" % fi] = ftex
		elif _textures.has("ui_fertilizer"):
			_textures["ui_fertilizer_fly_%d" % fi] = _textures["ui_fertilizer"]
	for i in 12:
		var ctex := _load_tex("res://assets/textures/ui/client_%d.png" % i)
		if ctex:
			_textures["client_%d" % i] = ctex

	# Fonds
	var sky := _load_tex("res://assets/textures/backgrounds/sky.png")
	if sky:
		_textures["sky_bg"] = sky
	var field := _load_tex("res://assets/textures/backgrounds/field.png")
	if field:
		_textures["field_bg"] = field


func _load_tex(path: String) -> Texture2D:
	# Toujours relire le PNG disque pour ?viter le cache d'import Godot obsol?te
	var abs_path := ProjectSettings.globalize_path(path)
	var img := Image.new()
	if img.load(abs_path) == OK:
		return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(path):
		var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res is Texture2D:
			return res
	return null

func _assign_ui_textures() -> void:
	_set_tex(%SkyBg, "sky_bg")
	_set_field_background()
	_set_tex(%MoneyIcon, "ui_coin")
	_set_tex(%MissionIcon, "ui_mission")
	_set_tex(%BrandIcon, "ui_logo")
	var combo_ic := get_node_or_null("%ComboBoostIcon") as TextureRect
	if combo_ic and _textures.has("ui_shop_speed"):
		combo_ic.texture = _textures["ui_shop_speed"]
		combo_ic.custom_minimum_size = Vector2(24, 24)
		combo_ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_rebuild_stock()


func _set_field_background() -> void:
	var grass := get_node_or_null("%FieldGrass") as Node
	if grass == null:
		return
	if grass is TextureRect:
		_set_tex(grass as TextureRect, "field_bg")
		return
	# Remplace le ColorRect par une TextureRect prairie
	var parent := grass.get_parent() as Control
	if parent == null:
		return
	var idx := grass.get_index()
	var tr := TextureRect.new()
	tr.name = "FieldGrass"
	tr.unique_name_in_owner = true
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.modulate = Color(0.94, 0.97, 0.92, 1.0)


func _set_tex(node: TextureRect, key: String) -> void:
	if node and _textures.has(key):
		node.texture = _textures[key]
		node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _process(delta: float) -> void:
	_pulse_t += delta
	## Refresh parcelles ~12 fps (stages / % / pulse) ? assez fluide, bien plus leger.
	_plot_vis_accum += delta
	if _plot_vis_accum >= 0.08:
		_plot_vis_accum = 0.0
		_update_plot_visuals()
	_update_plot_hover()
	_process_field_drag()
	_update_finger_tutorial(delta)
	_mission_refresh -= delta
	if _mission_refresh <= 0.0:
		_mission_refresh = 0.35
		_refresh_mission_timers()
	## Combo UI pas besoin de 60 fps.
	_combo_ui_accum += delta
	if _combo_ui_accum >= 0.20:
		_combo_ui_accum = 0.0
		_refresh_combo_ui()
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			toast_label.text = ""


func _update_plot_hover() -> void:
	if _is_blocking_ui(get_viewport().gui_get_hovered_control()):
		if _hovered_plot:
			_hovered_plot.set_hovered(false)
			_hovered_plot = null
		return
	var tile := _pick_plot_at_mouse()
	if tile == _hovered_plot:
		return
	if _hovered_plot:
		_hovered_plot.set_hovered(false)
	_hovered_plot = tile
	if _hovered_plot:
		_hovered_plot.set_hovered(true)


func _pick_plot_at_mouse() -> PlotTile:
	## Choisit la parcelle sous la souris : losange strict + z_index le plus haut.
	var best: PlotTile = null
	var best_z := -999999
	for tile in _plot_tiles:
		if not tile.contains_global_mouse():
			continue
		if tile.z_index > best_z:
			best_z = tile.z_index
			best = tile
		elif tile.z_index == best_z and best != null:
			var d_new := tile.get_local_mouse_position().distance_squared_to(tile.size * 0.5)
			var d_old := best.get_local_mouse_position().distance_squared_to(best.size * 0.5)
			if d_new < d_old:
				best = tile
	return best


func _process_field_drag() -> void:
	## Glisser sur d'autres parcelles : plante / r?colte seulement (pas d'accel).
	var held := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if not held:
		_drag_done.clear()
		return
	if _is_blocking_ui(get_viewport().gui_get_hovered_control()):
		return

	var tile := _pick_plot_at_mouse()
	if tile == null:
		return
	if _drag_done.has(tile.index):
		return
	_drag_done[tile.index] = true
	var p: Dictionary = GameState.plots[tile.index]
	if p["crop"] == null or p["ready"]:
		_on_field_action(tile.index, true)


func _on_field_host_gui_input(event: InputEvent) -> void:
	## Un clic physique = une action (pas d'auto-r?p?tition au maintien).
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	if not mb.pressed:
		return
	var tile := _pick_plot_at_mouse()
	if tile == null:
		return
	_drag_done[tile.index] = true
	_on_field_action(tile.index, false)
	field_host.accept_event()


func _is_blocking_ui(ctrl: Control) -> bool:
	if ctrl == null:
		return false
	if ctrl is Button or ctrl is LineEdit or ctrl is TextEdit or ctrl is Slider:
		return true
	var n: Node = ctrl
	while n:
		if n == %MoneyChip or n == %SettingsButton:
			return true
		if n == %LeftPanel or n == %RightPanel or n == %SeedPanel or n == %SettingsOverlay or n == %SkillTreeOverlay or n == %PlayerBar:
			return true
		n = n.get_parent()
	return false


func _connect_signals() -> void:
	GameState.money_changed.connect(_on_money)
	GameState.xp_changed.connect(_on_xp)
	GameState.level_changed.connect(_on_level)
	GameState.missions_changed.connect(func(): call_deferred("_rebuild_missions"))
	GameState.stock_changed.connect(func():
		_rebuild_stock()
		call_deferred("_rebuild_missions")
	)
	GameState.boosts_changed.connect(func():
		call_deferred("_rebuild_side")
	)
	GameState.skills_changed.connect(func():
		_refresh_player_hud()
		call_deferred("_ensure_combo_panel")
		if skill_tree_overlay and skill_tree_overlay.visible:
			call_deferred("_rebuild_skill_modal")
		else:
			call_deferred("_rebuild_side")
	)
	GameState.relics_changed.connect(func(): call_deferred("_rebuild_side"))
	GameState.plots_changed.connect(_on_plots_changed)
	GameState.prestige_ready_changed.connect(func(_ready): _refresh_player_hud())
	GameState.prestige_points_changed.connect(func(_v):
		_refresh_player_hud()
		call_deferred("_rebuild_side")
	)
	GameState.combo_boost_changed.connect(_refresh_combo_ui)
	GameState.toast.connect(_show_toast)
	GameState.harvested.connect(_on_harvested)
	GameState.gardener_harvest.connect(_on_gardener_harvest)
	GameState.tutorial_nudge.connect(_on_tutorial_nudge)
	GameState.board_quests_changed.connect(func():
		_refresh_missions_tab_alert()
		if _current_tab == "missions":
			call_deferred("_rebuild_side")
	)


func _on_money(v: int) -> void:
	if money_label:
		money_label.text = "%d pcs d'or" % v
		money_label.modulate = Color(1.35, 1.20, 0.70)
		var tw := create_tween()
		tw.tween_property(money_label, "modulate", Color.WHITE, 0.4)
	_refresh_currencies()
	if _current_tab == "boosts":
		call_deferred("_rebuild_side")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := (event as InputEventKey).keycode
	match key:
		KEY_F1:
			_toggle_debug_cheats()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if is_instance_valid(_debug_panel):
				_debug_panel.dismiss()
				_debug_panel = null
				get_viewport().set_input_as_handled()
			elif settings_overlay and settings_overlay.visible:
				_close_settings()
				get_viewport().set_input_as_handled()
			elif skill_tree_overlay and skill_tree_overlay.visible:
				_close_skill_tree()
				get_viewport().set_input_as_handled()
			else:
				var boost_ov := get_node_or_null("BoostInfoOverlay") as Control
				if boost_ov:
					boost_ov.queue_free()
					get_viewport().set_input_as_handled()
		KEY_1, KEY_KP_1:
			_on_seed_picked(0)
			get_viewport().set_input_as_handled()
		KEY_2, KEY_KP_2:
			_on_seed_picked(1)
			get_viewport().set_input_as_handled()
		KEY_3, KEY_KP_3:
			_on_seed_picked(2)
			get_viewport().set_input_as_handled()
		KEY_4, KEY_KP_4:
			_on_seed_picked(3)
			get_viewport().set_input_as_handled()
		KEY_5, KEY_KP_5:
			_on_seed_picked(4)
			get_viewport().set_input_as_handled()
		KEY_6, KEY_KP_6:
			_on_seed_picked(5)
			get_viewport().set_input_as_handled()


func _toggle_debug_cheats() -> void:
	if not DebugCheatPanelScript.cheats_available():
		_show_toast("Cheats dispo en build debug / editeur seulement.")
		return
	if is_instance_valid(_debug_panel):
		_debug_panel.dismiss()
		_debug_panel = null
		return
	var panel := DebugCheatPanelScript.present(self)
	_debug_panel = panel
	panel.closed.connect(func():
		if _debug_panel == panel:
			_debug_panel = null
	)
	panel.applied.connect(func():
		_refresh_all()
		_build_seed_bar()
		_build_iso_field()
		_refresh_player_hud()
	)


func _setup_combo_boost_chip() -> void:
	var chip := get_node_or_null("%ComboBoostChip") as Control
	if chip == null:
		return
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in chip.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_combo_ui()


func _refresh_combo_ui() -> void:
	var chip := get_node_or_null("%ComboBoostChip") as Control
	var lab := get_node_or_null("%ComboBoostLabel") as Label
	if chip and lab:
		if GameState.combo_boost_left > 0.0:
			chip.visible = true
			chip.modulate = Color(1.05, 1.12, 1.0)
			lab.text = "x%.1f  %ds" % [
				GameState.combo_boost_mult(),
				maxi(1, int(ceil(GameState.combo_boost_left))),
			]
			lab.modulate = Color(0.22, 0.55, 0.85)
		elif GameState.combo_cooldown_left > 0.0:
			chip.visible = true
			chip.modulate = Color(0.75, 0.78, 0.75, 0.85)
			var cd := maxi(0, int(ceil(GameState.combo_cooldown_left)))
			lab.text = "CD %d:%02d" % [cd / 60, cd % 60]
			lab.modulate = Color(0.45, 0.50, 0.48)
		else:
			chip.visible = false

	_refresh_combo_panel()
	_apply_combo_host_cooldown_look()


func _apply_combo_host_cooldown_look() -> void:
	var host := get_node_or_null("%ComboHost") as Control
	if host == null:
		return
	if GameState.combo_cooldown_left > 0.0 and GameState.combo_boost_left <= 0.0:
		host.modulate = Color(0.55, 0.55, 0.58, 0.72)
	else:
		host.modulate = Color.WHITE


func _refresh_combo_panel() -> void:
	if _combo_status_l == null or not is_instance_valid(_combo_status_l):
		return

	var prog := GameState.combo_progress()

	for i in _combo_segments.size():
		var seg: PanelContainer = _combo_segments[i]
		if not is_instance_valid(seg):
			continue
		var on_cd := GameState.combo_cooldown_left > 0.0 and GameState.combo_boost_left <= 0.0
		var filled := (not on_cd) and (GameState.combo_boost_left > 0.0 or i < prog)
		var st := StyleBoxFlat.new()
		st.set_corner_radius_all(6)
		st.set_content_margin_all(0)
		st.set_border_width_all(2)
		if on_cd:
			st.bg_color = Color(0.48, 0.50, 0.52, 0.55)
			st.border_color = Color(0.38, 0.40, 0.42, 0.60)
		elif GameState.combo_boost_left > 0.0:
			st.bg_color = Color(0.42, 0.72, 0.95, 1.0)
			st.border_color = Color(0.22, 0.48, 0.78, 1.0)
		elif filled:
			st.bg_color = Color(0.42, 0.78, 0.48, 1.0)
			st.border_color = Color(0.22, 0.55, 0.30, 1.0)
		else:
			st.bg_color = Color(0.68, 0.76, 0.70, 0.65)
			st.border_color = Color(0.45, 0.55, 0.48, 0.70)
		seg.add_theme_stylebox_override("panel", st)

		# Check / num?ro
		if seg.get_child_count() > 0:
			var mark := seg.get_child(0)
			if mark is Label:
				var lab := mark as Label
				lab.text = "?" if filled else str(i + 1)
				if on_cd:
					lab.modulate = Color(0.55, 0.55, 0.58, 0.70)
				else:
					lab.modulate = Color(1, 1, 1, 1) if filled else Color(0.22, 0.30, 0.24, 0.80)

	if _combo_window_bar and is_instance_valid(_combo_window_bar):
		_combo_window_bar.max_value = GameState.combo_window_sec()
		_combo_window_bar.value = GameState.combo_window_left
		_combo_window_bar.visible = (
			GameState.combo_window_left > 0.0 and GameState.combo_boost_left <= 0.0
		)

	if _combo_goal_l and is_instance_valid(_combo_goal_l):
		_combo_goal_l.text = "%d en %ds" % [
			GameState.combo_needed(),
			int(GameState.combo_window_sec()),
		]
	if _combo_reward_l and is_instance_valid(_combo_reward_l):
		_combo_reward_l.visible = true
		_combo_reward_l.text = "x%.1f - %ds" % [
			GameState.combo_boost_mult(),
			int(GameState.combo_boost_duration_sec()),
		]

	if GameState.combo_boost_left > 0.0:
		_combo_status_l.text = "Actif %ds" % maxi(1, int(ceil(GameState.combo_boost_left)))
		_combo_status_l.modulate = Color(0.20, 0.50, 0.82)
	elif GameState.combo_cooldown_left > 0.0:
		var cd := maxi(0, int(ceil(GameState.combo_cooldown_left)))
		_combo_status_l.text = "CD %d:%02d" % [cd / 60, cd % 60]
		_combo_status_l.modulate = Color(0.52, 0.55, 0.50)
	elif prog > 0:
		_combo_status_l.text = "%d/%d" % [prog, GameState.combo_needed()]
		_combo_status_l.modulate = Color(0.28, 0.55, 0.36)
	else:
		_combo_status_l.text = ""


func _ensure_combo_panel() -> void:
	var host := get_node_or_null("%ComboHost") as VBoxContainer
	if host == null:
		return
	var need := GameState.combo_needed()
	if (
		_combo_panel_built
		and host.get_child_count() > 0
		and is_instance_valid(_combo_reward_l)
		and _combo_segments.size() == need
	):
		_refresh_combo_panel()
		return
	# free imm?diat pour ?viter doublons (sep + panel) pendant 1 frame
	var kids := host.get_children()
	for c in kids:
		host.remove_child(c)
		c.free()
	_combo_segments.clear()
	_combo_status_l = null
	_combo_reward_l = null
	_combo_goal_l = null
	_combo_window_bar = null
	_combo_markers_row = null
	_combo_panel_built = false

	var sep := HSeparator.new()
	sep.modulate = Color(0.45, 0.58, 0.48, 0.45)
	host.add_child(sep)

	host.add_child(_make_combo_panel())
	_combo_panel_built = true
	_refresh_combo_panel()


func _make_combo_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 58)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.set_meta("combo_panel", true)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.72, 0.82, 0.88, 0.92)
	st.border_color = Color(0.35, 0.58, 0.78, 0.70)
	st.set_border_width_all(2)
	st.set_corner_radius_all(10)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", st)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 5)
	panel.add_child(root)

	# Ligne 1 : camion + titre + statut
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	root.add_child(head)

	if _textures.has("ui_truck"):
		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(26, 26)
		ic.texture = _textures["ui_truck"]
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(ic)

	var title := Label.new()
	title.text = "Combo livraisons"
	title.add_theme_font_size_override("font_size", 13)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)

	_combo_status_l = Label.new()
	_combo_status_l.add_theme_font_size_override("font_size", 12)
	_combo_status_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_combo_status_l)

	# Ligne 2 : cases de progression
	var seg_row := HBoxContainer.new()
	seg_row.add_theme_constant_override("separation", 5)
	seg_row.custom_minimum_size = Vector2(0, 20)
	root.add_child(seg_row)

	_combo_segments.clear()
	for i in GameState.combo_needed():
		var seg := PanelContainer.new()
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.custom_minimum_size = Vector2(0, 20)
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var empty := StyleBoxFlat.new()
		empty.bg_color = Color(0.68, 0.76, 0.70, 0.65)
		empty.border_color = Color(0.45, 0.55, 0.48, 0.70)
		empty.set_border_width_all(2)
		empty.set_corner_radius_all(6)
		seg.add_theme_stylebox_override("panel", empty)

		var mark := Label.new()
		mark.text = str(i + 1)
		mark.add_theme_font_size_override("font_size", 11)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mark.size_flags_vertical = Control.SIZE_EXPAND_FILL
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seg.add_child(mark)
		seg_row.add_child(seg)
		_combo_segments.append(seg)

	# Chrono fen?tre combo
	_combo_window_bar = ProgressBar.new()
	_combo_window_bar.custom_minimum_size = Vector2(0, 4)
	_combo_window_bar.max_value = GameState.combo_window_sec()
	_combo_window_bar.show_percentage = false
	_combo_window_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.55, 0.52, 0.40, 0.45)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.78, 0.22, 1.0)
	fill.set_corner_radius_all(3)
	_combo_window_bar.add_theme_stylebox_override("background", bg)
	_combo_window_bar.add_theme_stylebox_override("fill", fill)
	_combo_window_bar.visible = false
	root.add_child(_combo_window_bar)

	# Deux colonnes : titre au-dessus + pastille (Objectif | R?compense)
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 8)
	root.add_child(info_row)

	var need_n := GameState.combo_needed()
	var win_s := int(GameState.combo_window_sec())
	var mult := GameState.combo_boost_mult()
	var dur_s := int(GameState.combo_boost_duration_sec())

	info_row.add_child(_make_combo_info_column(
		"Objectif",
		"ui_target",
		"%d en %ds" % [need_n, win_s],
		Color(0.86, 0.90, 0.78, 0.95),
		Color(0.42, 0.55, 0.28, 0.75),
		Color(0.28, 0.40, 0.22),
		true
	))
	info_row.add_child(_make_combo_info_column(
		"R?compense",
		"ui_shop_speed",
		"x%.1f - %ds" % [mult, dur_s],
		Color(0.78, 0.88, 0.96, 0.95),
		Color(0.28, 0.52, 0.78, 0.75),
		Color(0.18, 0.38, 0.58),
		false
	))

	return panel


func _make_combo_info_column(
	caption: String,
	icon_key: String,
	text: String,
	bg: Color,
	border: Color,
	font_col: Color,
	is_goal: bool
) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var cap := Label.new()
	cap.text = caption
	cap.add_theme_font_size_override("font_size", 10)
	cap.add_theme_color_override("font_color", Color(0.32, 0.40, 0.48))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(cap)

	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cst := StyleBoxFlat.new()
	cst.bg_color = bg
	cst.border_color = border
	cst.set_border_width_all(1)
	cst.set_corner_radius_all(8)
	cst.content_margin_left = 6
	cst.content_margin_right = 8
	cst.content_margin_top = 4
	cst.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel", cst)
	col.add_child(chip)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)

	if icon_key != "" and _textures.has(icon_key):
		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(22, 22)
		ic.texture = _textures[icon_key]
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)

	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", 11)
	lab.add_theme_color_override("font_color", font_col)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.autowrap_mode = TextServer.AUTOWRAP_OFF
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lab)
	if is_goal:
		_combo_goal_l = lab
	else:
		_combo_reward_l = lab
	return col


func _setup_player_bar() -> void:
	## Une seule barre : avatar, monnaies, XP/prestige, arbre, param?tres.
	var top_bar := get_node_or_null("%TopBar") as Control
	if top_bar:
		top_bar.visible = false
	var avatar_block := get_node_or_null("%AvatarBlock") as Control
	var avatar_frame := get_node_or_null("%AvatarFrame") as Control
	if avatar_block and avatar_frame and player_level_label:
		avatar_block.move_child(avatar_frame, 0)
		avatar_block.move_child(player_level_label, 1)
	if sp_badge:
		sp_badge.visible = false
	# Chip argent du champ ? redondant avec la barre joueur
	var money_chip := get_node_or_null("%MoneyChip") as Control
	if money_chip:
		money_chip.visible = false
	if avatar_frame is PanelContainer:
		avatar_frame.custom_minimum_size = Vector2(54, 54)
		avatar_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		## Cadre serre : bois clair + int?rieur cr?me, coin arrondi.
		var af := StyleBoxFlat.new()
		af.bg_color = Color(0.94, 0.96, 0.90, 0.98)
		af.border_color = Color(0.58, 0.46, 0.22, 0.95)
		af.set_border_width_all(3)
		af.set_corner_radius_all(14)
		af.content_margin_left = 3
		af.content_margin_right = 3
		af.content_margin_top = 3
		af.content_margin_bottom = 3
		## Liser? int?rieur doux (ombre port?e l?g?re).
		af.shadow_color = Color(0.28, 0.36, 0.22, 0.22)
		af.shadow_size = 3
		af.shadow_offset = Vector2(0, 1)
		(avatar_frame as PanelContainer).add_theme_stylebox_override("panel", af)
	if player_avatar:
		player_avatar.custom_minimum_size = Vector2(44, 44)
		player_avatar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		player_avatar.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if _textures.has("ui_player_avatar"):
			player_avatar.texture = _textures["ui_player_avatar"]
		elif _textures.has("client_0"):
			player_avatar.texture = _textures["client_0"]
		elif _textures.has("ui_logo"):
			player_avatar.texture = _textures["ui_logo"]
		player_avatar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		player_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		player_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bind_currency_icon(cur_money_icon, "ui_coin", "ui_coin")
	_bind_currency_icon(cur_skill_icon, "ui_coin_skill", "ui_xp")
	_bind_currency_icon(cur_prestige_icon, "ui_coin_prestige", "ui_prestige")
	## Agrandit monnaies (ic?ne + texte) en haut ? gauche.
	for pair in [
		[cur_money_icon, cur_money_label],
		[cur_skill_icon, cur_skill_label],
		[cur_prestige_icon, cur_prestige_label],
	]:
		var ic: TextureRect = pair[0]
		var lab: Label = pair[1]
		if ic:
			ic.custom_minimum_size = Vector2(22, 22)
		if lab:
			lab.add_theme_font_size_override("font_size", 13)
	_setup_xp_prestige_bars()
	if skill_tree_button:
		skill_tree_button.text = "Arbre de\nCompetences"
		_apply_skill_tree_button_icon()
		skill_tree_button.add_theme_font_size_override("font_size", 12)
		skill_tree_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		skill_tree_button.custom_minimum_size = Vector2(166, 57)
	if settings_button and skill_tree_button:
		var row := skill_tree_button.get_parent() as Node
		if settings_button.get_parent() != row:
			settings_button.reparent(row)
		row.move_child(settings_button, skill_tree_button.get_index() + 1)
		settings_button.custom_minimum_size = Vector2(57, 57)
		settings_button.tooltip_text = "Parametres"
		_apply_settings_button_icon()
	if skill_tree_button and skill_tree_button.get_node_or_null("SpPillHost") == null:
		var pill_bg := PanelContainer.new()
		pill_bg.name = "SpPillHost"
		pill_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill_bg.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		pill_bg.offset_left = -18
		pill_bg.offset_top = -8
		pill_bg.offset_right = 6
		pill_bg.offset_bottom = 12
		var pst := StyleBoxFlat.new()
		pst.bg_color = Color(0.88, 0.18, 0.18, 1.0)
		pst.set_corner_radius_all(10)
		pst.content_margin_left = 5
		pst.content_margin_right = 5
		pst.content_margin_top = 1
		pst.content_margin_bottom = 1
		pill_bg.add_theme_stylebox_override("panel", pst)
		var pill := Label.new()
		pill.name = "SpPill"
		pill.text = "!"
		pill.add_theme_font_size_override("font_size", 12)
		pill.add_theme_color_override("font_color", Color(1, 0.95, 0.95))
		pill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pill.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill_bg.add_child(pill)
		skill_tree_button.add_child(pill_bg)
	_refresh_player_hud()


func _setup_xp_prestige_bars() -> void:
	if xp_bar == null:
		return
	var xp_wrap := xp_bar.get_parent() as Control
	var xp_block := xp_wrap.get_parent() as VBoxContainer if xp_wrap else null
	if xp_block == null:
		return
	xp_block.add_theme_constant_override("separation", 3)
	xp_block.size_flags_stretch_ratio = 0.62
	xp_wrap.custom_minimum_size = Vector2(0, 24)

	# XP bleue (comp?tences / progression)
	var xp_bg := StyleBoxFlat.new()
	xp_bg.bg_color = Color(0.28, 0.38, 0.52, 0.85)
	xp_bg.set_corner_radius_all(6)
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.28, 0.55, 0.88, 1.0)
	xp_fill.set_corner_radius_all(6)
	xp_bar.add_theme_stylebox_override("background", xp_bg)
	xp_bar.add_theme_stylebox_override("fill", xp_fill)
	if xp_label:
		xp_label.add_theme_font_size_override("font_size", 11)
		_style_bar_overlay_label(xp_label)

	# Barre prestige rose sous l'XP
	if xp_block.get_node_or_null("PrestigeBarWrap") != null:
		prestige_bar = xp_block.get_node("PrestigeBarWrap/PrestigeBar") as ProgressBar
		prestige_label = xp_block.get_node("PrestigeBarWrap/PrestigeLabel") as Label
		var existing_wrap := xp_block.get_node("PrestigeBarWrap") as Control
		if existing_wrap:
			existing_wrap.custom_minimum_size = Vector2(0, 24)
		if prestige_bar:
			var p_bg2 := StyleBoxFlat.new()
			p_bg2.bg_color = Color(0.48, 0.28, 0.38, 0.85)
			p_bg2.set_corner_radius_all(6)
			prestige_bar.add_theme_stylebox_override("background", p_bg2)
		if prestige_label:
			prestige_label.add_theme_font_size_override("font_size", 11)
			_style_bar_overlay_label(prestige_label)
		_refresh_prestige_bar()
		return

	var p_wrap := Control.new()
	p_wrap.name = "PrestigeBarWrap"
	p_wrap.custom_minimum_size = Vector2(0, 24)
	p_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_block.add_child(p_wrap)

	prestige_bar = ProgressBar.new()
	prestige_bar.name = "PrestigeBar"
	prestige_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prestige_bar.show_percentage = false
	prestige_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	prestige_bar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var p_bg := StyleBoxFlat.new()
	p_bg.bg_color = Color(0.48, 0.28, 0.38, 0.85)
	p_bg.set_corner_radius_all(6)
	var p_fill := StyleBoxFlat.new()
	p_fill.bg_color = Color(0.78, 0.28, 0.52, 1.0)
	p_fill.set_corner_radius_all(6)
	prestige_bar.add_theme_stylebox_override("background", p_bg)
	prestige_bar.add_theme_stylebox_override("fill", p_fill)
	p_wrap.add_child(prestige_bar)

	prestige_label = Label.new()
	prestige_label.name = "PrestigeLabel"
	prestige_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prestige_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prestige_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prestige_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prestige_label.add_theme_font_size_override("font_size", 11)
	_style_bar_overlay_label(prestige_label)
	prestige_label.clip_text = true
	p_wrap.add_child(prestige_label)

	prestige_bar.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if GameState.can_prestige():
				_on_prestige()
	)
	_refresh_prestige_bar()


func _refresh_prestige_bar() -> void:
	if prestige_bar == null or prestige_label == null:
		return
	var need := GameState.prestige_level_required()
	var ready := GameState.can_prestige()
	prestige_bar.max_value = float(need)
	prestige_bar.value = float(mini(GameState.player_level, need))
	if ready:
		prestige_label.text = "Prestige ! (+%d)" % GameState.calc_prestige_points_gain()
		_style_bar_overlay_label(prestige_label)
		prestige_bar.tooltip_text = "Clique pour prestige - reset la run, garde reliques et prestige."
	else:
		prestige_label.text = "Prochain prestige : Nv.%d / %d" % [GameState.player_level, need]
		_style_bar_overlay_label(prestige_label)
		prestige_bar.tooltip_text = "Prochain prestige au niveau %d." % need
	# Fill plus vif si pr?t
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.90, 0.32, 0.58, 1.0) if ready else Color(0.78, 0.28, 0.52, 1.0)
	fill.set_corner_radius_all(5)
	prestige_bar.add_theme_stylebox_override("fill", fill)


func _bind_currency_icon(node: TextureRect, primary: String, fallback: String) -> void:
	if node == null:
		return
	var key := primary if _textures.has(primary) else fallback
	if _textures.has(key):
		node.texture = _textures[key]
		node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _refresh_currencies() -> void:
	if cur_money_label:
		cur_money_label.text = "%d pcs d'or" % GameState.money
		cur_money_label.add_theme_color_override("font_color", Color(0.55, 0.40, 0.08))
	if cur_skill_label:
		cur_skill_label.text = "%d pts competences" % GameState.skill_points
		cur_skill_label.add_theme_color_override("font_color", Color(0.18, 0.38, 0.68))
	if cur_prestige_label:
		cur_prestige_label.text = "%d pts prestige" % GameState.prestige_points
		cur_prestige_label.add_theme_color_override("font_color", Color(0.68, 0.22, 0.45))
	# Noms int?gr?s dans le label ? masquer les labels annexes
	var currencies := get_node_or_null("%CurrenciesBlock") as Control
	if currencies:
		for child in currencies.get_children():
			for sub in child.get_children():
				if sub is Label and String(sub.name).ends_with("Name"):
					(sub as Label).visible = false


func _setup_skill_tree_modal() -> void:
	if skill_tree_overlay:
		skill_tree_overlay.z_index = 250
		skill_tree_overlay.top_level = true
		skill_tree_overlay.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				var panel := get_node_or_null("%SkillTreePanel") as Control
				if panel and not panel.get_global_rect().has_point(ev.global_position):
					_close_skill_tree()
		)
	if settings_overlay:
		settings_overlay.z_index = 240
		settings_overlay.top_level = true
	var panel := get_node_or_null("%SkillTreePanel") as PanelContainer
	if panel:
		panel.add_theme_stylebox_override("panel", _make_skill_tree_panel_style())


func _close_skill_tree() -> void:
	_hide_skill_tip()
	if skill_tree_overlay:
		skill_tree_overlay.visible = false


func _make_parchment_style() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.93, 0.88, 0.74, 0.98)
	st.border_color = Color(0.62, 0.48, 0.28, 0.85)
	st.set_border_width_all(2)
	st.set_corner_radius_all(14)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	st.shadow_color = Color(0, 0, 0, 0.28)
	st.shadow_size = 10
	return st


func _make_skill_tree_panel_style() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.10, 0.14, 0.12, 0.97)
	st.border_color = Color(0.42, 0.58, 0.46, 0.75)
	st.set_border_width_all(2)
	st.set_corner_radius_all(18)
	st.content_margin_left = 4
	st.content_margin_right = 4
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	st.shadow_color = Color(0.05, 0.12, 0.08, 0.55)
	st.shadow_size = 18
	return st


func _make_ui_close_button(on_press: Callable, light: bool = false) -> Button:
	## Bouton fermeture compact, style pro (?).
	var btn := Button.new()
	btn.text = "?"
	btn.focus_mode = Control.FOCUS_NONE
	btn.flat = false
	btn.custom_minimum_size = Vector2(30, 30)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 18)
	var bg := Color(0.92, 0.90, 0.84, 0.95) if light else Color(0.16, 0.20, 0.18, 0.95)
	var bd := Color(0.62, 0.50, 0.32, 0.70) if light else Color(0.42, 0.52, 0.46, 0.75)
	var fg := Color(0.32, 0.22, 0.12, 1.0) if light else Color(0.82, 0.88, 0.84, 1.0)
	var hv := Color(0.98, 0.94, 0.86, 1.0) if light else Color(0.24, 0.30, 0.26, 1.0)
	var pr := Color(0.86, 0.80, 0.70, 1.0) if light else Color(0.12, 0.15, 0.13, 1.0)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg)
	btn.add_theme_color_override("font_pressed_color", fg.darkened(0.15))
	for pair in [["normal", bg, bd], ["hover", hv, bd.lightened(0.15)], ["pressed", pr, bd]]:
		var st := StyleBoxFlat.new()
		st.bg_color = pair[1]
		st.border_color = pair[2]
		st.set_border_width_all(1)
		st.set_corner_radius_all(8)
		st.content_margin_left = 0
		st.content_margin_right = 0
		st.content_margin_top = 0
		st.content_margin_bottom = 2
		btn.add_theme_stylebox_override(str(pair[0]), st)
	var dis := StyleBoxFlat.new()
	dis.bg_color = bg.darkened(0.08)
	dis.border_color = bd.darkened(0.1)
	dis.set_border_width_all(1)
	dis.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("disabled", dis)
	btn.pressed.connect(on_press)
	return btn


func _make_skill_pc_badge() -> PanelContainer:
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.12, 0.22, 0.36, 0.94)
	st.border_color = Color(0.45, 0.68, 0.95, 0.85)
	st.set_border_width_all(1)
	st.set_corner_radius_all(10)
	st.content_margin_left = 8
	st.content_margin_right = 10
	st.content_margin_top = 5
	st.content_margin_bottom = 5
	st.shadow_color = Color(0, 0, 0, 0.35)
	st.shadow_size = 4
	badge.add_theme_stylebox_override("panel", st)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(row)
	if _textures.has("ui_coin_skill"):
		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(20, 20)
		ic.texture = _textures["ui_coin_skill"]
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
	elif _textures.has("ui_xp"):
		var ic2 := TextureRect.new()
		ic2.custom_minimum_size = Vector2(20, 20)
		ic2.texture = _textures["ui_xp"]
		ic2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic2.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic2.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		ic2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic2)
	var lab := Label.new()
	lab.text = str(GameState.skill_points)
	lab.add_theme_font_size_override("font_size", 14)
	lab.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lab)
	var unit := Label.new()
	unit.text = "PC"
	unit.add_theme_font_size_override("font_size", 10)
	unit.add_theme_color_override("font_color", Color(0.70, 0.82, 0.95))
	unit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(unit)
	return badge


func _open_skill_tree() -> void:
	if skill_tree_overlay == null:
		return
	_clear_finger_tutorial()
	_rebuild_skill_modal()
	skill_tree_overlay.z_index = 250
	skill_tree_overlay.top_level = true
	skill_tree_overlay.visible = true
	skill_tree_overlay.move_to_front()


func _on_level(_level: int, _sp: int) -> void:
	_refresh_player_hud()
	if skill_tree_overlay and skill_tree_overlay.visible:
		call_deferred("_rebuild_skill_modal")


func _refresh_player_hud() -> void:
	var level := GameState.player_level
	var sp := GameState.skill_points
	if player_level_label:
		player_level_label.text = "Nv.%d" % level
		player_level_label.add_theme_color_override("font_color", Color(0.22, 0.40, 0.28))
	_refresh_currencies()
	_refresh_prestige_bar()
	if skill_tree_button:
		skill_tree_button.text = "Arbre de\nCompetences"
		_apply_skill_tree_button_icon()
		skill_tree_button.tooltip_text = ""
		var pill_host := skill_tree_button.get_node_or_null("SpPillHost") as Control
		var pill := skill_tree_button.get_node_or_null("SpPillHost/SpPill") as Label
		if pill_host and pill:
			pill.text = "!" if sp <= 9 else str(mini(sp, 99))
			pill_host.visible = sp > 0
			if sp > 0:
				skill_tree_button.tooltip_text = "%d point%s de competence a depenser" % [sp, "s" if sp > 1 else ""]
			else:
				skill_tree_button.tooltip_text = "Arbre de competences"


func _apply_skill_tree_button_icon() -> void:
	if skill_tree_button == null:
		return
	if _textures.has("ui_skill_tree"):
		skill_tree_button.icon = _textures["ui_skill_tree"]
		skill_tree_button.expand_icon = true
		skill_tree_button.add_theme_constant_override("icon_max_width", 52)
		skill_tree_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		skill_tree_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		skill_tree_button.icon = null


func _apply_settings_button_icon() -> void:
	if settings_button == null:
		return
	if _textures.has("ui_settings"):
		settings_button.icon = _textures["ui_settings"]
		settings_button.text = ""
		settings_button.expand_icon = true
		settings_button.add_theme_constant_override("icon_max_width", 40)
		settings_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		settings_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif settings_button.text == "?":
		settings_button.add_theme_font_size_override("font_size", 16)

func _style_bar_overlay_label(lab: Label, _fill: Color = Color.WHITE, _outline: Color = Color.BLACK) -> void:
	## Blanc + contour noir : lisible sur barre vide comme remplie.
	lab.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lab.add_theme_constant_override("outline_size", 5)


func _clamp_side_panels() -> void:
	## Layout confort HD (1280?720) : ratios fluides, sans d?bordement.
	## Sur iPhone paysage (Dynamic Island / notch), marge extra seulement
	## du c?t? o? l?inset r?el d?passe le seuil ? sinon marges de base.
	var left_p := get_node_or_null("%LeftPanel") as Control
	var right_p := get_node_or_null("%RightPanel") as Control
	var center := get_node_or_null("Root/Body/Center") as Control
	if left_p:
		left_p.custom_minimum_size = Vector2.ZERO
		left_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left_p.size_flags_stretch_ratio = 0.24
		left_p.clip_contents = true
	if center:
		center.custom_minimum_size = Vector2.ZERO
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center.size_flags_stretch_ratio = 0.48
		center.clip_contents = true
	if right_p:
		right_p.custom_minimum_size = Vector2.ZERO
		right_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right_p.size_flags_stretch_ratio = 0.28
		right_p.clip_contents = true
	var body := get_node_or_null("Root/Body") as HBoxContainer
	if body:
		body.add_theme_constant_override("separation", 12)
		body.clip_contents = true
	var root := get_node_or_null("Root") as Control
	if root:
		var safe := _safe_area_extra_margins()
		root.offset_left = 10.0 + safe.x
		root.offset_top = 8.0 + safe.y
		root.offset_right = -(10.0 + safe.z)
		root.offset_bottom = -(8.0 + safe.w)
		root.clip_contents = true
	var seed_row_node := get_node_or_null("%SeedRow") as Control
	if seed_row_node:
		seed_row_node.add_theme_constant_override("separation", 8)
	# Ajuste la largeur du contenu des scrolls au panneau (?vite collapse / overflow)
	call_deferred("_layout_seed_chips")
	call_deferred("_fit_scroll_widths")


func _safe_area_extra_margins() -> Vector4:
	## Retourne (left, top, right, bottom) en px viewport.
	## N?ajoute de marge que si l?inset CSS/?cran est significatif (notch / island).
	const CSS_THRESH := 14.0
	var insets := _read_raw_safe_insets_css() ## L,T,R,B en px CSS / ?cran
	if insets == Vector4.ZERO:
		return Vector4.ZERO
	var vp := get_viewport().get_visible_rect().size
	var win := _read_css_window_size()
	var sx := vp.x / maxf(win.x, 1.0)
	var sy := vp.y / maxf(win.y, 1.0)
	var out := Vector4.ZERO
	if insets.x >= CSS_THRESH:
		out.x = insets.x * sx
	if insets.y >= CSS_THRESH:
		out.y = insets.y * sy
	if insets.z >= CSS_THRESH:
		out.z = insets.z * sx
	if insets.w >= CSS_THRESH:
		out.w = insets.w * sy
	return out


func _read_css_window_size() -> Vector2:
	if OS.has_feature("web"):
		var raw: Variant = JavaScriptBridge.eval(
			"(function(){var s=window.ceiSafeInsets?window.ceiSafeInsets():null;return s?JSON.stringify({w:s.w,h:s.h}):'{\"w\":1,\"h\":1}';})()",
			true
		)
		if raw != null:
			var data: Variant = JSON.parse_string(str(raw))
			if typeof(data) == TYPE_DICTIONARY:
				var d: Dictionary = data
				return Vector2(float(d.get("w", 1.0)), float(d.get("h", 1.0)))
	return get_viewport().get_visible_rect().size


func _read_raw_safe_insets_css() -> Vector4:
	## L,T,R,B en pixels CSS (web) ou d?riv?s de DisplayServer (natif).
	if OS.has_feature("web"):
		var raw: Variant = JavaScriptBridge.eval(
			"(function(){var s=window.ceiSafeInsets?window.ceiSafeInsets():null;return s?JSON.stringify(s):'{\"l\":0,\"t\":0,\"r\":0,\"b\":0,\"w\":1,\"h\":1}';})()",
			true
		)
		if raw == null:
			return Vector4.ZERO
		var data: Variant = JSON.parse_string(str(raw))
		if typeof(data) != TYPE_DICTIONARY:
			return Vector4.ZERO
		var d: Dictionary = data
		return Vector4(
			float(d.get("l", 0.0)),
			float(d.get("t", 0.0)),
			float(d.get("r", 0.0)),
			float(d.get("b", 0.0))
		)
	## iOS / Android natif
	var safe := DisplayServer.get_display_safe_area()
	var full := Rect2i(Vector2i.ZERO, DisplayServer.window_get_size())
	if full.size.x <= 0 or full.size.y <= 0:
		return Vector4.ZERO
	## Convertit la safe area ?cran ? insets (approx. fen?tre principale).
	var left := float(maxi(0, safe.position.x - full.position.x))
	var top := float(maxi(0, safe.position.y - full.position.y))
	var right := float(maxi(0, (full.position.x + full.size.x) - (safe.position.x + safe.size.x)))
	var bottom := float(maxi(0, (full.position.y + full.size.y) - (safe.position.y + safe.size.y)))
	return Vector4(left, top, right, bottom)


func _fit_scroll_widths() -> void:
	_fit_scroll_child_width(get_node_or_null("%MissionScroll") as ScrollContainer, get_node_or_null("%MissionList") as Control)
	_fit_scroll_child_width(get_node_or_null("%SideScroll") as ScrollContainer, get_node_or_null("%SideContent") as Control)


func _fit_scroll_child_width(scroll: ScrollContainer, content: Control) -> void:
	if scroll == null or content == null:
		return
	var w := scroll.size.x
	if w < 8.0:
		return
	## Laisse de la place ? la barre de scroll verticale (?vite que les cards collent).
	var scroll_gap := 14.0
	content.custom_minimum_size.x = maxf(8.0, w - scroll_gap)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _on_tutorial_nudge(kind: StringName) -> void:
	var changed := kind != _last_tutorial_nudge
	_last_tutorial_nudge = kind
	## Une seule ic?ne partout : main + cercle de clic.
	const CLICK_ICON := "ui_click_hand"
	match kind:
		&"plant":
			_tutorial_mode = &"plant"
			var cname := GameState.crop_display_name(GameState.tutorial_next_crop_id())
			_select_tutorial_seed_if_needed()
			_show_finger_tutorial("Planter", CLICK_ICON)
			if changed:
				_show_toast("Tuto - Plante une %s (parcelle vide)." % cname)
		&"switch_seed":
			_tutorial_mode = &"switch_seed"
			var cname2 := GameState.crop_display_name(GameState.tutorial_next_crop_id())
			_show_finger_tutorial("Graine", CLICK_ICON)
			if changed:
				_show_toast("Tuto - Change de graine : clique %s en bas." % cname2)
		&"accelerate":
			_tutorial_mode = &"accelerate"
			_show_finger_tutorial("Augmenter la rapidite", CLICK_ICON)
			if changed:
				_show_toast("Tuto - Clique la plante pour augmenter la rapidite.")
		&"harvest":
			_tutorial_mode = &"harvest"
			_show_finger_tutorial("Recolte", CLICK_ICON)
			if changed:
				_show_toast("Tuto - Pret ! Clique pour recolter.")
		&"deliver":
			_tutorial_mode = &"deliver"
			_show_finger_tutorial("Livrer", CLICK_ICON)
			if changed:
				_show_toast("Tuto - Livre la commande (1 tomate, 1 carotte, 1 poivron).")
				_pulse_deliver_hint()
		&"sell":
			_tutorial_mode = &"sell"
			_select_tutorial_sell_seed()
			_rebuild_stock()
			_show_finger_tutorial("Stock", CLICK_ICON)
			if _finger_tutorial:
				_finger_tutorial.z_index = 90
			if changed:
				_show_toast("Tuto - Clique Stock sous le poivron pour vendre.")
		&"sell_confirm":
			_tutorial_mode = &"sell_confirm"
			_show_finger_tutorial("Vendre", CLICK_ICON)
			if _finger_tutorial:
				_finger_tutorial.z_index = 300
			if changed:
				_show_toast("Tuto - Appuie sur Vendre.")
		&"missions_tab":
			_tutorial_mode = &"missions_tab"
			_show_finger_tutorial("Missions", CLICK_ICON)
			if _finger_tutorial:
				_finger_tutorial.z_index = 90
			if changed:
				_show_toast("Tuto - Ouvre l'onglet Missions.")
		&"claim_mission":
			_tutorial_mode = &"claim_mission"
			_show_finger_tutorial("Recuperer", CLICK_ICON)
			if _finger_tutorial:
				_finger_tutorial.z_index = 90
			if changed:
				_show_toast("Tuto - Recupere la recompense de la mission.")
		&"terrain_edit":
			_tutorial_mode = &"terrain_edit"
			_update_edit_terrain_button()
			_show_finger_tutorial("Editer", CLICK_ICON)
			if _finger_tutorial:
				_finger_tutorial.z_index = 95
			if changed:
				_show_toast("Tuto - Nouvelle parcelle placee ! Clique Editer pour reorganiser ton champ.")
		&"tutorial_done":
			_tutorial_mode = &""
			_last_tutorial_nudge = &""
			_clear_finger_tutorial()
			_rebuild_stock()
			_select_tab("boosts")


func _select_tutorial_sell_seed() -> void:
	var want := GameState.TUTORIAL_SELL_CROP
	for i in GameState.crops.size():
		if GameState.crops[i].id == want:
			_on_seed_picked(i)
			return


func _pulse_deliver_hint() -> void:
	## Met en avant le panneau commandes pendant l'?tape livrer.
	var left := get_node_or_null("%LeftPanel") as Control
	if left == null:
		return
	var tw := create_tween()
	tw.tween_property(left, "modulate", Color(1.08, 1.12, 0.85, 1.0), 0.25)
	tw.tween_property(left, "modulate", Color.WHITE, 0.45)


func _show_finger_tutorial(hint_text: String = "Clic", icon_key: String = "ui_click_hand") -> void:
	_clear_finger_tutorial()
	var host := Control.new()
	host.name = "FingerTutorial"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.z_index = 90
	host.top_level = true
	host.custom_minimum_size = Vector2(96, 100)
	add_child(host)
	_finger_tutorial = host
	_finger_plot_index = -1
	_resolve_tutorial_plot()

	var icon_size := 56.0
	## Bout de l'index en haut-gauche de l'asset click_hand (~15%/14%).
	_finger_hotspot = Vector2(0.18, 0.16) * icon_size

	var icon := TextureRect.new()
	icon.name = "TutIcon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.size = Vector2(icon_size, icon_size)
	icon.position = Vector2.ZERO
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var key := icon_key
	if not _textures.has(key):
		key = "ui_click_hand" if _textures.has("ui_click_hand") else ""
	if key != "" and _textures.has(key):
		icon.texture = _textures[key]
	## Pivot = hotspot (l'index ? appuie ? sur la cible)
	icon.pivot_offset = _finger_hotspot
	host.add_child(icon)
	_finger_anim = icon
	_finger_aura = null

	var hint := Label.new()
	hint.text = hint_text
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.95, 0.92, 0.35, 1.0))
	hint.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.04, 0.9))
	hint.add_theme_constant_override("outline_size", 4)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.position = Vector2(-12, icon_size + 2)
	hint.size = Vector2(96, 36)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(hint)
	_finger_label = hint

	_snap_finger_to_plot()
	_play_finger_click_anim(icon)


func _play_finger_click_anim(icon: Control) -> void:
	## Mouvement type clic : l'index avance vers la cible (haut-gauche) puis revient.
	if icon == null:
		return
	var rest := Vector2.ZERO
	var press := Vector2(-3, -6)
	var tw := create_tween().set_loops()
	tw.tween_property(icon, "position", press, 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(icon, "scale", Vector2(0.92, 0.92), 0.11)
	tw.tween_callback(func():
		if is_instance_valid(icon):
			icon.modulate = Color(1.2, 1.25, 0.95, 1.0)
		if _finger_label and is_instance_valid(_finger_label):
			_finger_label.modulate = Color(1.25, 1.2, 0.55, 1.0)
	)
	tw.tween_property(icon, "position", rest, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(icon, "scale", Vector2.ONE, 0.18)
	tw.parallel().tween_property(icon, "modulate", Color.WHITE, 0.18)
	if _finger_label and is_instance_valid(_finger_label):
		tw.parallel().tween_property(_finger_label, "modulate", Color.WHITE, 0.18)
	tw.tween_interval(0.55)


func _resolve_tutorial_plot() -> void:
	_finger_plot_index = -1
	if _tutorial_mode == &"plant":
		for tile in _plot_tiles:
			var p: Dictionary = GameState.plots[tile.index]
			if p["unlocked"] and p["crop"] == null:
				_finger_plot_index = tile.index
				return
	elif _tutorial_mode == &"accelerate":
		for tile in _plot_tiles:
			var p: Dictionary = GameState.plots[tile.index]
			if p["crop"] != null and not p["ready"]:
				_finger_plot_index = tile.index
				return
	elif _tutorial_mode == &"harvest":
		for tile in _plot_tiles:
			var p: Dictionary = GameState.plots[tile.index]
			if p["crop"] != null and p["ready"]:
				_finger_plot_index = tile.index
				return


func _finger_anchor_to_global(anchor: Vector2) -> Vector2:
	## Bout de l'index (haut-gauche de l'asset) align? sur la cible.
	return anchor - _finger_hotspot + _finger_target_nudge


func _snap_finger_to_plot() -> void:
	if _finger_tutorial == null or not is_instance_valid(_finger_tutorial):
		return
	_resolve_tutorial_plot()
	var anchor := Vector2(get_viewport_rect().size.x * 0.5, get_viewport_rect().size.y * 0.42)

	if _tutorial_mode == &"switch_seed":
		var next_id := GameState.tutorial_next_crop_id()
		for chip in _seed_buttons:
			if not is_instance_valid(chip):
				continue
			if chip.get_meta("crop_id", &"") == next_id:
				var rect := chip.get_global_rect()
				anchor = rect.position + Vector2(rect.size.x * 0.70, rect.size.y * 0.55)
				_finger_tutorial.global_position = _finger_anchor_to_global(anchor)
				return
	elif _tutorial_mode == &"deliver":
		var btn := _find_tut_deliver_btn()
		if btn:
			var rect := btn.get_global_rect()
			anchor = rect.position + rect.size * 0.5
			_finger_tutorial.global_position = _finger_anchor_to_global(anchor)
			return
		var left := get_node_or_null("%LeftPanel") as Control
		if left:
			var rect := left.get_global_rect()
			anchor = rect.position + Vector2(rect.size.x * 0.82, 150)
			_finger_tutorial.global_position = _finger_anchor_to_global(anchor)
			return
	elif _tutorial_mode == &"sell":
		var sell_btn := _find_tut_sell_btn()
		if sell_btn:
			var rect := sell_btn.get_global_rect()
			anchor = rect.position + Vector2(rect.size.x * 0.55, rect.size.y * 0.55)
			_finger_tutorial.global_position = _finger_anchor_to_global(anchor)
			return
	elif _tutorial_mode == &"sell_confirm":
		var confirm := _find_tut_sell_confirm_btn()
		if confirm:
			var rect := confirm.get_global_rect()
			anchor = rect.position + rect.size * 0.5
			_finger_tutorial.global_position = _finger_anchor_to_global(anchor)
			return
	elif _tutorial_mode == &"missions_tab":
		var tab_btn := _find_tut_missions_tab_btn()
		if tab_btn:
			var rect := tab_btn.get_global_rect()
			anchor = rect.position + rect.size * 0.5
			_finger_tutorial.global_position = _finger_anchor_to_global(anchor)
			return
	elif _tutorial_mode == &"claim_mission":
		var claim := _find_tut_claim_btn()
		if claim:
			var rect := claim.get_global_rect()
			anchor = rect.position + rect.size * 0.5
			_finger_tutorial.global_position = _finger_anchor_to_global(anchor)
			return
	elif _tutorial_mode == &"terrain_edit":
		if _edit_terrain_btn != null and is_instance_valid(_edit_terrain_btn) and _edit_terrain_btn.visible:
			var rect := _edit_terrain_btn.get_global_rect()
			anchor = rect.position + rect.size * 0.5
			_finger_tutorial.global_position = _finger_anchor_to_global(anchor)
			return

	if _finger_plot_index >= 0:
		for tile in _plot_tiles:
			if tile.index == _finger_plot_index:
				var rect := tile.get_global_rect()
				# Bas-droite terre / l?gume
				anchor = rect.position + Vector2(rect.size.x * 0.70, rect.size.y * 0.60)
				break
	_finger_tutorial.global_position = _finger_anchor_to_global(anchor)


func _find_tut_deliver_btn() -> Control:
	if _tut_deliver_btn != null and is_instance_valid(_tut_deliver_btn):
		return _tut_deliver_btn
	if mission_list == null:
		return null
	for n in mission_list.find_children("*", "Button", true, false):
		if n.has_meta("tut_deliver_btn"):
			_tut_deliver_btn = n as Control
			return _tut_deliver_btn
	return null


func _find_tut_sell_btn() -> Control:
	## Bouton Stock du l?gume offert pendant l??tape vente.
	var want := GameState.TUTORIAL_SELL_CROP
	for chip in _seed_buttons:
		if not is_instance_valid(chip):
			continue
		if chip.get_meta("crop_id", &"") != want:
			continue
		if chip.has_meta("sell_btn"):
			var b: Variant = chip.get_meta("sell_btn")
			if b is Control and is_instance_valid(b):
				return b as Control
	return null


func _find_tut_sell_confirm_btn() -> Control:
	if is_instance_valid(_active_sell_modal):
		var btn: Button = _active_sell_modal.get_confirm_button()
		if btn != null and is_instance_valid(btn):
			return btn
	return null


func _find_tut_missions_tab_btn() -> Control:
	if _tab_buttons.has("missions"):
		var b: Variant = _tab_buttons["missions"]
		if b is Control and is_instance_valid(b):
			return b as Control
	return null


func _find_tut_claim_btn() -> Control:
	if side_content == null:
		return null
	for n in side_content.find_children("*", "Button", true, false):
		if n.has_meta("tut_claim_btn"):
			return n as Control
	return null


func _clear_finger_tutorial() -> void:
	if _finger_tutorial and is_instance_valid(_finger_tutorial):
		_finger_tutorial.queue_free()
	_finger_tutorial = null
	_finger_anim = null
	_finger_label = null
	_finger_aura = null
	_finger_plot_index = -1


func _update_finger_tutorial(_delta: float) -> void:
	## Tuto terrain (post-tuto principal) : garder le doigt sur Editer.
	if _tutorial_mode == &"terrain_edit":
		if _finger_tutorial == null or not is_instance_valid(_finger_tutorial):
			_show_finger_tutorial("Editer", "ui_click_hand")
			if _finger_tutorial:
				_finger_tutorial.z_index = 95
		_snap_finger_to_plot()
		return
	if GameState.is_tutorial_done():
		if _finger_tutorial and is_instance_valid(_finger_tutorial):
			_clear_finger_tutorial()
		return
	## Suit l'?tat r?el (+ modal vente / onglet missions pendant le tuto)
	var want := _resolve_tutorial_want()
	if want == &"":
		return
	var need_finger := _finger_tutorial == null or not is_instance_valid(_finger_tutorial)
	if want != _tutorial_mode or need_finger:
		_on_tutorial_nudge(want)
		return
	_snap_finger_to_plot()


func _resolve_tutorial_want() -> StringName:
	var want := GameState.tutorial_guidance_kind()
	if want == &"sell" and is_instance_valid(_active_sell_modal):
		return &"sell_confirm"
	if want == &"missions_tab" and _current_tab == "missions":
		return &"claim_mission"
	return want


func _bind_tabs() -> void:
	var strip := get_node_or_null("%TabStrip") as PanelContainer
	if strip:
		var strip_st := StyleBoxFlat.new()
		strip_st.bg_color = Color(0.88, 0.92, 0.86, 0.72)
		strip_st.border_color = Color(0.28, 0.38, 0.30, 0.28)
		strip_st.set_border_width_all(1)
		strip_st.set_corner_radius_all(12)
		strip_st.content_margin_left = 4
		strip_st.content_margin_right = 4
		strip_st.content_margin_top = 4
		strip_st.content_margin_bottom = 4
		strip_st.shadow_color = Color(0.08, 0.12, 0.10, 0.24)
		strip_st.shadow_size = 4
		strip_st.shadow_offset = Vector2(0, 2)
		strip.add_theme_stylebox_override("panel", strip_st)
		strip.custom_minimum_size = Vector2(0, 50)
	var rail: HBoxContainer = %TabRail
	for c in rail.get_children():
		c.free()
	_tab_buttons.clear()
	var group := ButtonGroup.new()
	group.allow_unpress = false
	rail.add_theme_constant_override("separation", 3)
	rail.alignment = BoxContainer.ALIGNMENT_CENTER
	for tab in RIGHT_TABS:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_group = group
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(0, 40)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.theme_type_variation = &"ButtonTab"
		btn.expand_icon = true
		btn.text = str(tab["title"])
		btn.add_theme_font_size_override("font_size", 11)
		btn.tooltip_text = str(tab.get("hint", tab["title"]))
		var icon_key: String = tab["icon"]
		if _textures.has(icon_key):
			btn.icon = _textures[icon_key]
		var tab_id: String = tab["id"]
		btn.pressed.connect(func(): _select_tab(tab_id))
		if tab_id == "missions":
			_attach_tab_alert_pill(btn)
		rail.add_child(btn)
		_tab_buttons[tab_id] = btn
	# Header "Shop" redondant ? masquer via n?uds uniques (UpgradeHeader n'a pas de %)
	var up_icon := get_node_or_null("%UpgradeIcon") as Control
	if up_icon and up_icon.get_parent():
		(up_icon.get_parent() as Control).visible = false
	var hint_l := get_node_or_null("%UpgradeHint") as Control
	if hint_l:
		hint_l.visible = false
	_select_tab(_current_tab)
	_refresh_missions_tab_alert()


func _attach_tab_alert_pill(btn: Button) -> void:
	if btn.get_node_or_null("TabAlertPill") != null:
		return
	var pill_bg := PanelContainer.new()
	pill_bg.name = "TabAlertPill"
	pill_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_bg.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pill_bg.offset_left = -14
	pill_bg.offset_top = -6
	pill_bg.offset_right = 4
	pill_bg.offset_bottom = 10
	var pst := StyleBoxFlat.new()
	pst.bg_color = Color(0.88, 0.18, 0.18, 1.0)
	pst.set_corner_radius_all(9)
	pst.content_margin_left = 4
	pst.content_margin_right = 4
	pst.content_margin_top = 0
	pst.content_margin_bottom = 0
	pill_bg.add_theme_stylebox_override("panel", pst)
	var pill := Label.new()
	pill.name = "PillLabel"
	pill.text = "!"
	pill.add_theme_font_size_override("font_size", 11)
	pill.add_theme_color_override("font_color", Color(1, 0.95, 0.95))
	pill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_bg.add_child(pill)
	pill_bg.visible = false
	btn.add_child(pill_bg)


func _refresh_missions_tab_alert() -> void:
	if not _tab_buttons.has("missions"):
		return
	var btn: Button = _tab_buttons["missions"]
	var pill := btn.get_node_or_null("TabAlertPill") as Control
	if pill == null:
		return
	var n := GameState.count_claimable_board_quests()
	pill.visible = n > 0
	var lab := pill.get_node_or_null("PillLabel") as Label
	if lab:
		lab.text = "!" if n <= 9 else str(mini(n, 99))


func _tab_def(id: String) -> Dictionary:
	for tab in RIGHT_TABS:
		if tab["id"] == id:
			return tab
	return RIGHT_TABS[0]


func _select_tab(id: String) -> void:
	for tid in _tab_buttons:
		var b: Button = _tab_buttons[tid]
		var on: bool = tid == id
		b.set_pressed_no_signal(on)
		b.z_index = 2 if on else 0
		_style_side_tab_button(b, tid, on)
	_show_tab(id)


func _style_side_tab_button(btn: Button, tab_id: String, selected: bool) -> void:
	var tab := _tab_def(tab_id)
	var accent: Color = tab.get("accent", Color(0.55, 0.70, 0.40))
	var normal := StyleBoxFlat.new()
	var hover := StyleBoxFlat.new()
	var pressed := StyleBoxFlat.new()
	if selected:
		## Fond teint? accent, bien opaque + ombre ? lisible sur le panneau.
		normal.bg_color = Color(
			lerpf(0.96, accent.r, 0.42),
			lerpf(0.95, accent.g, 0.42),
			lerpf(0.90, accent.b, 0.42),
			0.96
		)
		normal.border_color = Color(accent.r, accent.g, accent.b, 0.85)
		normal.border_width_left = 0
		normal.border_width_top = 0
		normal.border_width_right = 0
		normal.border_width_bottom = 3
		normal.corner_radius_top_left = 10
		normal.corner_radius_top_right = 10
		normal.corner_radius_bottom_left = 4
		normal.corner_radius_bottom_right = 4
		normal.shadow_color = Color(accent.r * 0.35, accent.g * 0.35, accent.b * 0.35, 0.35)
		normal.shadow_size = 5
		normal.shadow_offset = Vector2(0, 2)
		btn.modulate = Color.WHITE
		btn.add_theme_color_override("font_color", Color(0.12, 0.14, 0.12))
		btn.add_theme_color_override("font_pressed_color", Color(0.12, 0.14, 0.12))
		btn.add_theme_color_override("font_hover_color", Color(0.08, 0.10, 0.08))
		btn.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.55))
		btn.add_theme_constant_override("outline_size", 2)
	else:
		normal.bg_color = Color(0.94, 0.96, 0.92, 0.78)
		normal.border_color = Color(0.22, 0.30, 0.24, 0.22)
		normal.set_border_width_all(1)
		normal.set_corner_radius_all(10)
		normal.shadow_color = Color(0.08, 0.12, 0.10, 0.26)
		normal.shadow_size = 3
		normal.shadow_offset = Vector2(0, 2)
		btn.modulate = Color.WHITE
		btn.add_theme_color_override("font_color", Color(0.18, 0.24, 0.18))
		btn.add_theme_color_override("font_hover_color", Color(0.10, 0.16, 0.10))
		btn.add_theme_color_override("font_pressed_color", Color(0.10, 0.16, 0.10))
		btn.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.35))
		btn.add_theme_constant_override("outline_size", 1)
	normal.content_margin_left = 4
	normal.content_margin_right = 4
	normal.content_margin_top = 5
	normal.content_margin_bottom = 5
	hover = normal.duplicate() as StyleBoxFlat
	if not selected:
		hover.bg_color = Color(0.98, 0.99, 0.96, 0.92)
		hover.border_color = Color(accent.r, accent.g, accent.b, 0.45)
		hover.shadow_size = 4
		hover.shadow_color = Color(0.08, 0.12, 0.10, 0.30)
	else:
		hover.bg_color = Color(
			lerpf(0.98, accent.r, 0.38),
			lerpf(0.97, accent.g, 0.38),
			lerpf(0.92, accent.b, 0.38),
			0.98
		)
	pressed = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(
		lerpf(0.90, accent.r, 0.35),
		lerpf(0.90, accent.g, 0.35),
		lerpf(0.86, accent.b, 0.35),
		0.92
	) if selected else Color(0.88, 0.90, 0.86, 0.85)
	pressed.shadow_size = 2
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", pressed)
	btn.add_theme_font_size_override("font_size", 11)


func _show_tab(id: String) -> void:
	_current_tab = id
	_rebuild_side()


func _on_plots_changed() -> void:
	if _rebuilding_ui:
		return
	## Grille fixe 10x10 : rebuild seulement si le nombre de tuiles a change.
	if _plot_tiles.size() != GameState.MAX_PLOTS:
		_build_iso_field()
	else:
		_update_plot_visuals()
		## Recadrer seulement si le nombre de terres change (pas a chaque recolte).
		var land := GameState.land_placed()
		if land != _last_centered_land:
			_last_centered_land = land
			call_deferred("_center_field")
	_update_edit_terrain_button()


func _clear_field_host_children() -> void:
	## free() imm?diat : queue_free laisse d'anciennes tuiles 1 frame ? layout / center foireux.
	if field_host == null:
		return
	var kids := field_host.get_children()
	for c in kids:
		field_host.remove_child(c)
		c.free()


func _build_iso_field() -> void:
	_clear_field_host_children()
	_plot_tiles.clear()
	_plot_base_positions.clear()
	_hovered_plot = null
	_drag_done.clear()
	_field_layer = null
	_field_zoom = 1.0

	_shown_unlocked = GameState.MAX_PLOTS
	if field_host == null:
		return

	field_host.clip_contents = true
	field_host.scale = Vector2.ONE

	_field_layer = Control.new()
	_field_layer.name = "FieldLayer"
	_field_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field_host.add_child(_field_layer)

	var cols: int = GameState.GRID_W
	var rows: int = GameState.GRID_H
	for row in rows:
		for col in cols:
			var i: int = row * cols + col
			var tile: PlotTile = PLOT_SCENE.instantiate()
			_field_layer.add_child(tile)
			tile.setup(i, _textures)
			tile.scale = Vector2.ONE
			var base := Vector2((col - row) * ISO_W, (col + row) * ISO_H)
			tile.position = base
			_plot_base_positions.append(base)
			tile.z_index = col + row
			_plot_tiles.append(tile)
			if not tile.fertilizer_pulse.is_connected(_on_fertilizer_pulse):
				tile.fertilizer_pulse.connect(_on_fertilizer_pulse)

	# Ordre de dessin seulement ? garder _plot_tiles[i] == parcelle i
	var draw_order: Array[PlotTile] = _plot_tiles.duplicate()
	draw_order.sort_custom(func(a: PlotTile, b: PlotTile): return a.z_index < b.z_index)
	for tile in draw_order:
		_field_layer.move_child(tile, _field_layer.get_child_count() - 1)

	call_deferred("_center_field")
	call_deferred("_update_plot_visuals")
	_update_edit_terrain_button()


func _setup_edit_terrain_button() -> void:
	var stack := get_node_or_null("Root/Body/Center/FieldFrame/FieldStack") as Control
	if stack == null:
		return
	if _edit_terrain_btn != null and is_instance_valid(_edit_terrain_btn):
		_update_edit_terrain_button()
		return
	_edit_terrain_btn = Button.new()
	_edit_terrain_btn.name = "EditTerrainButton"
	_edit_terrain_btn.text = "Editer"
	_edit_terrain_btn.focus_mode = Control.FOCUS_NONE
	_edit_terrain_btn.custom_minimum_size = Vector2(96, 34)
	_edit_terrain_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	## Coin haut-droit du champ
	_edit_terrain_btn.offset_left = -108
	_edit_terrain_btn.offset_top = 6
	_edit_terrain_btn.offset_right = -6
	_edit_terrain_btn.offset_bottom = 40
	_edit_terrain_btn.z_index = 20
	_edit_terrain_btn.tooltip_text = "Placer terres et machines"
	_edit_terrain_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_edit_terrain_btn.expand_icon = true
	_edit_terrain_btn.add_theme_constant_override("icon_max_width", 20)
	_edit_terrain_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_edit_terrain_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_edit_terrain_btn.pressed.connect(_open_terrain_edit)
	stack.add_child(_edit_terrain_btn)

	_edit_terrain_badge = Panel.new()
	_edit_terrain_badge.name = "EditTerrainBadge"
	_edit_terrain_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edit_terrain_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_edit_terrain_badge.offset_left = -5
	_edit_terrain_badge.offset_top = -4
	_edit_terrain_badge.offset_right = 7
	_edit_terrain_badge.offset_bottom = 8
	_edit_terrain_badge.z_index = 2
	var bst := StyleBoxFlat.new()
	bst.bg_color = Color(0.92, 0.22, 0.20, 1.0)
	bst.border_color = Color(1.0, 0.92, 0.90, 0.95)
	bst.set_border_width_all(1)
	bst.set_corner_radius_all(8)
	_edit_terrain_badge.add_theme_stylebox_override("panel", bst)
	_edit_terrain_badge.visible = false
	_edit_terrain_btn.add_child(_edit_terrain_badge)

	_update_edit_terrain_button()


func _has_unplaced_machines() -> bool:
	return GameState.fertilizer_unplaced() > 0 or GameState.gardener_unplaced() > 0


func _update_edit_terrain_button() -> void:
	if _edit_terrain_btn == null or not is_instance_valid(_edit_terrain_btn):
		return
	_edit_terrain_btn.visible = GameState.is_terrain_edit_unlocked()
	if _textures.has("ui_edit_pen"):
		_edit_terrain_btn.icon = _textures["ui_edit_pen"]
	if _edit_terrain_badge != null and is_instance_valid(_edit_terrain_badge):
		_edit_terrain_badge.visible = _edit_terrain_btn.visible and _has_unplaced_machines()


func _open_terrain_edit() -> void:
	if not GameState.is_terrain_edit_unlocked():
		return
	if _active_terrain_modal != null and is_instance_valid(_active_terrain_modal):
		return
	if _tutorial_mode == &"terrain_edit":
		_tutorial_mode = &""
		_clear_finger_tutorial()
	var modal: Control = TerrainEditModalScript.present(self, _textures)
	_active_terrain_modal = modal
	if modal.has_signal("closed"):
		modal.closed.connect(func(_applied: bool):
			_active_terrain_modal = null
			_update_plot_visuals()
			call_deferred("_center_field")
			_rebuild_side()
			_update_edit_terrain_button()
			_clear_finger_tutorial()
		)


func _center_field() -> void:
	## Centre + d?zoom progressif pour faire rentrer jusqu?? 10?10 dans FieldHost.
	if _plot_tiles.is_empty() or field_host == null or _field_layer == null:
		return
	if not is_instance_valid(_field_layer):
		return
	if field_host.size.x < 8.0 or field_host.size.y < 8.0:
		return
	if _plot_base_positions.size() != _plot_tiles.size():
		return

	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	var any_land := false
	for i in _plot_tiles.size():
		var tile: PlotTile = _plot_tiles[i]
		if not is_instance_valid(tile):
			continue
		## Ne cadrer que les terres placees (?vite le zoom ? grille ?dition ?).
		if i >= GameState.plots.size() or not bool(GameState.plots[i].get("unlocked", false)):
			continue
		any_land = true
		var pos: Vector2 = _plot_base_positions[i]
		var sz := tile.size
		if sz.x < 1.0:
			sz = tile.custom_minimum_size
		if sz.x < 1.0:
			sz = Vector2(104, 182)
		min_x = minf(min_x, pos.x)
		max_x = maxf(max_x, pos.x + sz.x)
		min_y = minf(min_y, pos.y)
		max_y = maxf(max_y, pos.y + sz.y)

	if not any_land or not is_finite(min_x) or not is_finite(max_x):
		return

	var content_w := maxf(1.0, max_x - min_x)
	var content_h := maxf(1.0, max_y - min_y)
	## Marge pour 1?peu de parcelles : ne pas trop zoomer non plus.
	var margin := 0.78 if GameState.land_placed() <= 4 else 0.90
	var zoom_x := (field_host.size.x * margin) / content_w
	var zoom_y := (field_host.size.y * margin) / content_h
	_field_zoom = clampf(minf(zoom_x, zoom_y), 0.35, 1.15)
	_last_centered_land = GameState.land_placed()

	## Positions locales scale 1 (coin haut-gauche du contenu 0,0)
	for i in _plot_tiles.size():
		var tile: PlotTile = _plot_tiles[i]
		if not is_instance_valid(tile):
			continue
		if bool(tile.get_meta("_soil_shake", false)):
			continue
		tile.scale = Vector2.ONE
		tile.position = _plot_base_positions[i] - Vector2(min_x, min_y)

	_field_layer.scale = Vector2(_field_zoom, _field_zoom)
	var scaled_w := content_w * _field_zoom
	var scaled_h := content_h * _field_zoom
	_field_layer.position = (field_host.size - Vector2(scaled_w, scaled_h)) * 0.5


func _build_seed_bar() -> void:
	if seed_row == null:
		return
	var kids := seed_row.get_children()
	for c in kids:
		seed_row.remove_child(c)
		c.free()
	_seed_buttons.clear()
	var keys := ["1", "2", "3", "4", "5", "6"]
	var seed_style := _theme.get_stylebox("panel", "SeedCard") as StyleBoxFlat if _theme else _card_style
	var key_style := _theme.get_stylebox("panel", "Keycap") as StyleBoxFlat if _theme else null

	seed_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	seed_row.add_theme_constant_override("separation", 8)

	var scroll := get_node_or_null("%SeedScroll") as ScrollContainer
	if scroll and not scroll.resized.is_connected(_layout_seed_chips):
		scroll.resized.connect(_layout_seed_chips)

	for i in GameState.crops.size():
		var crop: CropData = GameState.crops[i]
		var unlocked := GameState.is_crop_unlocked(crop)
		var chip := PanelContainer.new()
		# Largeur g?r?e par _layout_seed_chips ; hauteur fixe confortable
		chip.custom_minimum_size = Vector2(0, 94)
		chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		chip.size_flags_stretch_ratio = 1.0
		chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if unlocked else Control.CURSOR_ARROW
		if seed_style:
			var st := seed_style.duplicate() as StyleBoxFlat
			st.content_margin_left = 5
			st.content_margin_right = 5
			st.content_margin_top = 4
			st.content_margin_bottom = 10  # marge sous stock / prestige
			chip.add_theme_stylebox_override("panel", st)

		var holder := Control.new()
		holder.custom_minimum_size = Vector2(0, 72)
		holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(holder)

		var time_row := HBoxContainer.new()
		time_row.add_theme_constant_override("separation", 2)
		time_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		time_row.set_anchors_preset(Control.PRESET_TOP_LEFT)
		time_row.offset_left = 2
		time_row.offset_top = 1
		time_row.offset_right = 44
		time_row.offset_bottom = 12
		if unlocked and _textures.has("ui_chrono"):
			var chron := TextureRect.new()
			chron.custom_minimum_size = Vector2(14, 14)
			chron.texture = _textures["ui_chrono"]
			chron.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			chron.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			chron.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			chron.mouse_filter = Control.MOUSE_FILTER_IGNORE
			time_row.add_child(chron)
		var time_l := Label.new()
		time_l.text = ("%.0fs" % crop.base_grow_time) if unlocked else "??"
		time_l.add_theme_font_size_override("font_size", 9)
		time_l.modulate = Color(0.45, 0.55, 0.50)
		time_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		time_row.add_child(time_l)
		holder.add_child(time_row)

		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 2
		v.offset_top = 12
		v.offset_right = -2
		v.offset_bottom = -6  # espace avant le bord bas (stock / prestige)
		v.add_theme_constant_override("separation", 2)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(v)

		var badge := PanelContainer.new()
		badge.custom_minimum_size = Vector2(30, 30)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var badge_st := StyleBoxFlat.new()
		if unlocked:
			badge_st.bg_color = Color(0.93, 0.95, 0.88, 0.98)
			badge_st.border_color = Color(0.55, 0.68, 0.48, 0.75)
		else:
			badge_st.bg_color = Color(0.42, 0.43, 0.45, 0.95)
			badge_st.border_color = Color(0.28, 0.28, 0.30, 0.80)
		badge_st.set_border_width_all(1)
		badge_st.set_corner_radius_all(15)
		badge_st.set_content_margin_all(3)
		badge.add_theme_stylebox_override("panel", badge_st)
		v.add_child(badge)

		var icon_key := "icon_%s" % String(crop.id)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _textures.has(icon_key):
			icon.texture = _textures[icon_key]
		if not unlocked:
			icon.modulate = Color(0.12, 0.12, 0.14, 0.95)
		badge.add_child(icon)

		var name_l := Label.new()
		name_l.text = crop.display_name if unlocked else "??"
		name_l.add_theme_font_size_override("font_size", 11)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_l.clip_text = true
		name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not unlocked:
			name_l.modulate = Color(0.45, 0.45, 0.48)
		v.add_child(name_l)

		var stock_ctrl: Control
		if unlocked:
			var stock_btn := Button.new()
			stock_btn.name = "StockCount"
			stock_btn.text = "Stock : x0"
			stock_btn.focus_mode = Control.FOCUS_NONE
			stock_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			stock_btn.tooltip_text = ""
			stock_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			stock_btn.add_theme_font_size_override("font_size", 9)
			stock_btn.add_theme_color_override("font_color", Color(0.48, 0.36, 0.10))
			stock_btn.add_theme_color_override("font_hover_color", Color(0.32, 0.22, 0.06))
			stock_btn.add_theme_color_override("font_pressed_color", Color(0.28, 0.18, 0.04))
			stock_btn.add_theme_color_override("font_disabled_color", Color(0.50, 0.55, 0.50))
			## L?ger bouton texte (pas d?ic?ne bourse).
			var sn := StyleBoxFlat.new()
			sn.bg_color = Color(0.92, 0.88, 0.72, 0.55)
			sn.border_color = Color(0.72, 0.58, 0.22, 0.55)
			sn.set_border_width_all(1)
			sn.set_corner_radius_all(6)
			sn.content_margin_left = 6
			sn.content_margin_right = 6
			sn.content_margin_top = 2
			sn.content_margin_bottom = 2
			stock_btn.add_theme_stylebox_override("normal", sn)
			var sh := sn.duplicate() as StyleBoxFlat
			sh.bg_color = Color(0.96, 0.90, 0.62, 0.85)
			sh.border_color = Color(0.78, 0.58, 0.16, 0.85)
			stock_btn.add_theme_stylebox_override("hover", sh)
			var sp := sn.duplicate() as StyleBoxFlat
			sp.bg_color = Color(0.88, 0.82, 0.58, 0.9)
			stock_btn.add_theme_stylebox_override("pressed", sp)
			var sd := sn.duplicate() as StyleBoxFlat
			sd.bg_color = Color(0.82, 0.84, 0.80, 0.45)
			sd.border_color = Color(0.55, 0.58, 0.52, 0.35)
			stock_btn.add_theme_stylebox_override("disabled", sd)
			var sell_id: StringName = crop.id
			stock_btn.pressed.connect(func(): _open_sell_modal(sell_id))
			v.add_child(stock_btn)
			stock_ctrl = stock_btn
			chip.set_meta("sell_btn", stock_btn)
		else:
			var stock_l := Label.new()
			stock_l.name = "StockCount"
			stock_l.text = GameState.crop_unlock_hint(crop)
			stock_l.add_theme_font_size_override("font_size", 9)
			stock_l.modulate = Color(0.70, 0.55, 0.35)
			stock_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stock_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			stock_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stock_l.clip_text = true
			stock_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			stock_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.add_child(stock_l)
			stock_ctrl = stock_l

		chip.set_meta("crop_id", crop.id)
		chip.set_meta("stock_label", stock_ctrl)
		chip.set_meta("unlocked", unlocked)

		if unlocked and i < keys.size():
			var key_badge := PanelContainer.new()
			key_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			key_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			key_badge.offset_left = -14
			key_badge.offset_top = 1
			key_badge.offset_right = -1
			key_badge.offset_bottom = 14
			if key_style:
				var ks := key_style.duplicate() as StyleBoxFlat
				ks.set_content_margin_all(1)
				key_badge.add_theme_stylebox_override("panel", ks)
			var key_l := Label.new()
			key_l.text = keys[i]
			key_l.add_theme_font_size_override("font_size", 8)
			key_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			key_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			key_l.modulate = Color(0.92, 0.98, 0.55)
			key_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			key_badge.add_child(key_l)
			holder.add_child(key_badge)

		if not unlocked:
			chip.modulate = Color.WHITE
			if seed_style:
				var locked_st := seed_style.duplicate() as StyleBoxFlat
				locked_st.bg_color = Color(0.58, 0.60, 0.62, 0.92)
				locked_st.border_color = Color(0.40, 0.42, 0.44, 0.70)
				locked_st.content_margin_left = 5
				locked_st.content_margin_right = 5
				locked_st.content_margin_top = 4
				locked_st.content_margin_bottom = 10
				chip.add_theme_stylebox_override("panel", locked_st)
			chip.tooltip_text = "Debloque au %s" % GameState.crop_unlock_hint(crop)
		else:
			var idx := i
			chip.tooltip_text = "%s - %.0fs" % [crop.display_name, crop.base_grow_time]
			chip.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					_on_seed_picked(idx)
			)
		seed_row.add_child(chip)
		_seed_buttons.append(chip)

	call_deferred("_layout_seed_chips")
	if not GameState.is_tutorial_done():
		var need_id := GameState.tutorial_next_crop_id()
		if need_id != &"":
			for si in GameState.crops.size():
				if GameState.crops[si].id == need_id:
					_on_seed_picked(si)
					_rebuild_stock()
					return
	_on_seed_picked(GameState.selected_crop_index)
	_rebuild_stock()


func _select_tutorial_seed_if_needed() -> void:
	if GameState.is_tutorial_done():
		return
	var need_id := GameState.tutorial_next_crop_id()
	if need_id == &"":
		return
	for i in GameState.crops.size():
		if GameState.crops[i].id == need_id:
			if GameState.selected_crop_index != i:
				_on_seed_picked(i)
			return


func _layout_seed_chips() -> void:
	## R?partit exactement les 6 cards sur toute la largeur, gaps ?gaux, sans scroll H.
	var scroll := get_node_or_null("%SeedScroll") as ScrollContainer
	if scroll == null or seed_row == null:
		return
	var n := maxi(1, _seed_buttons.size())
	var gap := 8
	var avail := scroll.size.x
	if avail < 32.0:
		return
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	seed_row.custom_minimum_size.x = avail
	seed_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	seed_row.add_theme_constant_override("separation", gap)
	# Largeur exacte pour remplir le bandeau (reste de pixels sur les premi?res cards)
	var usable := avail - float(gap) * float(n - 1)
	var base_w := floorf(usable / float(n))
	var rem := int(usable - base_w * float(n))
	for i in _seed_buttons.size():
		var chip: Control = _seed_buttons[i]
		if not is_instance_valid(chip):
			continue
		var w := base_w + (1.0 if i < rem else 0.0)
		chip.custom_minimum_size = Vector2(w, 94)
		chip.size = Vector2(w, 94)
		chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		chip.size_flags_stretch_ratio = 1.0


func _on_seed_picked(i: int) -> void:
	if i < 0 or i >= GameState.crops.size():
		return
	if not GameState.is_crop_unlocked(GameState.crops[i]):
		_show_toast("Debloque au %s" % GameState.crop_unlock_hint(GameState.crops[i]))
		return
	if not GameState.is_tutorial_done():
		var need_id := GameState.tutorial_next_crop_id()
		if need_id != &"" and GameState.crops[i].id != need_id:
			_show_toast("Tuto - choisis %s" % GameState.crop_display_name(need_id))
			return
	GameState.selected_crop_index = i
	var seed_style := _theme.get_stylebox("panel", "SeedCard") as StyleBoxFlat if _theme else _card_style
	for j in _seed_buttons.size():
		var chip: Control = _seed_buttons[j]
		var unlocked: bool = bool(chip.get_meta("unlocked", true))
		if not unlocked:
			continue
		var selected := j == i
		if selected:
			chip.modulate = Color(1.06, 1.08, 1.04)
		else:
			chip.modulate = Color(0.55, 0.55, 0.58, 0.72)
		if seed_style:
			var st := seed_style.duplicate() as StyleBoxFlat
			st.content_margin_left = 5
			st.content_margin_right = 5
			st.content_margin_top = 4
			st.content_margin_bottom = 10
			if selected:
				st.border_color = Color(0.82, 0.68, 0.28, 0.95)
				st.set_border_width_all(2)
				st.shadow_size = 5
			else:
				st.bg_color = Color(0.72, 0.74, 0.72, 0.88)
				st.border_color = Color(0.50, 0.52, 0.50, 0.55)
			chip.add_theme_stylebox_override("panel", st)
	if not GameState.is_tutorial_done():
		GameState._emit_tutorial_guidance()


func _styled_card() -> PanelContainer:
	var panel := PanelContainer.new()
	if _card_style:
		panel.add_theme_stylebox_override("panel", _card_style)
	return panel


func _styled_order_card() -> PanelContainer:
	var panel := PanelContainer.new()
	## Hauteur commune waiting / commer?ant pour ?viter le saut de layout.
	panel.custom_minimum_size = Vector2(0, 114)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _card_style:
		var st := _card_style.duplicate() as StyleBoxFlat
		if st:
			st.content_margin_left = 8
			st.content_margin_right = 8
			st.content_margin_top = 6
			st.content_margin_bottom = 1
			panel.add_theme_stylebox_override("panel", st)
		else:
			panel.add_theme_stylebox_override("panel", _card_style)
	return panel


func _apply_order_trait_style(panel: PanelContainer, m: MissionData) -> void:
	var col := m.trait_color()
	if m.client_trait == MissionData.TRAIT_IMPATIENT:
		if _theme:
			var rush_style := _theme.get_stylebox("panel", "RushCard")
			if rush_style:
				var st := rush_style.duplicate() as StyleBoxFlat
				if st:
					st.content_margin_left = 8
					st.content_margin_right = 8
					st.content_margin_top = 6
					st.content_margin_bottom = 1
					st.border_color = col
					st.set_border_width_all(2)
					panel.add_theme_stylebox_override("panel", st)
		return
	# ?picurien / Gourmand : fond + contours teint?s du trait
	var base := _card_style.duplicate() as StyleBoxFlat if _card_style else StyleBoxFlat.new()
	base.content_margin_left = 8
	base.content_margin_right = 8
	base.content_margin_top = 6
	base.content_margin_bottom = 1
	base.bg_color = Color(
		lerpf(0.90, col.r, 0.28),
		lerpf(0.92, col.g, 0.28),
		lerpf(0.88, col.b, 0.28),
		0.96
	)
	base.border_color = col
	base.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", base)


func _card(title: String, subtitle: String, cost_text: String, enabled: bool, on_press: Callable, icon_key: String = "", show_coin: bool = true) -> PanelContainer:
	## Carte boutique / comp?tences ? HBox stable (pas de Control ancr? qui collapse).
	var panel := _styled_card()
	if _card_style:
		var compact := _card_style.duplicate() as StyleBoxFlat
		compact.set_content_margin_all(8)
		panel.add_theme_stylebox_override("panel", compact)

	panel.custom_minimum_size = Vector2(0, 48)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(root)

	if icon_key != "" and _textures.has(icon_key):
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(24, 24)
		icon.texture = _textures[icon_key]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(icon)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(v)

	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 13)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	if subtitle != "":
		var s := Label.new()
		s.text = subtitle
		s.add_theme_font_size_override("font_size", 11)
		s.modulate = Color(0.42, 0.52, 0.44)
		s.autowrap_mode = TextServer.AUTOWRAP_OFF
		s.clip_text = true
		s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(s)

	var cost_box := HBoxContainer.new()
	cost_box.alignment = BoxContainer.ALIGNMENT_END
	cost_box.add_theme_constant_override("separation", 4)
	cost_box.size_flags_horizontal = Control.SIZE_SHRINK_END
	cost_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cost_box)

	if show_coin and _textures.has("ui_coin"):
		var coin := TextureRect.new()
		coin.custom_minimum_size = Vector2(16, 16)
		coin.texture = _textures["ui_coin"]
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_box.add_child(coin)

	var cost_l := Label.new()
	if show_coin and cost_text.is_valid_int():
		cost_l.text = "%s or" % cost_text
	else:
		cost_l.text = cost_text
	cost_l.add_theme_font_size_override("font_size", 13)
	cost_l.modulate = Color(0.62, 0.48, 0.12) if enabled else Color(0.55, 0.58, 0.55)
	cost_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	cost_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_box.add_child(cost_l)

	if enabled:
		panel.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				on_press.call()
				panel.accept_event()
		)
	else:
		panel.modulate = Color(0.82, 0.84, 0.82, 0.9)

	return panel


func _rebuild_missions() -> void:
	_tut_deliver_btn = null
	for c in mission_list.get_children():
		c.queue_free()
	## Pendant le tuto : uniquement la commande Tuteur (pas de file d'attente).
	if not GameState.is_tutorial_done():
		GameState.order_refresh_slots.clear()
		for m in GameState.missions:
			if GameState.is_tutorial_order(m):
				mission_list.add_child(_make_order_card(m))
		_update_next_hint()
		call_deferred("_clamp_side_panels")
		return
	for m in GameState.missions:
		mission_list.add_child(_make_order_card(m))
	for i in GameState.order_refresh_slots.size():
		var slot: Dictionary = GameState.order_refresh_slots[i]
		mission_list.add_child(_make_refresh_wait_card(slot, i))
	_update_next_hint()
	call_deferred("_clamp_side_panels")


func _refresh_mission_timers() -> void:
	## Met ? jour uniquement les chronos ? ne recr?e pas les boutons (?vite double-clic).
	for node in mission_list.get_children():
		_refresh_timer_labels_recursive(node)
	if _current_tab == "missions" and side_content:
		GameState.ensure_board_quests(false)
		MissionsPanelScript.refresh_reset_timers(side_content)


func _format_order_time(seconds: float) -> String:
	var s := maxi(0, int(ceil(seconds)))
	return "%d:%02d" % [s / 60, s % 60]


func _refresh_timer_labels_recursive(node: Node) -> void:
	if node is Label:
		var lab := node as Label
		if lab.has_meta("timer_order_id"):
			var oid: String = lab.get_meta("timer_order_id")
			for m in GameState.missions:
				if m.id == oid:
					lab.text = _format_order_time(m.time_left)
					var urgent := m.time_left <= 15.0
					lab.modulate = m.trait_color() if not urgent else Color(0.92, 0.28, 0.24)
					break
		elif lab.has_meta("timer_refresh_idx"):
			var idx: int = int(lab.get_meta("timer_refresh_idx"))
			if idx >= 0 and idx < GameState.order_refresh_slots.size():
				var slot: Dictionary = GameState.order_refresh_slots[idx]
				var secs := maxi(0, int(ceil(float(slot.get("time", 0.0)))))
				lab.text = "%d s" % secs
	for child in node.get_children():
		_refresh_timer_labels_recursive(child)


func _refresh_wait_title(reason: String) -> String:
	if reason == "failed":
		return "Commande ratee, un client repassera..."
	return "Commande refusee, un client repassera..."


func _make_refresh_wait_card(slot: Dictionary, refresh_idx: int = 0) -> PanelContainer:
	var panel := _styled_order_card()
	panel.modulate = Color(0.88, 0.90, 0.88, 0.9)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(root)

	## Spacer haut pour centrer verticalement comme une card commer?ant.
	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(spacer_top)

	var secs := maxi(0, int(ceil(float(slot.get("time", 0.0)))))
	var reason := str(slot.get("reason", "refused"))
	var accent := Color(0.72, 0.42, 0.32) if reason == "failed" else Color(0.55, 0.58, 0.45)

	var title_l := Label.new()
	title_l.text = _refresh_wait_title(reason)
	title_l.add_theme_font_size_override("font_size", 12)
	title_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_l.modulate = accent
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(title_l)

	var time_row := HBoxContainer.new()
	time_row.alignment = BoxContainer.ALIGNMENT_CENTER
	time_row.add_theme_constant_override("separation", 4)
	time_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(time_row)

	if _textures.has("ui_chrono"):
		var tic := TextureRect.new()
		tic.custom_minimum_size = Vector2(18, 18)
		tic.texture = _textures["ui_chrono"]
		tic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		time_row.add_child(tic)

	var timer_l := Label.new()
	timer_l.text = "%d s" % secs
	timer_l.add_theme_font_size_override("font_size", 14)
	timer_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_l.modulate = accent
	timer_l.set_meta("timer_refresh_idx", refresh_idx)
	time_row.add_child(timer_l)

	var spacer_bot := Control.new()
	spacer_bot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(spacer_bot)
	return panel


func _make_order_card(m: MissionData) -> PanelContainer:
	var panel := _styled_order_card()
	var can_deliver := m.is_fulfillable(GameState.stock)
	var trait_col := m.trait_color()
	_apply_order_trait_style(panel, m)
	if can_deliver:
		panel.modulate = Color(1.04, 1.10, 1.0)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 2)
	panel.add_child(root)

	# ?? Ligne 1 : avatar + m?tier/trait + r?compenses (or / xp) ??
	const FACE_SIZE := 36.0
	const HEAD_SEP := 6.0
	var body_indent := 0.0

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(HEAD_SEP))
	root.add_child(head)

	var face_key := "client_%d" % m.client_face
	var face_tex: Texture2D = _textures.get(face_key, _textures.get("ui_mission", null))
	if face_tex:
		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(FACE_SIZE, FACE_SIZE)
		ic.texture = face_tex
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(ic)

	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_col.add_theme_constant_override("separation", 0)
	head.add_child(name_col)

	var title := Label.new()
	title.text = "Tuteur (tuto)" if GameState.is_tutorial_order(m) else m.client_name
	title.add_theme_font_size_override("font_size", 13)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_col.add_child(title)

	var trait_l := Label.new()
	trait_l.text = m.trait_label()
	trait_l.add_theme_font_size_override("font_size", 10)
	trait_l.add_theme_color_override("font_color", trait_col)
	trait_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_col.add_child(trait_l)

	var reward_col := VBoxContainer.new()
	reward_col.add_theme_constant_override("separation", 1)
	reward_col.size_flags_horizontal = Control.SIZE_SHRINK_END
	reward_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reward_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(reward_col)

	var gold_row := HBoxContainer.new()
	gold_row.add_theme_constant_override("separation", 3)
	gold_row.alignment = BoxContainer.ALIGNMENT_END
	gold_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_col.add_child(gold_row)
	var money_l := Label.new()
	money_l.text = "+%d or" % maxi(1, int(m.coin_reward * GameState.mission_money_mult()))
	money_l.add_theme_font_size_override("font_size", 12)
	money_l.modulate = Color(0.55, 0.45, 0.14)
	money_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	money_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_row.add_child(money_l)
	if _textures.has("ui_coin"):
		var coin := TextureRect.new()
		coin.custom_minimum_size = Vector2(22, 22)
		coin.texture = _textures["ui_coin"]
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gold_row.add_child(coin)

	var xp_row := HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 3)
	xp_row.alignment = BoxContainer.ALIGNMENT_END
	xp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_col.add_child(xp_row)
	var xp_l := Label.new()
	xp_l.text = "+%dxp" % m.xp_reward
	xp_l.add_theme_font_size_override("font_size", 12)
	xp_l.modulate = Color(0.28, 0.52, 0.58)
	xp_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	xp_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_row.add_child(xp_l)
	if _textures.has("ui_xp"):
		var xp_ic := TextureRect.new()
		xp_ic.custom_minimum_size = Vector2(22, 22)
		xp_ic.texture = _textures["ui_xp"]
		xp_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		xp_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		xp_ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		xp_ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		xp_row.add_child(xp_ic)

	# ?? Ligne 2 : besoins (chips), align?s au bord gauche du portrait ??
	var needs_row := HBoxContainer.new()
	needs_row.add_theme_constant_override("separation", 0)
	needs_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(needs_row)
	if body_indent > 0.0:
		var needs_pad := Control.new()
		needs_pad.custom_minimum_size = Vector2(body_indent, 0)
		needs_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		needs_row.add_child(needs_pad)

	var needs := HBoxContainer.new()
	needs.add_theme_constant_override("separation", 6)
	needs.alignment = BoxContainer.ALIGNMENT_BEGIN
	needs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	needs_row.add_child(needs)

	for crop_id in m.requirements:
		var need: int = int(m.requirements[crop_id])
		var have: int = GameState.get_stock(crop_id)
		var ready := have >= need
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _chip_style:
			var st := _chip_style.duplicate() as StyleBoxFlat
			if st:
				st.content_margin_left = 4
				st.content_margin_right = 6
				st.content_margin_top = 2
				st.content_margin_bottom = 2
				st.bg_color = Color(0.78, 0.90, 0.80, 0.95) if ready else Color(0.90, 0.88, 0.78, 0.95)
				chip.add_theme_stylebox_override("panel", st)
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 3)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(cell)
		var ikey := "icon_%s" % String(crop_id)
		if _textures.has(ikey):
			var cic := TextureRect.new()
			cic.custom_minimum_size = Vector2(16, 16)
			cic.texture = _textures[ikey]
			cic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			cic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			cic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			cic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(cic)
		var qty := Label.new()
		qty.text = "%d/%d" % [mini(have, need), need]
		qty.add_theme_font_size_override("font_size", 12)
		qty.modulate = Color(0.18, 0.55, 0.32) if ready else Color(0.55, 0.42, 0.14)
		qty.autowrap_mode = TextServer.AUTOWRAP_OFF
		qty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(qty)
		needs.add_child(chip)

	## Espace l?ger entre les ressources et la ligne timer / boutons.
	var mid_gap := Control.new()
	mid_gap.custom_minimum_size = Vector2(0, 3)
	mid_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(mid_gap)

	# ?? Ligne 3 : chrono (m?me indent) | actions ??
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 4)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(foot)

	if body_indent > 0.0:
		var foot_pad := Control.new()
		foot_pad.custom_minimum_size = Vector2(body_indent, 0)
		foot_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		foot.add_child(foot_pad)

	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 3)
	time_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	time_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(time_row)
	if _textures.has("ui_chrono"):
		var tic := TextureRect.new()
		tic.custom_minimum_size = Vector2(18, 18)
		tic.texture = _textures["ui_chrono"]
		tic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		time_row.add_child(tic)
	var timer_l := Label.new()
	timer_l.text = _format_order_time(m.time_left)
	timer_l.add_theme_font_size_override("font_size", 13)
	timer_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	timer_l.modulate = trait_col if m.time_left > 15.0 else Color(0.92, 0.28, 0.24)
	timer_l.set_meta("timer_order_id", m.id)
	timer_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_row.add_child(timer_l)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 3)
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(actions)

	var oid := m.id
	var is_tut := GameState.is_tutorial_order(m)
	var cancel_btn := _make_action_button(false, not is_tut)
	cancel_btn.custom_minimum_size = Vector2(26, 26)
	cancel_btn.tooltip_text = "Commande tutoriel" if is_tut else "Refuser (30s)"
	cancel_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	if not is_tut:
		cancel_btn.pressed.connect(func(): GameState.cancel_order(oid))
	actions.add_child(cancel_btn)

	var check_btn := _make_action_button(true, can_deliver)
	check_btn.custom_minimum_size = Vector2(26, 26)
	check_btn.tooltip_text = "Livrer"
	check_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	check_btn.set_meta("tut_deliver_btn", true)
	check_btn.pressed.connect(func(): GameState.try_deliver_order(oid))
	actions.add_child(check_btn)
	if GameState.is_tutorial_order(m):
		_tut_deliver_btn = check_btn

	return panel


func _make_action_button(is_check: bool, enabled: bool) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(26, 26)
	btn.disabled = not enabled
	btn.expand_icon = true
	btn.add_theme_constant_override("icon_max_width", 16)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	var type_name := "BtnCheck" if is_check else "BtnCancel"
	if _theme:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var st := _theme.get_stylebox(state, type_name)
			if st:
				btn.add_theme_stylebox_override(state, st.duplicate())
	var tex_key := "ui_btn_check" if is_check else "ui_btn_cancel"
	if _textures.has(tex_key):
		btn.icon = _textures[tex_key]
		btn.text = ""
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		btn.text = "OK" if is_check else "X"
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", Color.WHITE)
	if not enabled:
		btn.modulate = Color(0.78, 0.78, 0.78, 0.75)
	return btn


func _rebuild_stock() -> void:
	var can_sell := GameState.can_sell_now()
	for chip in _seed_buttons:
		if not chip.has_meta("stock_label") or not chip.has_meta("crop_id"):
			continue
		if not bool(chip.get_meta("unlocked", true)):
			continue
		var stock_ctrl: Control = chip.get_meta("stock_label")
		var cid: StringName = chip.get_meta("crop_id")
		var amt := GameState.get_stock(cid)
		var txt := "Stock : x%d" % amt
		if stock_ctrl is Button:
			var sb := stock_ctrl as Button
			sb.text = txt
			## Pendant l??tape vente tuto : seul le l?gume offert est cliquable.
			if GameState.is_tutorial_sell_step():
				sb.disabled = amt <= 0 or cid != GameState.TUTORIAL_SELL_CROP
			else:
				sb.disabled = (not can_sell) or amt <= 0
		elif stock_ctrl is Label:
			(stock_ctrl as Label).text = txt
			(stock_ctrl as Label).modulate = Color(0.55, 0.42, 0.10) if amt > 0 else Color(0.50, 0.55, 0.50)


func _open_sell_modal(crop_id: StringName) -> void:
	if not GameState.can_sell_now():
		_show_toast("Termine le tutoriel avant de vendre.")
		return
	if GameState.is_tutorial_sell_step() and crop_id != GameState.TUTORIAL_SELL_CROP:
		_show_toast("Tuto - Vends le poivron offert.")
		return
	if is_instance_valid(_active_sell_modal):
		_active_sell_modal.dismiss()
	var modal := SellModalScript.present(self, crop_id, _textures)
	_active_sell_modal = modal
	if GameState.is_tutorial_sell_step():
		## Passe imm?diatement le doigt sur ? Vendre ?.
		_on_tutorial_nudge(&"sell_confirm")
	modal.sold.connect(func(_cid: StringName, _amt: int, _gold: int):
		_rebuild_stock()
		if _current_tab == "missions":
			_rebuild_side()
	)
	modal.closed.connect(func():
		if _active_sell_modal == modal:
			_active_sell_modal = null
		_rebuild_stock()
		## Si le joueur ferme sans vendre pendant le tuto, reviens sur Stock.
		if GameState.is_tutorial_sell_step():
			_on_tutorial_nudge(&"sell")
	)


func _on_harvested(plot_index: int, crop_id: StringName, amount: int, via_gardener: bool = false) -> void:
	var tile: PlotTile = null
	for t in _plot_tiles:
		if t.index == plot_index:
			tile = t
			break
	if tile == null:
		return

	## Jardinier : feedback via bras + vol stock (evite spam popup/tweens).
	if via_gardener:
		return

	var popup := HBoxContainer.new()
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_theme_constant_override("separation", 2)
	popup.z_index = 80
	# Hors layout parent (sinon PanelContainer force x=0 a gauche de l'ecran)
	popup.top_level = true

	var ikey := "icon_%s" % String(crop_id)
	if _textures.has(ikey):
		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(18, 18)
		ic.texture = _textures[ikey]
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		popup.add_child(ic)
	var lab := Label.new()
	lab.text = "+%d" % amount
	lab.add_theme_font_size_override("font_size", 16)
	lab.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lab.add_theme_constant_override("outline_size", 4)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(lab)

	add_child(popup)

	# Ancre sur la plante (crop) ou le centre de la parcelle
	var rect: Rect2 = tile.get_global_rect()
	if tile.crop != null and tile.crop.visible and tile.crop.texture != null:
		rect = tile.crop.get_global_rect()
	var anchor := rect.position + Vector2(rect.size.x * 0.65, rect.size.y * 0.35)
	popup.global_position = anchor
	popup.modulate = Color(1, 1, 1, 1)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(popup, "global_position", anchor + Vector2(18, -16), 0.65).set_ease(Tween.EASE_OUT)
	tw.tween_property(popup, "modulate:a", 0.0, 0.65).set_delay(0.2)
	tw.chain().tween_callback(popup.queue_free)

	## Vol vers le stock : recolte manuelle seulement (le jardinier le fait en fin de bras).
	if not via_gardener:
		var fly_from := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.55)
		_spawn_crop_to_stock_fly(fly_from, crop_id)


func _rebuild_side() -> void:
	for c in side_content.get_children():
		c.queue_free()
	side_content.add_theme_constant_override("separation", 8)
	var tab := _tab_def(_current_tab)
	if tab.get("locked", false):
		_fill_coming_soon(tab)
		return
	match _current_tab:
		"boosts":
			_fill_boosts()
		"missions":
			_fill_missions_tab()
		"relics":
			_fill_relics()
		_:
			_fill_boosts()
	_update_edit_terrain_button()
	call_deferred("_clamp_side_panels")


func _fill_missions_tab() -> void:
	MissionsPanelScript.fill(side_content, _textures, func(qid: String):
		GameState.claim_board_quest(qid)
		_rebuild_side()
	)


func _rebuild_skill_modal() -> void:
	if skill_tree_vbox == null:
		return
	for c in skill_tree_vbox.get_children():
		c.queue_free()
	_fill_skills()


func _fill_coming_soon(tab: Dictionary) -> void:
	var panel := _styled_card()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)

	var icon_key: String = tab.get("icon", "")
	if icon_key != "" and _textures.has(icon_key):
		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(40, 40)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = _textures[icon_key]
		head.add_child(ic)

	var title := Label.new()
	title.text = "%s - a venir" % tab["title"]
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(title)

	var body := Label.new()
	body.text = str(tab.get("teaser", "Cette section arrive bientot."))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 13)
	body.modulate = Color(0.75, 0.88, 0.78, 1)
	box.add_child(body)

	var badge := Label.new()
	badge.text = "Placeholder - pas encore jouable"
	badge.add_theme_font_size_override("font_size", 11)
	badge.modulate = Color(0.55, 0.68, 0.58, 1)
	box.add_child(badge)

	side_content.add_child(panel)


func _fill_boosts() -> void:
	side_content.add_child(_shop_section_title("Culture", Color(0.42, 0.58, 0.28)))
	var sp := GameState.speed_level
	var sp_max := GameState.MAX_SPEED_LEVEL
	var sp_now := GameState.speed_pct()
	var sp_gain := int(GameState.SPEED_PER_LEVEL * 100.0)
	var sp_maxed := sp >= sp_max
	var sp_sub := "MAX (actuel %d%%)" % sp_now if sp_maxed else "Gain +%d%% (actuel %d%%)" % [sp_gain, sp_now]
	side_content.add_child(_shop_row(
		"Temps de pousse",
		sp_sub,
		sp, sp_max,
		"MAX" if sp_maxed else str(GameState.get_boost_cost("speed")),
		(not sp_maxed) and GameState.money >= GameState.get_boost_cost("speed"),
		func(): GameState.buy_boost("speed"); _rebuild_side(),
		"ui_shop_speed",
		not sp_maxed,
		"speed"
	))

	var cl := GameState.click_level
	var cl_max := GameState.MAX_CLICK_LEVEL
	var power_now := GameState.click_power()
	var power_next := GameState.CLICK_POWER_BASE + float(cl + 1) * GameState.CLICK_POWER_PER_LEVEL
	var gt := GameState.get_relic_level("green_thumb")
	if gt > 0:
		power_next *= 1.0 + 0.10 * float(gt)
	var cl_maxed := cl >= cl_max
	var cl_sub := ("MAX (actuel ?%.1fs)" % power_now) if cl_maxed else ("Clic ?%.1fs (actuel ?%.1fs)" % [power_next, power_now])
	side_content.add_child(_shop_row(
		"Puissance de clic",
		cl_sub,
		cl, cl_max,
		"MAX" if cl_maxed else str(GameState.get_boost_cost("click")),
		(not cl_maxed) and GameState.money >= GameState.get_boost_cost("click"),
		func(): GameState.buy_boost("click"); _rebuild_side(),
		"ui_shop_click",
		not cl_maxed,
		"click"
	))

	var yl := GameState.yield_level
	var yl_max := GameState.MAX_YIELD_LEVEL
	var y_now := GameState.yield_pct()
	var y_gain := int(GameState.DOUBLE_DROP_PER_LEVEL * 100.0)
	var yl_maxed := yl >= yl_max
	var yl_sub := "MAX (actuel %d%%)" % y_now if yl_maxed else "Chance +%d%% (actuel %d%%)" % [y_gain, y_now]
	side_content.add_child(_shop_row(
		"Chance double drop",
		yl_sub,
		yl, yl_max,
		"MAX" if yl_maxed else str(GameState.get_boost_cost("yield")),
		(not yl_maxed) and GameState.money >= GameState.get_boost_cost("yield"),
		func(): GameState.buy_boost("yield"); _rebuild_side(),
		"ui_shop_frenzy",
		not yl_maxed,
		"yield"
	))

	var plots_now := GameState.unlocked_plots
	var pl_maxed := plots_now >= GameState.MAX_PLOTS
	var pl_sub := "MAX (%d)" % plots_now if pl_maxed else "+1 parcelle auto (actuel %d) - Editer pour reorganiser" % plots_now
	side_content.add_child(_shop_row(
		"Nouvelle parcelle",
		pl_sub,
		plots_now, GameState.MAX_PLOTS,
		"MAX" if pl_maxed else str(GameState.get_boost_cost("plot")),
		(not pl_maxed) and GameState.money >= GameState.get_boost_cost("plot"),
		func(): GameState.buy_boost("plot"); _rebuild_side(); _update_edit_terrain_button(); call_deferred("_center_field"),
		"ui_shop_plot",
		not pl_maxed,
		"plot"
	))

	side_content.add_child(_shop_section_title("Automatisation", Color(0.38, 0.48, 0.62)))
	_add_machine_shop_row(
		"Fertiliseur",
		"Salve d'etoiles / 2 s : -0,5 s de pousse (8 cases autour) - pose via Editer.",
		GameState.MACHINE_FERTILIZER,
		1,
		"ui_fertilizer",
		GameState.fertilizer_owned,
		GameState.FERTILIZER_MAX
	)
	_add_machine_shop_row(
		"Jardinier",
		"Recolte + replante / 2 s (1 bras, 8 cases autour) - pose via Editer.",
		GameState.MACHINE_GARDENER,
		3,
		"ui_gardener",
		GameState.gardener_owned,
		GameState.GARDENER_MAX
	)
	_add_machine_shop_row(
		"Livreur auto",
		"Livre toutes les commandes des que le stock suffit.",
		"delivery",
		5,
		"ui_auto_delivery",
		GameState.delivery_owned,
		GameState.DELIVERY_MAX
	)


func _add_machine_shop_row(
	title: String,
	desc: String,
	machine_id: String,
	prestige_req: int,
	icon_key: String,
	owned: int,
	max_owned: int
) -> void:
	var unlocked := GameState.prestige_level >= prestige_req
	if not unlocked:
		side_content.add_child(_shop_row(
			title,
			"Debloque au Prestige %d" % prestige_req,
			0, 1,
			"",
			false,
			func(): pass,
			icon_key,
			false,
			"",
			true
		))
		return
	var maxed := owned >= max_owned
	var cost := GameState.get_machine_cost(machine_id)
	var sub := "MAX (%d)" % owned if maxed else "%s - possedes %d/%d" % [desc, owned, max_owned]
	side_content.add_child(_shop_row(
		title,
		sub,
		owned, max_owned,
		"MAX" if maxed else str(cost),
		(not maxed) and GameState.money >= cost and GameState.can_buy_machine(machine_id),
		func(): GameState.buy_machine(machine_id); _rebuild_side(); _update_edit_terrain_button(),
		icon_key,
		not maxed,
		""
	))


func _add_automation_shop_row(title: String, desc: String, prestige_req: int, icon_key: String) -> void:
	## Legacy teaser helper (conserv? si appel? ailleurs).
	var unlocked := GameState.prestige_level >= prestige_req
	var subtitle := "Debloque au Prestige %d" % prestige_req
	if unlocked:
		subtitle = "%s - Bientot" % desc
	side_content.add_child(_shop_row(
		title,
		subtitle,
		0, 1,
		"",
		false,
		func(): pass,
		icon_key,
		false,
		"",
		true
	))


func _shop_section_title(text: String, accent: Color) -> Control:
	var wrap := HBoxContainer.new()
	wrap.add_theme_constant_override("separation", 8)
	var bar := ColorRect.new()
	bar.custom_minimum_size = Vector2(4, 16)
	bar.color = accent
	wrap.add_child(bar)
	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", 12)
	lab.add_theme_color_override("font_color", accent.darkened(0.15))
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_child(lab)
	return wrap


func _shop_row(
	title: String,
	subtitle: String,
	level: int,
	level_max: int,
	cost_text: String,
	enabled: bool,
	on_press: Callable,
	icon_key: String = "",
	show_coin: bool = true,
	boost_id: String = "",
	show_lock: bool = false
) -> PanelContainer:
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	if enabled:
		st.bg_color = Color(0.90, 0.95, 0.86, 0.98)
		st.border_color = Color(0.62, 0.52, 0.18, 0.85)
	elif not show_coin:
		st.bg_color = Color(0.78, 0.82, 0.78, 0.85)
		st.border_color = Color(0.50, 0.55, 0.50, 0.45)
	else:
		st.bg_color = Color(0.84, 0.88, 0.84, 0.92)
		st.border_color = Color(0.48, 0.56, 0.48, 0.50)
	st.set_border_width_all(1)
	st.set_corner_radius_all(10)
	st.content_margin_left = 8
	st.content_margin_right = 6
	st.content_margin_top = 7
	st.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", st)
	panel.custom_minimum_size = Vector2(0, 58)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(root)

	if icon_key != "" and _textures.has(icon_key):
		## Culture + Automatisation : ic?nes illustr?es ~38px.
		var icon_sz := 38.0
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(icon_sz, icon_sz)
		icon.texture = _textures[icon_key]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(icon)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 2)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(mid)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 4)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(title_row)

	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 12)
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(t)

	if boost_id != "":
		var info := Button.new()
		info.focus_mode = Control.FOCUS_NONE
		info.text = "i"
		info.tooltip_text = "Details des niveaux"
		info.custom_minimum_size = Vector2(18, 18)
		info.add_theme_font_size_override("font_size", 10)
		var in_st := StyleBoxFlat.new()
		in_st.bg_color = Color(0.42, 0.58, 0.72, 0.95)
		in_st.border_color = Color(0.28, 0.42, 0.55, 0.9)
		in_st.set_border_width_all(1)
		in_st.set_corner_radius_all(9)
		in_st.content_margin_left = 2
		in_st.content_margin_right = 2
		in_st.content_margin_top = 0
		in_st.content_margin_bottom = 0
		var in_h := in_st.duplicate() as StyleBoxFlat
		in_h.bg_color = Color(0.50, 0.66, 0.82, 1.0)
		info.add_theme_stylebox_override("normal", in_st)
		info.add_theme_stylebox_override("hover", in_h)
		info.add_theme_stylebox_override("pressed", in_st)
		info.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
		info.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		var bid := boost_id
		info.pressed.connect(func(): _open_boost_info(bid))
		title_row.add_child(info)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 8)
	bar.max_value = maxf(1.0, float(level_max))
	bar.value = float(level)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.62, 0.68, 0.60, 0.55)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.48, 0.70, 0.36, 1.0) if show_coin else Color(0.55, 0.58, 0.55, 1.0)
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	mid.add_child(bar)

	var meta := Label.new()
	## Ex. ? 0/50 ? Gain +4% (actuel 0%) ?
	if show_lock or (level_max <= 1 and level == 0 and not show_coin):
		meta.text = subtitle
	else:
		meta.text = "%d/%d - %s" % [level, level_max, subtitle]
	meta.add_theme_font_size_override("font_size", 10)
	meta.add_theme_color_override("font_color", Color(0.40, 0.48, 0.40))
	meta.clip_text = true
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(meta)

	# Bouton achat seul ? droite ? l?g?re marge chiffre / pi?ce
	var buy := PanelContainer.new()
	buy.custom_minimum_size = Vector2(58, 36)
	buy.mouse_filter = Control.MOUSE_FILTER_STOP
	buy.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	var bn := StyleBoxFlat.new()
	if show_lock:
		## Fond gris plat ? le cadenas blanc se lit dessus (pas de plaque autour de l?ic?ne).
		bn.bg_color = Color(0.58, 0.60, 0.58, 0.95)
		bn.border_color = Color(0.48, 0.50, 0.48, 0.55)
	elif enabled:
		bn.bg_color = Color(0.78, 0.58, 0.16, 1.0)
		bn.border_color = Color(0.58, 0.40, 0.10, 1.0)
	else:
		bn.bg_color = Color(0.62, 0.64, 0.60, 0.9)
		bn.border_color = Color(0.50, 0.52, 0.48, 0.6)
	bn.set_border_width_all(1)
	bn.set_corner_radius_all(7)
	bn.content_margin_left = 6
	bn.content_margin_right = 5
	bn.content_margin_top = 5
	bn.content_margin_bottom = 5
	buy.add_theme_stylebox_override("panel", bn)
	var buy_row := HBoxContainer.new()
	buy_row.add_theme_constant_override("separation", 4)
	buy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buy_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buy.add_child(buy_row)
	if show_lock:
		if _textures.has("ui_lock"):
			var lock_ic := TextureRect.new()
			lock_ic.custom_minimum_size = Vector2(26, 26)
			lock_ic.texture = _textures["ui_lock"]
			lock_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			lock_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			lock_ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			## Blanc direct sur le fond gris du bouton (PNG transparent).
			lock_ic.modulate = Color(1, 1, 1, 1)
			lock_ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			buy_row.add_child(lock_ic)
		else:
			var lock_l := Label.new()
			lock_l.text = "X"
			lock_l.add_theme_font_size_override("font_size", 14)
			lock_l.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			lock_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			buy_row.add_child(lock_l)
	else:
		var cost_l := Label.new()
		cost_l.text = cost_text
		cost_l.add_theme_font_size_override("font_size", 15)
		cost_l.add_theme_color_override("font_color", Color(1, 0.98, 0.92) if enabled else Color(0.45, 0.48, 0.45))
		cost_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		buy_row.add_child(cost_l)
		if show_coin and cost_text.is_valid_int() and _textures.has("ui_coin"):
			var coin := TextureRect.new()
			coin.custom_minimum_size = Vector2(20, 20)
			coin.texture = _textures["ui_coin"]
			coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			coin.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
			buy_row.add_child(coin)
	if enabled:
		buy.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				on_press.call()
		)
		buy.mouse_entered.connect(func():
			var hs := bn.duplicate() as StyleBoxFlat
			hs.bg_color = Color(0.88, 0.68, 0.22, 1.0)
			buy.add_theme_stylebox_override("panel", hs)
		)
		buy.mouse_exited.connect(func():
			buy.add_theme_stylebox_override("panel", bn)
		)
	root.add_child(buy)

	return panel


func _boost_info_meta(boost_id: String) -> Dictionary:
	match boost_id:
		"speed":
			return {
				"title": "Temps de pousse...",
				"col": "Bonus vitesse",
				"max": GameState.MAX_SPEED_LEVEL,
				"current": GameState.speed_level,
			}
		"click":
			return {
				"title": "Puissance de clic",
				"col": "Puissance (?s)",
				"max": GameState.MAX_CLICK_LEVEL,
				"current": GameState.click_level,
			}
		"yield":
			return {
				"title": "Chance double drop",
				"col": "Chance",
				"max": GameState.MAX_YIELD_LEVEL,
				"current": GameState.yield_level,
			}
		"plot":
			return {
				"title": "Parcelles",
				"col": "Parcelles",
				"max": GameState.MAX_PLOTS,
				"current": GameState.unlocked_plots,
			}
		_:
			return {"title": boost_id, "col": "Valeur", "max": 1, "current": 0}


func _boost_value_at(boost_id: String, level: int) -> String:
	match boost_id:
		"speed":
			return "+%d%%" % int(float(level) * GameState.SPEED_PER_LEVEL * 100.0)
		"click":
			var power := GameState.CLICK_POWER_BASE + float(level) * GameState.CLICK_POWER_PER_LEVEL
			var gt := GameState.get_relic_level("green_thumb")
			if gt > 0:
				power *= 1.0 + 0.10 * float(gt)
			return "x%.1fs" % power
		"yield":
			var base_pct := int(float(level) * GameState.DOUBLE_DROP_PER_LEVEL * 100.0)
			base_pct += int(3 * GameState.get_relic_level("bountiful"))
			return "%d%%" % mini(100, base_pct)
		"plot":
			return "%d parcelle%s" % [level, "" if level < 2 else "s"]
		_:
			return "-"


func _open_boost_info(boost_id: String) -> void:
	var existing := get_node_or_null("BoostInfoOverlay") as Control
	if existing:
		existing.queue_free()

	var meta := _boost_info_meta(boost_id)
	var overlay := ColorRect.new()
	overlay.name = "BoostInfoOverlay"
	overlay.color = Color(0.05, 0.08, 0.06, 0.62)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 260
	overlay.top_level = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 420)
	panel.add_theme_stylebox_override("panel", _make_parchment_style())
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	vbox.add_child(head)
	var title := Label.new()
	title.text = str(meta.get("title", boost_id))
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.28, 0.16, 0.08))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_make_ui_close_button(func(): overlay.queue_free(), true))

	var hint := Label.new()
	hint.text = "Valeurs par niveau (actuel : %d)." % int(meta.get("current", 0))
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.42, 0.30, 0.16))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hint)

	# En-t?te colonnes
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 8)
	vbox.add_child(cols)
	for pair in [["Niv.", 54], [str(meta.get("col", "Valeur")), 0]]:
		var hl := Label.new()
		hl.text = pair[0]
		hl.add_theme_font_size_override("font_size", 11)
		hl.add_theme_color_override("font_color", Color(0.36, 0.24, 0.12))
		if int(pair[1]) > 0:
			hl.custom_minimum_size = Vector2(int(pair[1]), 0)
		else:
			hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(hl)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)

	var cur_lvl: int = int(meta.get("current", 0))
	var max_lvl: int = int(meta.get("max", 1))
	var start_lvl := GameState.START_PLOTS if boost_id == "plot" else 0
	for lvl in range(start_lvl, max_lvl + 1):
		var row := PanelContainer.new()
		var rst := StyleBoxFlat.new()
		var is_cur := lvl == cur_lvl
		rst.bg_color = Color(0.86, 0.94, 0.72, 0.95) if is_cur else Color(0.96, 0.92, 0.80, 0.75)
		rst.border_color = Color(0.55, 0.70, 0.30, 0.9) if is_cur else Color(0.70, 0.58, 0.36, 0.35)
		rst.set_border_width_all(1 if is_cur else 0)
		rst.set_corner_radius_all(6)
		rst.content_margin_left = 8
		rst.content_margin_right = 8
		rst.content_margin_top = 4
		rst.content_margin_bottom = 4
		row.add_theme_stylebox_override("panel", rst)
		var rr := HBoxContainer.new()
		rr.add_theme_constant_override("separation", 8)
		row.add_child(rr)
		var nl := Label.new()
		nl.text = str(lvl) + ("  *" if is_cur else "")
		nl.custom_minimum_size = Vector2(54, 0)
		nl.add_theme_font_size_override("font_size", 12)
		nl.add_theme_color_override("font_color", Color(0.22, 0.36, 0.14) if is_cur else Color(0.30, 0.18, 0.08))
		rr.add_child(nl)
		var vl := Label.new()
		vl.text = _boost_value_at(boost_id, lvl)
		vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vl.add_theme_font_size_override("font_size", 12)
		vl.add_theme_color_override("font_color", Color(0.22, 0.36, 0.14) if is_cur else Color(0.34, 0.24, 0.12))
		rr.add_child(vl)
		list.add_child(row)

	# Scroll vers le niveau actuel
	call_deferred("_scroll_boost_info_to_current", scroll, list, cur_lvl, start_lvl)

	overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if not panel.get_global_rect().has_point(ev.global_position):
				overlay.queue_free()
	)


func _scroll_boost_info_to_current(scroll: ScrollContainer, list: VBoxContainer, cur_lvl: int, start_lvl: int) -> void:
	if not is_instance_valid(scroll) or not is_instance_valid(list):
		return
	var idx := cur_lvl - start_lvl
	if idx < 0 or idx >= list.get_child_count():
		return
	var row := list.get_child(idx) as Control
	if row:
		scroll.ensure_control_visible(row)


func _fill_skills() -> void:
	## Arbre compact : tout visible, sans scroll.
	var host: VBoxContainer = skill_tree_vbox
	if host == null:
		return
	_skill_nodes.clear()
	_hide_skill_tip()
	if _skill_tip != null and is_instance_valid(_skill_tip):
		_skill_tip.queue_free()
		_skill_tip = null

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	host.add_child(header)
	var title := Label.new()
	title.text = "Arbre de competences"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.88, 0.94, 0.86))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_make_ui_close_button(_close_skill_tree, false))

	var stage := PanelContainer.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stage_st := StyleBoxFlat.new()
	stage_st.bg_color = Color(0.06, 0.09, 0.08, 0.92)
	stage_st.border_color = Color(0.22, 0.32, 0.26, 0.7)
	stage_st.set_border_width_all(1)
	stage_st.set_corner_radius_all(12)
	stage_st.content_margin_left = 4
	stage_st.content_margin_right = 4
	stage_st.content_margin_top = 2
	stage_st.content_margin_bottom = 2
	stage.add_theme_stylebox_override("panel", stage_st)
	host.add_child(stage)

	var wrap := Control.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.clip_contents = true
	stage.add_child(wrap)

	var map := _build_skill_mindmap()
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(map)

	var pc_badge := _make_skill_pc_badge()
	pc_badge.position = Vector2(10, 10)
	wrap.add_child(pc_badge)


func _ensure_skill_tip() -> PanelContainer:
	if _skill_tip != null and is_instance_valid(_skill_tip):
		return _skill_tip
	var tip := PanelContainer.new()
	tip.name = "SkillTip"
	tip.visible = false
	tip.z_index = 80
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.11, 0.10, 0.96)
	st.border_color = Color(0.55, 0.72, 0.48, 0.85)
	st.set_border_width_all(1)
	st.set_corner_radius_all(8)
	st.content_margin_left = 9
	st.content_margin_right = 9
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	st.shadow_color = Color(0, 0, 0, 0.4)
	st.shadow_size = 6
	tip.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.name = "TipBox"
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tip.add_child(v)
	var title := Label.new()
	title.name = "TipTitle"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.94, 0.96, 0.90, 1))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	v.add_child(title)
	var body := Label.new()
	body.name = "TipBody"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(200, 0)
	body.add_theme_font_size_override("font_size", 11)
	body.add_theme_color_override("font_color", Color(0.78, 0.84, 0.78, 1))
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	v.add_child(body)
	if skill_tree_overlay:
		skill_tree_overlay.add_child(tip)
	_skill_tip = tip
	return tip


func _show_skill_tip(skill_id: String, anchor: Control) -> void:
	if not is_instance_valid(anchor):
		return
	var tip := _ensure_skill_tip()
	var def: Dictionary = GameState.get_skill_def(skill_id)
	if def.is_empty():
		_hide_skill_tip()
		return
	var owned := GameState.has_skill(skill_id)
	var branch_ok := GameState.is_skill_branch_unlocked(skill_id)
	var cost: int = int(def.get("cost", 1))
	var title := tip.get_node_or_null("TipBox/TipTitle") as Label
	var body := tip.get_node_or_null("TipBox/TipBody") as Label
	var branch := str(def.get("branch", "trunk"))
	var col := _skill_branch_color(branch)
	var name := str(def.get("title", skill_id))
	if title:
		if owned:
			title.text = "%s (acquise)" % name
		else:
			title.text = "%s (%d PC)" % [name, cost]
	if body:
		var detail := str(def.get("desc", ""))
		if not branch_ok:
			var reqs: Array = GameState.skill_prerequisites(skill_id)
			var names: PackedStringArray = []
			for p in reqs:
				names.append(str(GameState.get_skill_def(str(p)).get("title", p)))
			if not names.is_empty():
				detail += "\nPr?requis : %s" % " / ".join(names)
		body.text = detail
	var tip_st := tip.get_theme_stylebox("panel")
	if tip_st is StyleBoxFlat:
		var st2: StyleBoxFlat = (tip_st as StyleBoxFlat).duplicate()
		st2.border_color = Color(col.r, col.g, col.b, 0.9)
		tip.add_theme_stylebox_override("panel", st2)
	_skill_tip_skill_id = skill_id
	_skill_tip_anchor = anchor
	tip.visible = true
	_position_skill_tip(anchor)
	call_deferred("_fit_skill_tip")


func _fit_skill_tip() -> void:
	if _skill_tip == null or not is_instance_valid(_skill_tip) or not _skill_tip.visible:
		return
	_skill_tip.reset_size()
	var ms := _skill_tip.get_combined_minimum_size()
	_skill_tip.size = Vector2(maxi(180, int(ms.x)), int(ms.y))
	_clamp_skill_tip()


func _position_skill_tip(anchor: Control) -> void:
	if _skill_tip == null or not is_instance_valid(_skill_tip) or not is_instance_valid(anchor):
		return
	## Place le tip ? droite du n?ud, sans bloquer la souris.
	var tip_pos := anchor.get_global_rect().position + Vector2(anchor.size.x + 12, -4)
	if skill_tree_overlay:
		tip_pos -= skill_tree_overlay.global_position
	_skill_tip.position = tip_pos
	call_deferred("_clamp_skill_tip")


func _clamp_skill_tip() -> void:
	if _skill_tip == null or not is_instance_valid(_skill_tip) or not _skill_tip.visible:
		return
	var max_x := (skill_tree_overlay.size.x if skill_tree_overlay else 1280.0) - _skill_tip.size.x - 10.0
	var max_y := (skill_tree_overlay.size.y if skill_tree_overlay else 720.0) - _skill_tip.size.y - 10.0
	## Si trop ? droite, bascule ? gauche du n?ud
	if _skill_tip_anchor != null and is_instance_valid(_skill_tip_anchor) and _skill_tip.position.x > max_x:
		var left := _skill_tip_anchor.get_global_rect().position
		if skill_tree_overlay:
			left -= skill_tree_overlay.global_position
		_skill_tip.position.x = left.x - _skill_tip.size.x - 12.0
	_skill_tip.position = Vector2(
		clampf(_skill_tip.position.x, 10.0, maxf(10.0, max_x)),
		clampf(_skill_tip.position.y, 10.0, maxf(10.0, max_y))
	)


func _hide_skill_tip(_force: bool = false) -> void:
	_skill_tip_skill_id = ""
	_skill_tip_anchor = null
	if _skill_tip and is_instance_valid(_skill_tip):
		_skill_tip.visible = false


func _build_skill_mindmap() -> Control:
	## Hub + triangles (1 entr?e ? 3 choix) sur chaque c?t?.
	var map := Control.new()
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.clip_contents = true

	var layout := {
		"root_hub": Vector2(0.50, 0.50),
		# Haut ? Combo
		"combo_flash": Vector2(0.50, 0.34),
		"combo_boost": Vector2(0.36, 0.14),
		"combo_cd": Vector2(0.50, 0.08),
		"combo_master": Vector2(0.64, 0.14),
		# Gauche ? Commandes
		"order_time": Vector2(0.34, 0.50),
		"order_slots": Vector2(0.14, 0.36),
		"order_flow": Vector2(0.08, 0.50),
		"order_refuse": Vector2(0.14, 0.64),
		# Droite ? XP
		"xp_mission": Vector2(0.66, 0.50),
		"xp_curve": Vector2(0.86, 0.36),
		"xp_mission_2": Vector2(0.92, 0.50),
		"xp_prestige_prep": Vector2(0.86, 0.64),
		# Bas ? Argent
		"money_mission": Vector2(0.50, 0.66),
		"money_shop": Vector2(0.36, 0.86),
		"money_start": Vector2(0.50, 0.92),
		"money_crit": Vector2(0.64, 0.86),
		# Bas-gauche ? Atelier
		"atelier_gears": Vector2(0.28, 0.72),
		"atelier_long_arms": Vector2(0.12, 0.78),
		"atelier_wide_tour": Vector2(0.18, 0.90),
		"atelier_live_chain": Vector2(0.30, 0.94),
		"atelier_network": Vector2(0.40, 0.84),
	}

	var centers: Dictionary = {}
	var nodes: Dictionary = {}
	var sizes: Dictionary = {}
	const NODE_SZ := Vector2(44, 44)
	const HUB_SZ := Vector2(56, 56)

	var link_host := Control.new()
	link_host.name = "Links"
	link_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	link_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.add_child(link_host)

	for skill_id in GameState.skill_ids():
		var def: Dictionary = GameState.get_skill_def(skill_id)
		var owned := GameState.has_skill(skill_id)
		var branch_ok := GameState.is_skill_branch_unlocked(skill_id)
		var cost: int = int(def.get("cost", 1))
		var can := (not owned) and branch_ok and GameState.skill_points >= cost
		var is_hub := bool(def.get("hub", false))
		var node_size := HUB_SZ if is_hub else NODE_SZ
		var node := _mindmap_node(skill_id, def, owned, branch_ok, can, cost, node_size)
		map.add_child(node)
		nodes[skill_id] = node
		sizes[skill_id] = node_size
		_skill_nodes.append(node)
		node.set_meta("skill_id", skill_id)
		node.set_meta("rel", layout.get(skill_id, Vector2(0.5, 0.5)))

	var place := func():
		var w := maxf(map.size.x, 320.0)
		var h := maxf(map.size.y, 320.0)
		for sid in nodes:
			var n: Control = nodes[sid]
			var rel: Vector2 = n.get_meta("rel")
			var ns: Vector2 = sizes[sid]
			var pos := Vector2(rel.x * w - ns.x * 0.5, rel.y * h - ns.y * 0.5)
			pos.x = clampf(pos.x, 4.0, w - ns.x - 4.0)
			pos.y = clampf(pos.y, 4.0, h - ns.y - 4.0)
			n.position = pos
			centers[sid] = pos + ns * 0.5

		for c in link_host.get_children():
			c.queue_free()
		for sid in GameState.skill_ids():
			var parents: Array = GameState.skill_prerequisites(sid)
			if parents.is_empty():
				continue
			for parent in parents:
				var pid := str(parent)
				if not centers.has(pid) or not centers.has(sid):
					continue
				var parent_owned := GameState.has_skill(pid)
				var child_owned := GameState.has_skill(sid)
				var branch := str(GameState.get_skill_def(sid).get("branch", "trunk"))
				var col := _skill_branch_color(branch)
				var pts := PackedVector2Array([centers[pid], centers[sid]])
				if parent_owned:
					var glow := Line2D.new()
					glow.width = 7.0
					glow.default_color = Color(col.r, col.g, col.b, 0.14 if child_owned else 0.08)
					glow.antialiased = true
					glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
					glow.end_cap_mode = Line2D.LINE_CAP_ROUND
					glow.points = pts
					link_host.add_child(glow)
					var line := Line2D.new()
					line.width = 2.6 if child_owned else 2.0
					line.default_color = Color(col.r, col.g, col.b, 0.95 if child_owned else 0.60)
					line.antialiased = true
					line.begin_cap_mode = Line2D.LINE_CAP_ROUND
					line.end_cap_mode = Line2D.LINE_CAP_ROUND
					line.points = pts
					link_host.add_child(line)
				else:
					var empty := Line2D.new()
					empty.width = 1.4
					empty.default_color = Color(0.40, 0.46, 0.42, 0.22)
					empty.antialiased = true
					empty.begin_cap_mode = Line2D.LINE_CAP_ROUND
					empty.end_cap_mode = Line2D.LINE_CAP_ROUND
					empty.points = pts
					link_host.add_child(empty)

	map.resized.connect(place)
	call_deferred("_mindmap_place_once", map, place)
	return map


func _skill_branch_color(branch: String) -> Color:
	match branch:
		"combo":
			return Color(0.95, 0.52, 0.22, 1.0)
		"xp":
			return Color(0.38, 0.64, 0.98, 1.0)
		"orders":
			return Color(0.28, 0.72, 0.66, 1.0)
		"money":
			return Color(0.88, 0.72, 0.22, 1.0)
		"atelier":
			return Color(0.62, 0.55, 0.72, 1.0)
		_:
			return Color(0.55, 0.78, 0.48, 1.0)


func _mindmap_place_once(map: Control, place: Callable) -> void:
	if is_instance_valid(map):
		place.call()


func _mindmap_node(
	skill_id: String,
	def: Dictionary,
	owned: bool,
	branch_ok: bool,
	can: bool,
	cost: int,
	node_size: Vector2 = Vector2(52, 52)
) -> Control:
	var branch := str(def.get("branch", "trunk"))
	var branch_col := _skill_branch_color(branch)
	var is_hub := bool(def.get("hub", false))
	var radius := int(mini(node_size.x, node_size.y) * 0.5)

	var root := Control.new()
	root.custom_minimum_size = node_size
	root.size = node_size
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if (can or branch_ok or owned) else Control.CURSOR_ARROW
	root.pivot_offset = node_size * 0.5

	var card := PanelContainer.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	if owned:
		st.bg_color = Color(branch_col.r * 0.32 + 0.08, branch_col.g * 0.32 + 0.10, branch_col.b * 0.32 + 0.08, 0.98)
		st.border_color = branch_col
		st.set_border_width_all(3 if is_hub else 2)
		st.shadow_color = Color(branch_col.r, branch_col.g, branch_col.b, 0.40)
		st.shadow_size = 6
	elif can:
		st.bg_color = Color(0.16, 0.20, 0.15, 0.98)
		st.border_color = Color(0.95, 0.82, 0.35, 1.0)
		st.set_border_width_all(2)
		st.shadow_color = Color(0.95, 0.78, 0.25, 0.40)
		st.shadow_size = 5
	elif branch_ok:
		st.bg_color = Color(0.13, 0.16, 0.14, 0.95)
		st.border_color = Color(branch_col.r, branch_col.g, branch_col.b, 0.50)
		st.set_border_width_all(2)
	else:
		st.bg_color = Color(0.10, 0.12, 0.11, 0.92)
		st.border_color = Color(0.32, 0.36, 0.34, 0.50)
		st.set_border_width_all(1)
	st.set_corner_radius_all(radius)
	card.add_theme_stylebox_override("panel", st)
	root.add_child(card)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(center)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 0)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(content)

	if not branch_ok and not owned:
		var lock := Label.new()
		lock.text = "?"
		lock.add_theme_font_size_override("font_size", 15)
		lock.add_theme_color_override("font_color", Color(0.45, 0.48, 0.46))
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(lock)
	else:
		var icon_key := str(def.get("icon", "ui_xp"))
		if _textures.has(icon_key):
			var ic := TextureRect.new()
			var isz := 26 if is_hub else 22
			ic.custom_minimum_size = Vector2(isz, isz)
			ic.texture = _textures[icon_key]
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			ic.modulate = Color.WHITE if owned else (Color(0.95, 0.95, 0.92) if branch_ok else Color(0.5, 0.5, 0.5))
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			content.add_child(ic)

	var badge := Label.new()
	badge.anchor_left = 0.5
	badge.anchor_right = 0.5
	badge.anchor_top = 1.0
	badge.anchor_bottom = 1.0
	badge.offset_left = -18
	badge.offset_right = 18
	badge.offset_top = 0
	badge.offset_bottom = 14
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 9)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if owned:
		badge.text = "?"
		badge.add_theme_color_override("font_color", branch_col.lightened(0.2))
	elif can:
		badge.text = str(cost)
		badge.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40))
	elif branch_ok:
		badge.text = str(cost)
		badge.add_theme_color_override("font_color", Color(0.70, 0.76, 0.70))
	else:
		badge.text = ""
	root.add_child(badge)

	if can:
		var tw := root.create_tween().set_loops()
		tw.tween_property(root, "modulate", Color(1.10, 1.06, 0.95), 0.8)
		tw.tween_property(root, "modulate", Color.WHITE, 0.8)

	root.mouse_entered.connect(func():
		_show_skill_tip(skill_id, root)
		root.scale = Vector2(1.06, 1.06)
	)
	root.mouse_exited.connect(func():
		root.scale = Vector2.ONE
		## Ne cache que si on quitte ce n?ud (?vite les races)
		if _skill_tip_skill_id == skill_id:
			_hide_skill_tip()
	)
	root.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if can:
				GameState.buy_skill(skill_id)
				_rebuild_skill_modal()
				_refresh_player_hud()
	)
	return root


func _fill_relics() -> void:
	side_content.add_child(_relic_info_panel())

	if not _last_relic_draft.is_empty() and (Time.get_ticks_msec() / 1000.0 - _last_relic_draft_t) < 3.0:
		var def: Dictionary = GameState.relic_defs().get(_last_relic_draft, {})
		var banner := PanelContainer.new()
		var bst := StyleBoxFlat.new()
		bst.bg_color = Color(0.55, 0.28, 0.45, 0.95)
		bst.border_color = Color(0.92, 0.72, 0.42, 0.9)
		bst.set_border_width_all(2)
		bst.set_corner_radius_all(10)
		bst.content_margin_left = 10
		bst.content_margin_right = 10
		bst.content_margin_top = 8
		bst.content_margin_bottom = 8
		banner.add_theme_stylebox_override("panel", bst)
		var bl := Label.new()
		bl.text = "Dernier draft : %s (niv.%d)" % [
			str(def.get("title", _last_relic_draft)),
			GameState.get_relic_level(_last_relic_draft),
		]
		bl.add_theme_font_size_override("font_size", 12)
		bl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.86))
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		banner.add_child(bl)
		side_content.add_child(banner)

	var defs: Dictionary = GameState.relic_defs()
	var tag_order := ["Farm", "Livraison", "Meta"]
	var by_tag: Dictionary = {}
	for t in tag_order:
		by_tag[t] = []
	for relic_id in GameState.relic_order():
		var rid := str(relic_id)
		if not defs.has(rid):
			continue
		var tag := str(defs[rid].get("tag", "Meta"))
		if not by_tag.has(tag):
			by_tag[tag] = []
			tag_order.append(tag)
		by_tag[tag].append(rid)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_content.add_child(list)

	for tag in tag_order:
		var ids: Array = by_tag.get(tag, [])
		if ids.is_empty():
			continue
		list.add_child(_shop_section_title(tag, Color(0.58, 0.28, 0.48)))
		var group := VBoxContainer.new()
		group.add_theme_constant_override("separation", 6)
		group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(group)
		for rid in ids:
			group.add_child(_relic_list_row(str(rid), defs[str(rid)]))


func _relic_info_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.42, 0.22, 0.36, 0.96)
	st.border_color = Color(0.78, 0.42, 0.62, 0.9)
	st.set_border_width_all(2)
	st.set_corner_radius_all(12)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", st)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	if _textures.has("ui_tab_prestige"):
		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(24, 24)
		ic.texture = _textures["ui_tab_prestige"]
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		head.add_child(ic)
	var title := Label.new()
	title.text = "Reliques permanentes"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.86))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)

	var tip := Label.new()
	tip.text = "Choix libre d'une relique parmi 3 selectionnees aleatoirement a chaque nouveau prestige."
	tip.add_theme_font_size_override("font_size", 11)
	tip.add_theme_color_override("font_color", Color(0.90, 0.76, 0.84))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(tip)
	return panel


func _relic_list_row(relic_id: String, def: Dictionary) -> Control:
	var lvl := GameState.get_relic_level(relic_id)
	var owned := lvl > 0
	var open := _selected_relic_id == relic_id

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var header := PanelContainer.new()
	header.custom_minimum_size = Vector2(0, 44)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var st := StyleBoxFlat.new()
	if open:
		st.bg_color = Color(0.58, 0.32, 0.48, 0.98)
		st.border_color = Color(0.95, 0.75, 0.40, 1.0)
		st.set_border_width_all(2)
		st.corner_radius_top_left = 10
		st.corner_radius_top_right = 10
		st.corner_radius_bottom_left = 0
		st.corner_radius_bottom_right = 0
	elif owned:
		st.bg_color = Color(0.88, 0.82, 0.90, 0.96)
		st.border_color = Color(0.62, 0.36, 0.52, 0.75)
		st.set_border_width_all(1)
		st.set_corner_radius_all(10)
	else:
		st.bg_color = Color(0.74, 0.74, 0.76, 0.90)
		st.border_color = Color(0.52, 0.52, 0.55, 0.55)
		st.set_border_width_all(1)
		st.set_corner_radius_all(10)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	header.add_theme_stylebox_override("panel", st)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(row)

	## Ic?ne ? gauche (toujours)
	var icon_key := str(def.get("icon", "ui_tab_prestige"))
	if _textures.has(icon_key):
		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(28, 28)
		ic.texture = _textures[icon_key]
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		ic.modulate = Color.WHITE if owned else Color(0.55, 0.55, 0.58, 0.85)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
	else:
		var ph := Label.new()
		ph.text = "?"
		ph.add_theme_font_size_override("font_size", 16)
		ph.add_theme_color_override("font_color", Color(0.50, 0.46, 0.50))
		ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ph)

	var name_l := Label.new()
	name_l.text = str(def.get("title", relic_id))
	name_l.add_theme_font_size_override("font_size", 13)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.add_theme_color_override(
		"font_color",
		Color(1, 0.94, 0.90) if open else (Color(0.26, 0.16, 0.22) if owned else Color(0.42, 0.40, 0.44))
	)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_l)

	if owned:
		var lvl_l := Label.new()
		lvl_l.text = "niv.%d" % lvl
		lvl_l.add_theme_font_size_override("font_size", 11)
		lvl_l.add_theme_color_override(
			"font_color",
			Color(0.95, 0.78, 0.40) if open else Color(0.48, 0.28, 0.42)
		)
		lvl_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lvl_l)
	else:
		## Cadenas ? droite si verrouill?e
		if _textures.has("ui_lock"):
			var lock := TextureRect.new()
			lock.custom_minimum_size = Vector2(20, 20)
			lock.texture = _textures["ui_lock"]
			lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			lock.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			lock.modulate = Color(0.55, 0.52, 0.58)
			lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(lock)
		else:
			var lock_l := Label.new()
			lock_l.text = "x"
			lock_l.add_theme_font_size_override("font_size", 14)
			lock_l.add_theme_color_override("font_color", Color(0.50, 0.48, 0.52))
			lock_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(lock_l)

	var chevron := Label.new()
	chevron.text = "v" if open else ">"
	chevron.add_theme_font_size_override("font_size", 12)
	chevron.add_theme_color_override(
		"font_color",
		Color(0.95, 0.86, 0.78) if open else Color(0.50, 0.46, 0.50)
	)
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(chevron)

	header.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if _selected_relic_id == relic_id:
				_selected_relic_id = ""
			else:
				_selected_relic_id = relic_id
			_rebuild_side()
	)
	root.add_child(header)

	if open:
		root.add_child(_relic_drawer(relic_id, def))

	return root


func _relic_drawer(relic_id: String, def: Dictionary) -> PanelContainer:
	var lvl := GameState.get_relic_level(relic_id)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.92, 0.86, 0.92, 0.98)
	st.border_color = Color(0.95, 0.75, 0.40, 1.0)
	st.border_width_left = 2
	st.border_width_right = 2
	st.border_width_bottom = 2
	st.border_width_top = 0
	st.corner_radius_bottom_left = 10
	st.corner_radius_bottom_right = 10
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 8
	st.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", st)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var desc := Label.new()
	desc.text = str(def.get("desc", ""))
	if lvl > 0:
		desc.text += "\nEffet : %s" % GameState.relic_effect_summary(relic_id, lvl)
	else:
		desc.text += "\nVerrouillee - obtiens-la via le draft au prestige."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.38, 0.28, 0.34))
	box.add_child(desc)

	if lvl > 0 and lvl < GameState.RELIC_MAX_LEVEL:
		var up_cost := GameState.relic_upgrade_cost(relic_id)
		var can_up := GameState.prestige_points >= up_cost
		var up_btn := Button.new()
		up_btn.focus_mode = Control.FOCUS_NONE
		up_btn.text = "Ameliorer  -  %d pts" % up_cost
		up_btn.disabled = not can_up
		up_btn.pressed.connect(func():
			if GameState.upgrade_relic(relic_id):
				_rebuild_side()
				_refresh_player_hud()
		)
		box.add_child(up_btn)
	elif lvl >= GameState.RELIC_MAX_LEVEL:
		var max_l := Label.new()
		max_l.text = "Niveau maximum atteint."
		max_l.add_theme_font_size_override("font_size", 11)
		max_l.add_theme_color_override("font_color", Color(0.48, 0.36, 0.42))
		box.add_child(max_l)

	return panel


func _on_field_action(index: int, _from_drag: bool = false) -> void:
	_drag_done[index] = true
	var p: Dictionary = GameState.plots[index]
	if not p["unlocked"]:
		return

	if p["crop"] == null:
		GameState.plant_on_plot(index)
		return
	if p["ready"]:
		GameState.harvest_plot(index)
		return
	# Plante en pousse : 1 clic = 1 tick (click_power).
	var power := GameState.click_power()
	if GameState.accelerate_plot(index, power):
		_play_plot_click_fx(index, power, true)


func _play_plot_click_fx(index: int, seconds_gained: float, show_float: bool = true) -> void:
	for t in _plot_tiles:
		if t.index == index:
			t.play_click_boost_fx(seconds_gained, show_float)
			return


func _on_fertilizer_pulse(source_index: int) -> void:
	## Salve : cultures dans la port?e (8 cases autour de base, ?0,5 s chacune).
	if source_index < 0 or source_index >= _plot_tiles.size():
		return
	if _active_terrain_modal != null and is_instance_valid(_active_terrain_modal):
		return
	var src: PlotTile = _plot_tiles[source_index]
	var targets := GameState.fertilizer_salvo_targets(source_index)
	if targets.is_empty():
		return
	var power := GameState.fertilizer_salvo_seconds()
	_spawn_fertilizer_salvo_ring(src)
	var any := false
	for ti in targets:
		if GameState.accelerate_plot(ti, power, false, false):
			any = true
		_spawn_fertilizer_star(src, _plot_tiles[ti], power)
	if any:
		GameState.plots_changed.emit()


func _on_gardener_harvest(source_index: int, target_index: int, crop_id: StringName = &"") -> void:
	## Bras du jardinier vers la culture r?colt?e / replant?e.
	if source_index < 0 or source_index >= _plot_tiles.size():
		return
	if target_index < 0 or target_index >= _plot_tiles.size():
		return
	if _active_terrain_modal != null and is_instance_valid(_active_terrain_modal):
		return
	var src: PlotTile = _plot_tiles[source_index]
	var dst: PlotTile = _plot_tiles[target_index]
	src.play_gardener_action_fx()
	_spawn_gardener_arm(src, dst, crop_id)


func _spawn_gardener_arm(from_tile: PlotTile, to_tile: PlotTile, crop_id: StringName = &"") -> void:
	## Tourelle fixe = sprite. Bras mobile texture + pince ancree + legume saisi.
	var socket := from_tile.gardener_emit_global()
	var aim := to_tile.crop_hit_global()
	var remain := aim - socket
	if remain.length_squared() < 0.01:
		remain = Vector2(0.25, -1.0)
	var reach := clampf(remain.length(), 26.0, 76.0)
	var tip_dir0 := remain.normalized()
	var tip_target := socket + tip_dir0 * reach
	var flex := lerpf(5.0, 16.0, inverse_lerp(26.0, 76.0, reach))

	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.z_index = 72
	host.top_level = true
	add_child(host)

	## Pivot de sortie (charniere haut tourelle).
	var hub := _make_arm_joint(Color(0.82, 0.62, 0.28), 12.0)
	host.add_child(hub)
	hub.global_position = socket - hub.size * 0.5

	## Couches bras : outline / bois / grain / laiton.
	var mov_outline := _make_arm_line(11.0, Color(0.14, 0.10, 0.06, 0.98))
	var mov_dark := _make_arm_line(8.2, Color(0.48, 0.32, 0.14, 0.95))
	var mov_wood := _make_arm_line(6.4, Color(0.86, 0.64, 0.34, 0.98))
	var mov_grain_a := _make_arm_line(1.6, Color(0.62, 0.42, 0.18, 0.55))
	var mov_brass := _make_arm_line(2.4, Color(0.92, 0.74, 0.38, 0.85))
	var mov_hi := _make_arm_line(1.4, Color(0.98, 0.90, 0.68, 0.55))
	host.add_child(mov_outline)
	host.add_child(mov_dark)
	host.add_child(mov_wood)
	host.add_child(mov_grain_a)
	host.add_child(mov_brass)
	host.add_child(mov_hi)

	var mid_joint := _make_arm_joint(Color(0.82, 0.62, 0.28), 9.0)
	host.add_child(mid_joint)
	var ring_a := _make_arm_joint(Color(0.72, 0.52, 0.22), 7.0)
	var ring_b := _make_arm_joint(Color(0.72, 0.52, 0.22), 7.0)
	host.add_child(ring_a)
	host.add_child(ring_b)

	var rivets: Array[Panel] = []
	for _i in 3:
		var riv := _make_arm_joint(Color(0.90, 0.72, 0.36), 4.5)
		host.add_child(riv)
		rivets.append(riv)

	## Ancre poignet : origin = bout du bras = poignet de la pince.
	var tip_anchor := Node2D.new()
	host.add_child(tip_anchor)

	var wrist_cap := _make_arm_joint(Color(0.78, 0.58, 0.24), 8.0)
	tip_anchor.add_child(wrist_cap)
	wrist_cap.position = -wrist_cap.size * 0.5

	var claw := Sprite2D.new()
	claw.centered = false
	claw.z_index = 3
	claw.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if _textures.has("ui_gardener_claw"):
		claw.texture = _textures["ui_gardener_claw"]
	else:
		claw.texture = _make_gardener_claw_fallback()
	var claw_disp := 28.0
	var claw_tex_sz := claw.texture.get_size() if claw.texture != null else Vector2(28, 28)
	var claw_s := claw_disp / maxf(claw_tex_sz.x, 1.0)
	claw.scale = Vector2(claw_s, claw_s)
	## Poignet ~ bas-centre du sprite -> origin de tip_anchor.
	const WRIST_U := 0.50
	const WRIST_V := 0.94
	claw.position = Vector2(-claw_tex_sz.x * claw_s * WRIST_U, -claw_tex_sz.y * claw_s * WRIST_V)
	tip_anchor.add_child(claw)

	var held := Sprite2D.new()
	held.centered = true
	held.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	## Derriere la pince (premier plan) pour rester visible dans le berceau.
	held.z_index = 1
	held.visible = false
	held.modulate.a = 0.0
	## Petite icone dans le berceau des doigts (local -Y = vers les pinces).
	held.position = Vector2(0, -21)
	var icon_key := "icon_%s" % String(crop_id)
	if crop_id != &"" and _textures.has(icon_key):
		held.texture = _textures[icon_key]
	elif crop_id != &"" and _textures.has("%s_6" % String(crop_id)):
		held.texture = _textures["%s_6" % String(crop_id)]
	if held.texture != null:
		var ht := held.texture.get_size()
		var hs := 27.5 / maxf(ht.x, 1.0)
		held.scale = Vector2(hs, hs)
	tip_anchor.add_child(held)

	var state := {"hit": false, "holding": false}
	var update_arm := func(t: float) -> void:
		var tip: Vector2 = socket.lerp(tip_target, t)
		var side := Vector2(-(tip - socket).y, (tip - socket).x)
		if side.length_squared() > 0.01:
			side = side.normalized()
		else:
			side = Vector2(0, -1)
		var mid: Vector2 = (socket + tip) * 0.5 + side * (flex * sin(t * PI))
		var mov := PackedVector2Array([socket, mid, tip])
		mov_outline.points = mov
		mov_dark.points = mov
		mov_wood.points = mov
		mov_brass.points = mov
		mov_hi.points = mov
		var grain_off := side * 1.6
		mov_grain_a.points = PackedVector2Array([
			socket + grain_off, mid + grain_off, tip + grain_off
		])
		mid_joint.global_position = mid - mid_joint.size * 0.5
		ring_a.global_position = socket.lerp(mid, 0.45) - ring_a.size * 0.5
		ring_b.global_position = mid.lerp(tip, 0.55) - ring_b.size * 0.5
		for ri in rivets.size():
			var u := (float(ri) + 1.0) / (float(rivets.size()) + 1.0)
			var rp: Vector2
			if u < 0.5:
				rp = socket.lerp(mid, clampf(u * 2.0, 0.0, 1.0))
			else:
				rp = mid.lerp(tip, clampf((u - 0.5) * 2.0, 0.0, 1.0))
			rivets[ri].global_position = rp - rivets[ri].size * 0.5

		var tip_dir := tip - mid
		if tip_dir.length_squared() < 0.01:
			tip_dir = tip_dir0
		tip_anchor.global_position = tip
		tip_anchor.rotation = tip_dir.angle() + PI * 0.5

		var grip_t := clampf((t - 0.72) / 0.28, 0.0, 1.0)
		tip_anchor.scale = Vector2(lerpf(1.0, 0.92, grip_t), lerpf(1.0, 1.08, grip_t))
		tip_anchor.visible = t > 0.04

		## Apparait des que le bras arrive pres du plant.
		if t >= 0.72 and held.texture != null:
			state["holding"] = true
		if state["holding"] and held.texture != null:
			held.visible = true
			if t >= 0.72:
				held.modulate.a = clampf((t - 0.72) / 0.12, 0.0, 1.0)
			else:
				held.modulate.a = 1.0

		if t >= 0.98 and not state["hit"]:
			state["hit"] = true
			to_tile.play_gardener_harvest_fx()

	update_arm.call(0.04)
	var tw := create_tween()
	tw.set_parallel(false)
	## Aller un peu plus rapide vers le legume.
	tw.tween_method(update_arm, 0.04, 1.0, 0.88).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.32)
	## Retour rapide vers le jardinier.
	tw.tween_method(update_arm, 1.0, 0.04, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		var drop_from := tip_anchor.global_position
		if held.visible and held.texture != null:
			drop_from = held.global_position
		host.queue_free()
		if crop_id != &"":
			_spawn_crop_to_stock_fly(drop_from, crop_id)
	)

func _stock_chip_center_global(crop_id: StringName) -> Vector2:
	for chip in _seed_buttons:
		if not is_instance_valid(chip):
			continue
		if chip.get_meta("crop_id", &"") != crop_id:
			continue
		return chip.get_global_rect().get_center()
	if seed_row != null and is_instance_valid(seed_row):
		return seed_row.get_global_rect().get_center()
	var vr := get_viewport_rect()
	return Vector2(vr.size.x * 0.5, vr.size.y - 48.0)


func _spawn_crop_to_stock_fly(from_global: Vector2, crop_id: StringName) -> void:
	## L?gume d?pos? au robot ? vole vers le chip stock en bas.
	var ikey := "icon_%s" % String(crop_id)
	if not _textures.has(ikey):
		return
	var fly := TextureRect.new()
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly.top_level = true
	fly.z_index = 95
	fly.size = Vector2(22, 22)
	fly.custom_minimum_size = fly.size
	fly.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fly.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fly.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fly.texture = _textures[ikey]
	fly.pivot_offset = fly.size * 0.5
	add_child(fly)
	fly.global_position = from_global - fly.size * 0.5

	var dest_c := _stock_chip_center_global(crop_id)
	var dest := dest_c - fly.size * 0.5
	var mid := (from_global + dest_c) * 0.5 + Vector2(0, -36)

	var tw := create_tween()
	tw.set_parallel(false)
	var fly_step := func(u: float) -> void:
		## Courbe simple robot -> arc -> stock.
		var a: Vector2 = from_global.lerp(mid, u)
		var b: Vector2 = mid.lerp(dest_c, u)
		var p: Vector2 = a.lerp(b, u)
		fly.global_position = p - fly.size * 0.5
		fly.scale = Vector2.ONE * lerpf(0.85, 1.15, sin(u * PI))
	tw.tween_method(fly_step, 0.0, 1.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		## Petit pulse sur le chip stock.
		for chip in _seed_buttons:
			if not is_instance_valid(chip):
				continue
			if chip.get_meta("crop_id", &"") != crop_id:
				continue
			var pulse := create_tween()
			pulse.tween_property(chip, "scale", Vector2(1.08, 1.08), 0.08)
			pulse.tween_property(chip, "scale", Vector2.ONE, 0.12)
			break
		fly.queue_free()
	)


func _make_arm_line(width: float, color: Color) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	return line


func _make_arm_joint(color: Color, diameter: float) -> Panel:
	var joint := Panel.new()
	joint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joint.size = Vector2(diameter, diameter)
	joint.pivot_offset = joint.size * 0.5
	var st := StyleBoxFlat.new()
	st.bg_color = color
	st.border_color = Color(0.22, 0.14, 0.08, 1.0)
	st.set_border_width_all(2)
	st.set_corner_radius_all(int(diameter * 0.5))
	joint.add_theme_stylebox_override("panel", st)
	return joint


func _make_gardener_claw_fallback() -> ImageTexture:
	var img := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	## Petite pince en V.
	for y in 28:
		for x in 28:
			var p := Vector2(x - 14.0, y - 14.0)
			var left := absf(p.x + 5.0) < 2.2 and p.y > -2.0 and p.y < 10.0
			var right := absf(p.x - 5.0) < 2.2 and p.y > -2.0 and p.y < 10.0
			var hub := p.length() < 4.5
			if left or right or hub:
				img.set_pixel(x, y, Color(0.62, 0.66, 0.70, 1.0))
	return ImageTexture.create_from_image(img)


func _spawn_fertilizer_salvo_ring(from_tile: PlotTile) -> void:
	## Anneau de particules autour du drone au moment de la salve.
	var origin := from_tile.fertilizer_emit_global()
	for i in 8:
		var star := TextureRect.new()
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.top_level = true
		star.z_index = 88
		star.size = Vector2(14, 14)
		star.custom_minimum_size = star.size
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.texture = _textures["ui_sparkle"] if _textures.has("ui_sparkle") else _make_green_star_texture()
		star.modulate = Color(0.4, 1.0, 0.45, 0.95)
		add_child(star)
		star.pivot_offset = star.size * 0.5
		star.global_position = origin - star.size * 0.5
		var ang := TAU * float(i) / 8.0
		var dest := origin + Vector2(cos(ang), sin(ang)) * 56.0 - star.size * 0.5
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(star, "global_position", dest, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(star, "modulate:a", 0.0, 0.35).set_delay(0.08)
		tw.tween_property(star, "scale", Vector2(0.4, 0.4), 0.35)
		tw.chain().tween_callback(star.queue_free)


func _spawn_fertilizer_star(from_tile: PlotTile, to_tile: PlotTile, seconds_gained: float = 0.0) -> void:
	var star := TextureRect.new()
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star.top_level = true
	star.z_index = 90
	star.custom_minimum_size = Vector2(20, 20)
	star.size = Vector2(20, 20)
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if _textures.has("ui_sparkle"):
		star.texture = _textures["ui_sparkle"]
	else:
		star.texture = _make_green_star_texture()
	star.modulate = Color(0.40, 1.0, 0.42, 1.0)
	add_child(star)
	var start := from_tile.fertilizer_emit_global() - star.size * 0.5
	var end := to_tile.crop_hit_global() - star.size * 0.5
	star.global_position = start
	star.pivot_offset = star.size * 0.5
	var mid := (start + end) * 0.5 + Vector2(randf_range(-22.0, 22.0), randf_range(-36.0, -10.0))
	## Vol un peu plus long pour que la salve reste lisible.
	var dur := clampf(start.distance_to(end) / 520.0, 0.38, 0.70)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(star, "rotation", randf_range(-3.2, 3.2), dur)
	tw.tween_property(star, "scale", Vector2(1.25, 1.25), dur * 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_method(_fert_star_bezier.bind(star, start, mid, end), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_callback(func():
		if is_instance_valid(to_tile):
			to_tile.play_fertilizer_boost_fx(seconds_gained)
		if is_instance_valid(star):
			star.queue_free()
	)


func _fert_star_bezier(star: Control, start: Vector2, mid: Vector2, end: Vector2, t: float) -> void:
	if not is_instance_valid(star):
		return
	var a := start.lerp(mid, t)
	var b := mid.lerp(end, t)
	star.global_position = a.lerp(b, t)


func _make_green_star_texture() -> Texture2D:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(12, 12)
	for y in 24:
		for x in 24:
			var p := Vector2(x + 0.5, y + 0.5) - c
			var r := p.length()
			var arm := minf(absf(p.x), absf(p.y))
			var on := (absf(p.x) < 2.2 and r < 10.5) or (absf(p.y) < 2.2 and r < 10.5) or (arm < 1.6 and r < 7.0)
			if on:
				img.set_pixel(x, y, Color(0.35, 0.95, 0.40, 1.0))
	return ImageTexture.create_from_image(img)


func _on_xp(current: int, required: int) -> void:
	xp_bar.max_value = maxf(1.0, float(required))
	xp_bar.value = mini(current, required)
	xp_label.text = "Prochain niveau : %d/%d XP" % [current, required]
	xp_bar.modulate = Color.WHITE
	xp_label.add_theme_font_size_override("font_size", 10)
	_style_bar_overlay_label(xp_label)
	_refresh_player_hud()


func _on_prestige() -> void:
	if not GameState.can_prestige():
		_show_toast("Atteins le niveau %d pour prestigier." % GameState.prestige_level_required())
		return
	var modal := PrestigeConfirmScript.present(self, _textures)
	modal.confirmed.connect(func():
		var draft := RelicDraftModalScript.present(self, _textures)
		draft.picked.connect(func(relic_id: String):
			_rebuilding_ui = true
			GameState.do_prestige_with_relic(relic_id)
			_last_relic_draft = relic_id
			_last_relic_draft_t = Time.get_ticks_msec() / 1000.0
			_selected_relic_id = relic_id
			_rebuilding_ui = false
			_reload_run_ui(false)
			_show_toast("Prestige reussi - relique obtenue !")
		)
	)


func _refresh_all() -> void:
	_on_money(GameState.money)
	_on_xp(GameState.xp, GameState.xp_required)
	_on_level(GameState.player_level, GameState.skill_points)
	_refresh_player_hud()
	_update_plot_visuals()
	_rebuild_stock()
	_rebuild_missions()
	_rebuild_side()
	_refresh_combo_ui()


func _update_plot_visuals() -> void:
	for tile in _plot_tiles:
		var i: int = tile.index
		if i < 0 or i >= GameState.plots.size():
			continue
		tile.refresh(GameState.plots[i], GameState.plot_progress(i), _pulse_t)


func _update_next_hint() -> void:
	pass


func _show_toast(msg: String) -> void:
	toast_label.text = msg
	toast_label.modulate = Color(0.55, 0.72, 0.35)
	var tw := create_tween()
	tw.tween_property(toast_label, "modulate", Color(0.32, 0.48, 0.28), 0.35)
	_toast_timer = 2.5
