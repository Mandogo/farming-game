class_name RelicDraftModal
extends ColorRect
## Draft obligatoire au prestige : choisir 1 relique parmi 3.


signal picked(relic_id: String)


static func present(host: Node, textures: Dictionary = {}) -> RelicDraftModal:
	var modal := RelicDraftModal.new()
	host.add_child(modal)
	modal._build(textures)
	return modal


func _build(textures: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.08, 0.04, 0.10, 0.72)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 280
	top_level = true

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.96, 0.92, 0.94, 0.99)
	st.border_color = Color(0.72, 0.32, 0.52, 0.95)
	st.set_border_width_all(2)
	st.set_corner_radius_all(14)
	st.content_margin_left = 16
	st.content_margin_right = 16
	st.content_margin_top = 14
	st.content_margin_bottom = 14
	st.shadow_color = Color(0.40, 0.10, 0.25, 0.35)
	st.shadow_size = 12
	panel.add_theme_stylebox_override("panel", st)
	add_child(panel)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	panel.add_child(body)

	var title := Label.new()
	title.text = "Choisis une relique"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.48, 0.16, 0.32))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(title)

	var sub := Label.new()
	sub.text = "3 propositions · 1 choix · permanente. Améliore-la ensuite avec tes points de prestige."
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.42, 0.34, 0.40))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(sub)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(row)

	var options := GameState.build_relic_draft(3)
	var defs: Dictionary = GameState.relic_defs()
	for rid in options:
		row.add_child(_card(str(rid), defs.get(str(rid), {}), textures))

	call_deferred("_center", panel)


func _card(relic_id: String, def: Dictionary, textures: Dictionary) -> Control:
	var lvl := GameState.get_relic_level(relic_id)
	var at_max := lvl >= GameState.RELIC_MAX_LEVEL
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 210)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.94, 0.90, 0.93, 1.0)
	st.border_color = Color(0.72, 0.40, 0.55, 0.85)
	st.set_border_width_all(2)
	st.set_corner_radius_all(12)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", st)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(box)

	var tag := Label.new()
	tag.text = str(def.get("tag", "Meta"))
	tag.add_theme_font_size_override("font_size", 10)
	tag.add_theme_color_override("font_color", Color(0.62, 0.36, 0.48))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tag)

	var icon_key := str(def.get("icon", "ui_tab_prestige"))
	if textures.has(icon_key):
		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(48, 48)
		ic.texture = textures[icon_key]
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		box.add_child(ic)

	var name_l := Label.new()
	name_l.text = str(def.get("title", relic_id))
	name_l.add_theme_font_size_override("font_size", 13)
	name_l.add_theme_color_override("font_color", Color(0.28, 0.18, 0.24))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name_l)

	var status := Label.new()
	if lvl <= 0:
		status.text = "Nouvelle · niv.1"
	elif at_max:
		status.text = "Déjà max · niv.%d" % lvl
	else:
		status.text = "Possédée · niv.%d→%d" % [lvl, lvl + 1]
	status.add_theme_font_size_override("font_size", 11)
	status.add_theme_color_override("font_color", Color(0.48, 0.32, 0.40))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status)

	var effect := Label.new()
	var preview_lvl := 1 if lvl <= 0 else mini(GameState.RELIC_MAX_LEVEL, lvl + (0 if at_max else 1))
	effect.text = GameState.relic_effect_summary(relic_id, preview_lvl)
	effect.add_theme_font_size_override("font_size", 11)
	effect.add_theme_color_override("font_color", Color(0.36, 0.30, 0.34))
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(effect)

	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = "Choisir" if not at_max else "Continuer"
	btn.custom_minimum_size = Vector2(0, 34)
	btn.add_theme_font_size_override("font_size", 12)
	var bn := StyleBoxFlat.new()
	bn.bg_color = Color(0.78, 0.28, 0.52, 1.0)
	bn.border_color = Color(0.58, 0.18, 0.38, 1.0)
	bn.set_border_width_all(1)
	bn.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", bn)
	var bh := bn.duplicate() as StyleBoxFlat
	bh.bg_color = Color(0.88, 0.38, 0.58, 1.0)
	btn.add_theme_stylebox_override("hover", bh)
	btn.add_theme_color_override("font_color", Color(1, 0.96, 0.98))
	var pick_id := relic_id
	btn.pressed.connect(func(): _pick(pick_id))
	box.add_child(btn)
	return panel


func _pick(relic_id: String) -> void:
	picked.emit(relic_id)
	queue_free()


func _center(panel: Control) -> void:
	var vp := get_viewport_rect().size
	panel.reset_size()
	var sz := panel.get_combined_minimum_size()
	panel.position = (vp - sz) * 0.5
