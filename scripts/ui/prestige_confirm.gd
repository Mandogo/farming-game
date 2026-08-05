class_name PrestigeConfirm
extends ColorRect
## Modal prestige — pertes + déblocages (cartes).

signal confirmed
signal cancelled

var _textures: Dictionary = {}


static func present(host: Node, textures: Dictionary = {}) -> PrestigeConfirm:
	var modal := PrestigeConfirm.new()
	host.add_child(modal)
	modal._build(textures)
	return modal


func _build(textures: Dictionary) -> void:
	_textures = textures
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.08, 0.04, 0.08, 0.68)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 270
	top_level = true

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.96, 0.92, 0.94, 0.99)
	st.border_color = Color(0.72, 0.32, 0.52, 0.95)
	st.set_border_width_all(2)
	st.set_corner_radius_all(14)
	st.content_margin_left = 18
	st.content_margin_right = 18
	st.content_margin_top = 16
	st.content_margin_bottom = 16
	st.shadow_color = Color(0.40, 0.10, 0.25, 0.35)
	st.shadow_size = 12
	panel.add_theme_stylebox_override("panel", st)
	add_child(panel)
	gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if not panel.get_global_rect().has_point(ev.global_position):
				_cancel()
	)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	panel.add_child(body)

	## —— En-tête ——
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	body.add_child(head)
	_add_icon(head, "ui_coin_prestige", Vector2(36, 36))
	var title := Label.new()
	title.text = "Prestiger ?"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.48, 0.16, 0.32))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)

	## —— Ce que tu perds ——
	var lost_wrap := _make_section_panel(
		"Tu perds",
		Color(0.72, 0.28, 0.30),
		Color(0.98, 0.92, 0.92, 0.98),
		Color(0.86, 0.55, 0.55, 0.9)
	)
	body.add_child(lost_wrap)
	_fill_lost(lost_wrap.get_child(0) as VBoxContainer)

	## —— Boost permanent (explication courte) ——
	body.add_child(_make_boost_tip())

	## —— Déblocages ——
	var unlock_wrap := _make_section_panel(
		"Déblocages",
		Color(0.28, 0.42, 0.58),
		Color(0.92, 0.95, 0.98, 0.98),
		Color(0.55, 0.68, 0.82, 0.9)
	)
	body.add_child(unlock_wrap)
	_fill_unlocks(unlock_wrap.get_child(0) as VBoxContainer)

	## —— Actions ——
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	actions.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(actions)

	var cancel := Button.new()
	cancel.text = "Annuler"
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.custom_minimum_size = Vector2(110, 40)
	cancel.pressed.connect(_cancel)
	actions.add_child(cancel)

	var ok := Button.new()
	ok.text = "Continuer"
	ok.focus_mode = Control.FOCUS_NONE
	ok.custom_minimum_size = Vector2(130, 40)
	ok.add_theme_font_size_override("font_size", 14)
	var ok_st := StyleBoxFlat.new()
	ok_st.bg_color = Color(0.78, 0.28, 0.52, 1.0)
	ok_st.border_color = Color(0.58, 0.18, 0.38, 1.0)
	ok_st.set_border_width_all(1)
	ok_st.set_corner_radius_all(9)
	ok_st.content_margin_left = 12
	ok_st.content_margin_right = 12
	ok.add_theme_stylebox_override("normal", ok_st)
	var ok_h := ok_st.duplicate() as StyleBoxFlat
	ok_h.bg_color = Color(0.88, 0.38, 0.58, 1.0)
	ok.add_theme_stylebox_override("hover", ok_h)
	ok.add_theme_color_override("font_color", Color(1, 0.96, 0.98))
	ok.pressed.connect(_confirm)
	actions.add_child(ok)

	call_deferred("_center", panel)


func _make_section_panel(title_text: String, title_col: Color, bg: Color, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(1)
	st.set_corner_radius_all(10)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 8
	st.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", st)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", title_col)
	col.add_child(title)
	return panel


func _fill_lost(col: VBoxContainer) -> void:
	if col == null:
		return
	## Lignes générales en bandeau horizontal — sans montants.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	_add_simple_row(row, "ui_coin", "Or / Améliorations")
	_add_simple_row(row, "ui_xp", "XP / Niveau")
	_add_simple_row(row, "ui_coin_skill", "Compétences")
	_add_simple_row(row, "ui_truck", "Stocks")


func _fill_unlocks(col: VBoxContainer) -> void:
	if col == null:
		return
	var current_p := GameState.prestige_level + 1
	var max_tier := GameState.prestige_max_unlock_tier()
	var gain := GameState.calc_prestige_points_gain()

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 118)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	scroll.add_child(row)

	## Pts prestige de CE prestige — toujours à gauche.
	row.add_child(_make_unlock_card({
		"kind": "prestige_pts",
		"id": "prestige_pts",
		"label": "+%d pts" % gain,
		"icon": "ui_coin_prestige",
	}, true, current_p))

	for tier in range(current_p, max_tier + 1):
		var items := GameState.prestige_unlocks_at(tier)
		for item in items:
			var is_current := tier == current_p
			row.add_child(_make_unlock_card(item, is_current, tier))


