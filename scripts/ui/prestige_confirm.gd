class_name PrestigeConfirm
extends ColorRect
## Modal de confirmation prestige — résume gains / pertes avant reset de run.

signal confirmed
signal cancelled


static func present(host: Node, textures: Dictionary = {}) -> PrestigeConfirm:
	var modal := PrestigeConfirm.new()
	host.add_child(modal)
	modal._build(textures)
	return modal


func _build(textures: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.08, 0.04, 0.08, 0.68)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 270
	top_level = true

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
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

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	body.add_child(head)
	if textures.has("ui_coin_prestige"):
		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(36, 36)
		ic.texture = textures["ui_coin_prestige"]
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		head.add_child(ic)
	var title := Label.new()
	title.text = "Prestige disponible !"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.48, 0.16, 0.32))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)

	var gain := GameState.calc_prestige_points_gain()
	var next_p := GameState.prestige_level + 1
	var summary := Label.new()
	summary.text = "Tu gagnes +%d point%s de prestige (Prestige %d → %d).\nSeuil fixe : niveau %d." % [
		gain, "s" if gain > 1 else "", GameState.prestige_level, next_p, GameState.prestige_level_required()
	]
	if GameState.prestige_level < 9:
		summary.text += "\nPts faibles jusqu’au 10ᵉ prestige — le draft de relique est la vraie récompense."
	elif GameState.prestige_level == 9:
		summary.text += "\n10ᵉ prestige : gros paquet de pts pour monter tes reliques !"
	else:
		summary.text += "\nPts destinés surtout à améliorer tes reliques."
	summary.add_theme_font_size_override("font_size", 13)
	summary.add_theme_color_override("font_color", Color(0.32, 0.22, 0.28))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(summary)

	body.add_child(_section(
		"Tu perds (run)",
		"Or, XP, niveau, compétences, stock, améliorations boutique et parcelles achetées.",
		Color(0.62, 0.28, 0.28)
	))
	body.add_child(_section(
		"Tu gardes",
		"Points de prestige, niveau de prestige, reliques permanentes.",
		Color(0.28, 0.48, 0.32)
	))
	body.add_child(_section(
		"Ensuite",
		"Tu choisiras 1 relique parmi 3 propositions (draft).",
		Color(0.48, 0.28, 0.52)
	))
	if GameState.has_skill("xp_prestige_prep"):
		var keep := Label.new()
		keep.text = "Ambition active : tu conserve 1 Point de Compétence."
		keep.add_theme_font_size_override("font_size", 12)
		keep.add_theme_color_override("font_color", Color(0.42, 0.36, 0.55))
		body.add_child(keep)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	actions.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(actions)

	var cancel := Button.new()
	cancel.text = "Pas encore"
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.custom_minimum_size = Vector2(110, 40)
	cancel.pressed.connect(_cancel)
	actions.add_child(cancel)

	var ok := Button.new()
	ok.text = "Prestiger (+%d)" % gain
	ok.focus_mode = Control.FOCUS_NONE
	ok.custom_minimum_size = Vector2(150, 40)
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


func _section(title: String, body_text: String, accent: Color) -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 2)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 13)
	t.add_theme_color_override("font_color", accent)
	wrap.add_child(t)
	var b := Label.new()
	b.text = body_text
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", Color(0.38, 0.34, 0.36))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wrap.add_child(b)
	return wrap


func _center(panel: Control) -> void:
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