func _make_boost_tip() -> PanelContainer:
	var per := GameState.prestige_bonus_pct_per_point()
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.97, 0.94, 0.90, 0.98)
	st.border_color = Color(0.82, 0.62, 0.38, 0.85)
	st.set_border_width_all(1)
	st.set_corner_radius_all(10)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", st)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	_add_icon(row, "ui_coin_prestige", Vector2(22, 22))
	var lab := Label.new()
	lab.text = "Chaque pièce de prestige : +%d%% or et XP (permanent)." % per
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.add_theme_font_size_override("font_size", 12)
	lab.add_theme_color_override("font_color", Color(0.36, 0.26, 0.20))
	row.add_child(lab)
	return panel


func _make_unlock_card(item: Dictionary, unlocked_now: bool, prestige_tier: int) -> PanelContainer:
	var card := PanelContainer.new()
	var kind := str(item.get("kind", ""))
	card.custom_minimum_size = Vector2(100, 108)
	var st := StyleBoxFlat.new()
	if unlocked_now:
		st.bg_color = Color(1.0, 0.98, 0.90, 1.0)
		st.border_color = Color(0.82, 0.58, 0.20, 0.95)
	else:
		st.bg_color = Color(0.88, 0.89, 0.91, 1.0)
		st.border_color = Color(0.62, 0.64, 0.68, 0.9)
	st.set_border_width_all(1)
	st.set_corner_radius_all(9)
	st.content_margin_left = 6
	st.content_margin_right = 6
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", st)

	var root := Control.new()
	root.custom_minimum_size = Vector2(88, 96)
	card.add_child(root)

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(v)

	var icon_wrap := CenterContainer.new()
	icon_wrap.custom_minimum_size = Vector2(40, 40)
	icon_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(icon_wrap)
	var ic := TextureRect.new()
	ic.custom_minimum_size = Vector2(40, 40)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var icon_key := str(item.get("icon", ""))
	if icon_key != "" and _textures.has(icon_key):
		ic.texture = _textures[icon_key]
	if not unlocked_now:
		ic.modulate = Color(0.55, 0.55, 0.58, 0.85)
	icon_wrap.add_child(ic)

	## Cadenas en haut à droite de la card (futurs paliers).
	if not unlocked_now:
		var lock := TextureRect.new()
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.custom_minimum_size = Vector2(16, 16)
		lock.size = Vector2(16, 16)
		lock.anchor_left = 1.0
		lock.anchor_right = 1.0
		lock.anchor_top = 0.0
		lock.anchor_bottom = 0.0
		lock.offset_left = -18.0
		lock.offset_right = -2.0
		lock.offset_top = 2.0
		lock.offset_bottom = 18.0
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if _textures.has("ui_lock"):
			lock.texture = _textures["ui_lock"]
		root.add_child(lock)

	var name_lab := Label.new()
	name_lab.text = str(item.get("label", "?"))
	name_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lab.add_theme_font_size_override("font_size", 11)
	if unlocked_now:
		name_lab.add_theme_color_override("font_color", Color(0.22, 0.24, 0.28))
	else:
		name_lab.add_theme_color_override("font_color", Color(0.45, 0.46, 0.48))
	v.add_child(name_lab)

	var tag := Label.new()
	var custom_tag := str(item.get("tag", ""))
	if custom_tag != "":
		tag.text = custom_tag
	elif unlocked_now:
		if kind == "crop":
			tag.text = "Culture"
		elif kind == "machine":
			tag.text = "Machine"
		elif kind == "relic":
			tag.text = "Relique"
		elif kind == "prestige_pts":
			tag.text = "Prestige"
		else:
			tag.text = kind.capitalize()
	else:
		tag.text = "Prestige %d" % prestige_tier
	if unlocked_now:
		tag.add_theme_color_override("font_color", Color(0.42, 0.48, 0.36))
	else:
		tag.add_theme_color_override("font_color", Color(0.50, 0.52, 0.56))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.add_theme_font_size_override("font_size", 10)
	v.add_child(tag)
	return card


func _add_simple_row(parent: Control, icon_key: String, label: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(row)
	_add_icon(row, icon_key, Vector2(18, 18))
	var lab := Label.new()
	lab.text = label
	lab.add_theme_font_size_override("font_size", 12)
	lab.add_theme_color_override("font_color", Color(0.28, 0.24, 0.26))
	row.add_child(lab)


func _add_icon(parent: Control, key: String, size: Vector2) -> void:
	var ic := TextureRect.new()
	ic.custom_minimum_size = size
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if key != "" and _textures.has(key):
		ic.texture = _textures[key]
	parent.add_child(ic)


func _center(panel: Control) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var vp := get_viewport_rect().size
	panel.reset_size()
	var sz := panel.get_combined_minimum_size()
	panel.position = (vp - sz) * 0.5


func _confirm() -> void:
	confirmed.emit()
	queue_free()


func _cancel() -> void:
	cancelled.emit()
	queue_free()
