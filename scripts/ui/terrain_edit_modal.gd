class_name TerrainEditModal
extends ColorRect
## Modal centré — jetons à gauche + grille 2D au centre + actions en bas.

signal closed(applied: bool)

const CELL := 36
const CELL_GAP := 2

var _textures: Dictionary = {}
var _snapshot: Dictionary = {}
var _draft: Dictionary = {}
var _tool: String = "land" ## land | fertilizer | gardener
var _panel: PanelContainer
var _grid: GridContainer
var _cell_btns: Array = [] ## Button
var _help_label: Label
var _token_col: VBoxContainer
var _token_btns: Dictionary = {} ## tool_id -> PanelContainer
var _grid_host: Control
var _range_overlay: Control
var _hover_cell: int = -1


static func present(host: Node, textures: Dictionary = {}) -> TerrainEditModal:
	var modal := TerrainEditModal.new()
	host.add_child(modal)
	modal._textures = textures
	modal._build()
	return modal


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.04, 0.07, 0.05, 0.72)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 275
	top_level = true

	_snapshot = GameState.snapshot_terrain_layout()
	_draft = _snapshot.duplicate(true)

	## Centre le panneau dans l’écran (évite le débordement bas).
	var screen_center := CenterContainer.new()
	screen_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen_center)

	gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if _panel and not _panel.get_global_rect().has_point(ev.global_position):
				pass
	)

	_panel = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.94, 0.95, 0.90, 0.99)
	st.border_color = Color(0.42, 0.55, 0.34, 0.95)
	st.set_border_width_all(2)
	st.set_corner_radius_all(16)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 12
	st.content_margin_bottom = 12
	st.shadow_color = Color(0.05, 0.10, 0.06, 0.40)
	st.shadow_size = 16
	_panel.add_theme_stylebox_override("panel", st)
	screen_center.add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	_panel.add_child(root)

	## ——— En-tête ———
	var title := Label.new()
	title.text = "Editer le terrain"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.22, 0.36, 0.20))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	_help_label = Label.new()
	_help_label.add_theme_font_size_override("font_size", 11)
	_help_label.add_theme_color_override("font_color", Color(0.42, 0.38, 0.22))
	_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_help_label)

	## ——— Corps : jetons gauche + grille centre ———
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var token_wrap := VBoxContainer.new()
	token_wrap.add_theme_constant_override("separation", 6)
	token_wrap.custom_minimum_size = Vector2(118, 0)
	token_wrap.clip_contents = false
	body.add_child(token_wrap)

	var token_title := Label.new()
	token_title.text = "Disponible"
	token_title.clip_text = false
	token_title.custom_minimum_size = Vector2(110, 16)
	token_title.add_theme_font_size_override("font_size", 12)
	token_title.add_theme_color_override("font_color", Color(0.40, 0.48, 0.36))
	token_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	token_wrap.add_child(token_title)

	_token_col = VBoxContainer.new()
	_token_col.add_theme_constant_override("separation", 8)
	_token_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_token_col.alignment = BoxContainer.ALIGNMENT_CENTER
	token_wrap.add_child(_token_col)
	_add_token_chip("land", "Terre", "ui_shop_plot", Color(0.55, 0.42, 0.28))
	_add_token_chip("fertilizer", "Fertiliseur", "ui_fertilizer", Color(0.28, 0.62, 0.38))
	_add_token_chip("gardener", "Jardinier", "ui_gardener", Color(0.78, 0.62, 0.18))

	var field_center := CenterContainer.new()
	field_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field_center.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(field_center)

	var field_frame := PanelContainer.new()
	var ff := StyleBoxFlat.new()
	ff.bg_color = Color(0.58, 0.72, 0.55, 0.55)
	ff.border_color = Color(0.42, 0.52, 0.32, 0.55)
	ff.set_border_width_all(2)
	ff.set_corner_radius_all(12)
	ff.content_margin_left = 8
	ff.content_margin_right = 8
	ff.content_margin_top = 8
	ff.content_margin_bottom = 8
	ff.shadow_color = Color(0.15, 0.22, 0.14, 0.18)
	ff.shadow_size = 6
	field_frame.add_theme_stylebox_override("panel", ff)
	field_center.add_child(field_frame)

	_grid_host = Control.new()
	_grid_host.mouse_filter = Control.MOUSE_FILTER_PASS
	field_frame.add_child(_grid_host)

	_grid = GridContainer.new()
	_grid.columns = GameState.GRID_W
	_grid.add_theme_constant_override("h_separation", CELL_GAP)
	_grid.add_theme_constant_override("v_separation", CELL_GAP)
	_grid_host.add_child(_grid)

	_range_overlay = Control.new()
	_range_overlay.name = "RangeOverlay"
	_range_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_range_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_range_overlay.draw.connect(_draw_range_overlay)
	_grid_host.add_child(_range_overlay)

	_build_grid()

	## ——— Actions bas ———
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(actions)

	var reset_btn := _make_action_btn("Reset", Color(0.94, 0.82, 0.28, 0.96), Color(0.72, 0.58, 0.14), Vector2(120, 40))
	reset_btn.tooltip_text = ""
	reset_btn.pressed.connect(_on_reset)
	actions.add_child(reset_btn)

	var cancel := _make_action_btn("Annuler", Color(0.86, 0.52, 0.48, 0.92), Color(0.62, 0.32, 0.30), Vector2(120, 40))
	cancel.tooltip_text = ""
	cancel.pressed.connect(_on_cancel)
	actions.add_child(cancel)

	var ok := _make_action_btn("Accepter", Color(0.42, 0.74, 0.50, 0.95), Color(0.28, 0.55, 0.36), Vector2(120, 40))
	ok.pressed.connect(_on_validate)
	actions.add_child(ok)

	_refresh_token_ui()
	_update_help()
	if not GameState.terrain_edit_seen:
		_help_label.text = "Tuto — Clique un jeton à gauche, puis une case. Accepter pour garder."
		GameState.terrain_edit_seen = true
		GameState.save_game()

	resized.connect(_fit_panel)
	call_deferred("_fit_panel")


func _fit_panel() -> void:
	## Cap la taille pour rester dans ~90 % de l’écran ; CenterContainer gère le milieu.
	if _panel == null:
		return
	var vp := get_viewport_rect().size
	var max_w := vp.x * 0.92
	var max_h := vp.y * 0.90
	_panel.reset_size()
	var want := _panel.get_combined_minimum_size()
	want.x = minf(want.x, max_w)
	want.y = minf(want.y, max_h)
	_panel.custom_minimum_size = Vector2.ZERO
	## Si trop haut, on laisse le CenterContainer centrer le min size réel.
	if want.y > max_h * 0.98:
		## Dernier recours : le contenu reste compact grâce aux petites cellules.
		pass


func _make_action_btn(text: String, bg: Color, border: Color, min_size: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = min_size
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color(0.12, 0.18, 0.12))
	btn.add_theme_color_override("font_hover_color", Color(0.08, 0.14, 0.08))
	btn.add_theme_color_override("font_pressed_color", Color(0.18, 0.22, 0.16))
	for pair in [
		["normal", bg, border],
		["hover", bg.lightened(0.12), border.lightened(0.10)],
		["pressed", bg.darkened(0.10), border.darkened(0.08)],
	]:
		var box := StyleBoxFlat.new()
		box.bg_color = pair[1]
		box.border_color = pair[2]
		box.set_border_width_all(1)
		box.set_corner_radius_all(10)
		box.content_margin_left = 12
		box.content_margin_right = 12
		box.content_margin_top = 8
		box.content_margin_bottom = 8
		box.shadow_color = Color(0.08, 0.12, 0.10, 0.22)
		box.shadow_size = 4
		box.shadow_offset = Vector2(0, 2)
		btn.add_theme_stylebox_override(str(pair[0]), box)
	return btn


func _add_token_chip(tool_id: String, label: String, icon_key: String, accent: Color) -> void:
	var chip := PanelContainer.new()
	chip.focus_mode = Control.FOCUS_NONE
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.custom_minimum_size = Vector2(108, 88)
	chip.set_meta("accent", accent)
	chip.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_select_tool(tool_id)
			accept_event()
	)
	_token_col.add_child(chip)
	_token_btns[tool_id] = chip

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.add_child(v)

	var icon_wrap := PanelContainer.new()
	icon_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_wrap.custom_minimum_size = Vector2(44, 44)
	var iw := StyleBoxFlat.new()
	iw.bg_color = Color(accent.r, accent.g, accent.b, 0.18)
	iw.border_color = Color(accent.r, accent.g, accent.b, 0.45)
	iw.set_border_width_all(1)
	iw.set_corner_radius_all(10)
	iw.set_content_margin_all(3)
	icon_wrap.add_theme_stylebox_override("panel", iw)
	v.add_child(icon_wrap)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _textures.has(icon_key):
		icon.texture = _textures[icon_key]
	icon_wrap.add_child(icon)

	var name_l := Label.new()
	name_l.text = label
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 11)
	name_l.add_theme_color_override("font_color", Color(0.22, 0.30, 0.20))
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_l)

	var count_l := Label.new()
	count_l.name = "Count"
	count_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_l.add_theme_font_size_override("font_size", 12)
	count_l.add_theme_color_override("font_color", Color(0.32, 0.42, 0.28))
	count_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(count_l)


func _select_tool(tool_id: String) -> void:
	_tool = tool_id
	_refresh_token_ui()
	_update_help()
	_refresh_cell_visuals()


func _token_stock(tool_id: String) -> Vector2i:
	match tool_id:
		"land":
			var owned := int(_draft.get("unlocked_plots", 0))
			return Vector2i(maxi(0, owned - _count_draft_land()), owned)
		"fertilizer":
			var o := int(_draft.get("fertilizer_owned", 0))
			return Vector2i(maxi(0, o - _count_draft_machine(GameState.MACHINE_FERTILIZER)), o)
		"gardener":
			var o2 := int(_draft.get("gardener_owned", 0))
			return Vector2i(maxi(0, o2 - _count_draft_machine(GameState.MACHINE_GARDENER)), o2)
		_:
			return Vector2i(-1, -1)


func _refresh_token_ui() -> void:
	for tool_id in _token_btns.keys():
		var tid := str(tool_id)
		var chip: PanelContainer = _token_btns[tool_id]
		var selected: bool = (_tool == tid)
		var accent: Color = chip.get_meta("accent", Color(0.5, 0.55, 0.45))
		var st := StyleBoxFlat.new()
		if selected:
			st.bg_color = Color(
				lerpf(0.92, accent.r, 0.35),
				lerpf(0.94, accent.g, 0.35),
				lerpf(0.88, accent.b, 0.35),
				1.0
			)
			st.border_color = accent
			st.set_border_width_all(2)
			st.shadow_color = Color(accent.r, accent.g, accent.b, 0.28)
			st.shadow_size = 6
			st.shadow_offset = Vector2(0, 2)
		else:
			st.bg_color = Color(0.90, 0.92, 0.86, 1.0)
			st.border_color = Color(0.55, 0.60, 0.48, 0.55)
			st.set_border_width_all(1)
			st.shadow_color = Color(0.08, 0.12, 0.10, 0.12)
			st.shadow_size = 3
			st.shadow_offset = Vector2(0, 1)
		st.set_corner_radius_all(12)
		st.content_margin_left = 6
		st.content_margin_right = 6
		st.content_margin_top = 6
		st.content_margin_bottom = 4
		chip.add_theme_stylebox_override("panel", st)

		var count_l := chip.find_child("Count", true, false) as Label
		if count_l:
			var stock := _token_stock(tid)
			count_l.text = "%d / %d" % [stock.x, stock.y]
			chip.modulate = Color(1, 1, 1, 1) if stock.x > 0 or selected else Color(1, 1, 1, 0.55)


func _draft_cells() -> Array:
	return _draft.get("cells", []) as Array


func _cell(i: int) -> Dictionary:
	var cells := _draft_cells()
	if i < 0 or i >= cells.size():
		return {"unlocked": false, "machine": ""}
	return cells[i]


func _set_cell(i: int, unlocked: bool, machine: String) -> void:
	var cells: Array = _draft_cells()
	if i < 0 or i >= cells.size():
		return
	cells[i] = {"unlocked": unlocked, "machine": machine if unlocked else ""}
	_draft["cells"] = cells


func _count_draft_land() -> int:
	var n := 0
	for c in _draft_cells():
		if bool(c.get("unlocked", false)):
			n += 1
	return n


func _count_draft_machine(mid: String) -> int:
	var n := 0
	for c in _draft_cells():
		if str(c.get("machine", "")) == mid:
			n += 1
	return n


func _update_help() -> void:
	match _tool:
		"land":
			var left := maxi(0, int(_draft.get("unlocked_plots", 0)) - _count_draft_land())
			_help_label.text = "Terre — case vide pour poser (%d restant). Reclique pour retirer." % left
		"fertilizer":
			if _count_draft_land() <= 0:
				_help_label.text = "Place d’abord une terre — les machines se posent sur la terre."
			else:
				_help_label.text = "Fertiliseur — clique une terre (%d restant). Zone verte = portée." % maxi(
					0, int(_draft.get("fertilizer_owned", 0)) - _count_draft_machine(GameState.MACHINE_FERTILIZER)
				)
		"gardener":
			if _count_draft_land() <= 0:
				_help_label.text = "Place d’abord une terre — les machines se posent sur la terre."
			else:
				_help_label.text = "Jardinier — occupe la case (%d restant). Zone jaune = portée." % maxi(
					0, int(_draft.get("gardener_owned", 0)) - _count_draft_machine(GameState.MACHINE_GARDENER)
				)
		_:
			_help_label.text = ""


func _build_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_cell_btns.clear()
	for i in GameState.MAX_PLOTS:
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(CELL, CELL)
		btn.flat = false
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.clip_text = true
		btn.set_meta("cell_index", i)
		btn.pressed.connect(_on_cell_pressed.bind(i))
		btn.mouse_entered.connect(_on_cell_hover.bind(i))
		btn.mouse_exited.connect(_on_cell_unhover.bind(i))
		_grid.add_child(btn)
		_cell_btns.append(btn)
	call_deferred("_sync_grid_host_size")
	_refresh_cell_visuals()


func _sync_grid_host_size() -> void:
	if _grid == null or _grid_host == null:
		return
	var sz := _grid.get_combined_minimum_size()
	var pad := int(ceili(_range_radius_px(maxi(
		GameState.fertilizer_salvo_range(),
		GameState.gardener_range()
	))))
	_grid_host.custom_minimum_size = sz + Vector2(pad * 2, pad * 2)
	_grid_host.size = _grid_host.custom_minimum_size
	_grid.position = Vector2(pad, pad)
	_grid.size = sz
	if _range_overlay != null:
		_range_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_range_overlay.queue_redraw()


func _on_cell_hover(index: int) -> void:
	_hover_cell = index
	if _range_overlay != null:
		_range_overlay.queue_redraw()


func _on_cell_unhover(index: int) -> void:
	if _hover_cell == index:
		_hover_cell = -1
		if _range_overlay != null:
			_range_overlay.queue_redraw()


func _cell_center_local(index: int) -> Vector2:
	if index < 0 or index >= _cell_btns.size():
		return Vector2.ZERO
	var btn: Button = _cell_btns[index]
	return _grid.position + btn.position + btn.size * 0.5


func _range_radius_px(chebyshev_r: int) -> float:
	## Cercle qui enveloppe les centres des cases à distance Chebyshev r (+ marge bord case).
	var step := float(CELL + CELL_GAP)
	return step * float(chebyshev_r) + float(CELL) * 0.42


func _draw_range_ring(center: Vector2, chebyshev_r: int, fill: Color, stroke: Color) -> void:
	if chebyshev_r <= 0 or _range_overlay == null:
		return
	var radius := _range_radius_px(chebyshev_r)
	_range_overlay.draw_circle(center, radius, fill)
	_range_overlay.draw_arc(center, radius, 0.0, TAU, 64, stroke, 2.2, true)


func _draw_range_overlay() -> void:
	if _range_overlay == null or _cell_btns.is_empty():
		return
	var fr := GameState.fertilizer_salvo_range()
	var gr := GameState.gardener_range()
	## Jardiniers d’abord (dessous), fertiliseurs au-dessus.
	for i in GameState.MAX_PLOTS:
		var mid := str(_cell(i).get("machine", ""))
		if mid != GameState.MACHINE_GARDENER or not bool(_cell(i).get("unlocked", false)):
			continue
		_draw_range_ring(
			_cell_center_local(i),
			gr,
			Color(0.92, 0.78, 0.22, 0.16),
			Color(0.86, 0.68, 0.12, 0.85)
		)
	for i in GameState.MAX_PLOTS:
		var mid := str(_cell(i).get("machine", ""))
		if mid != GameState.MACHINE_FERTILIZER or not bool(_cell(i).get("unlocked", false)):
			continue
		_draw_range_ring(
			_cell_center_local(i),
			fr,
			Color(0.32, 0.78, 0.38, 0.20),
			Color(0.22, 0.72, 0.32, 0.92)
		)
	## Aperçu au survol pendant la pose.
	if _hover_cell >= 0 and bool(_cell(_hover_cell).get("unlocked", false)):
		var mid_h := str(_cell(_hover_cell).get("machine", ""))
		if _tool == "fertilizer" and mid_h != GameState.MACHINE_GARDENER:
			_draw_range_ring(
				_cell_center_local(_hover_cell),
				fr,
				Color(0.32, 0.78, 0.38, 0.12),
				Color(0.28, 0.80, 0.36, 0.70)
			)
		elif _tool == "gardener" and mid_h != GameState.MACHINE_FERTILIZER:
			_draw_range_ring(
				_cell_center_local(_hover_cell),
				gr,
				Color(0.92, 0.78, 0.22, 0.10),
				Color(0.86, 0.68, 0.12, 0.65)
			)


func _cell_style(bg: Color, border: Color, border_w: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(5)
	s.set_content_margin_all(1)
	return s


func _refresh_cell_visuals() -> void:
	for i in _cell_btns.size():
		var btn: Button = _cell_btns[i]
		var c := _cell(i)
		var has_land := bool(c.get("unlocked", false))
		var mid := str(c.get("machine", ""))

		var bg: Color
		var border: Color
		if has_land:
			bg = Color(0.58, 0.44, 0.30, 1.0)
			border = Color(0.38, 0.28, 0.18, 0.90)
			if mid == GameState.MACHINE_FERTILIZER:
				border = Color(0.22, 0.55, 0.30, 1.0)
			elif mid == GameState.MACHINE_GARDENER:
				border = Color(0.78, 0.62, 0.12, 1.0)
		else:
			bg = Color(0.72, 0.80, 0.66, 0.55)
			border = Color(0.50, 0.58, 0.42, 0.45)

		var style := _cell_style(bg, border, 2 if mid != "" else 1)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", _cell_style(bg.lightened(0.08), border.lightened(0.1), 2))
		btn.add_theme_stylebox_override("pressed", _cell_style(bg.darkened(0.08), border, 2))

		btn.icon = null
		btn.text = ""
		if mid == GameState.MACHINE_FERTILIZER and _textures.has("ui_fertilizer"):
			btn.icon = _textures["ui_fertilizer"]
			btn.expand_icon = true
			btn.add_theme_constant_override("icon_max_width", 22)
		elif mid == GameState.MACHINE_GARDENER:
			if _textures.has("ui_gardener"):
				btn.icon = _textures["ui_gardener"]
			elif _textures.has("ui_auto_planter"):
				btn.icon = _textures["ui_auto_planter"]
			btn.expand_icon = true
			btn.add_theme_constant_override("icon_max_width", 22)

	_refresh_token_ui()
	_update_help()
	call_deferred("_sync_grid_host_size")
	if _range_overlay != null:
		_range_overlay.queue_redraw()


func _on_cell_pressed(index: int) -> void:
	_apply_tool(index)


func _apply_tool(index: int) -> void:
	var c := _cell(index)
	var has_land := bool(c.get("unlocked", false))
	var mid := str(c.get("machine", ""))
	match _tool:
		"land":
			if has_land:
				_set_cell(index, false, "")
			else:
				if _count_draft_land() >= int(_draft.get("unlocked_plots", 0)):
					_help_label.text = "Plus de jetons terre — achètes-en en boutique."
					return
				_set_cell(index, true, "")
		"fertilizer":
			if _count_draft_land() <= 0:
				_help_label.text = "Place d’abord une terre — les machines se posent sur la terre."
				return
			if not has_land:
				_help_label.text = "Pose le fertiliseur sur une terre."
				return
			if mid == GameState.MACHINE_FERTILIZER:
				_set_cell(index, true, "")
			elif mid == GameState.MACHINE_GARDENER:
				_help_label.text = "Case déjà occupée par un jardinier."
				return
			else:
				if _count_draft_machine(GameState.MACHINE_FERTILIZER) >= int(_draft.get("fertilizer_owned", 0)):
					_help_label.text = "Plus de fertiliseurs en stock."
					return
				_set_cell(index, true, GameState.MACHINE_FERTILIZER)
		"gardener":
			if _count_draft_land() <= 0:
				_help_label.text = "Place d’abord une terre — les machines se posent sur la terre."
				return
			if not has_land:
				_help_label.text = "Pose le jardinier sur une terre."
				return
			if mid == GameState.MACHINE_GARDENER:
				_set_cell(index, true, "")
			elif mid == GameState.MACHINE_FERTILIZER:
				_help_label.text = "Case déjà occupée par un fertiliseur."
				return
			else:
				if _count_draft_machine(GameState.MACHINE_GARDENER) >= int(_draft.get("gardener_owned", 0)):
					_help_label.text = "Plus de jardiniers en stock."
					return
				_set_cell(index, true, GameState.MACHINE_GARDENER)
	_refresh_cell_visuals()


func _on_reset() -> void:
	_draft = GameState.reset_terrain_to_stock()
	_draft["unlocked_plots"] = _snapshot.get("unlocked_plots", GameState.unlocked_plots)
	_draft["fertilizer_owned"] = _snapshot.get("fertilizer_owned", GameState.fertilizer_owned)
	_draft["gardener_owned"] = _snapshot.get("gardener_owned", GameState.gardener_owned)
	_draft["delivery_owned"] = _snapshot.get("delivery_owned", GameState.delivery_owned)
	_refresh_cell_visuals()


func _on_cancel() -> void:
	## Restaure exactement le layout d’avant ouverture d’Editer.
	GameState.apply_terrain_layout(_snapshot)
	closed.emit(false)
	queue_free()


func _on_validate() -> void:
	if _count_draft_land() <= 0:
		_help_label.text = "Place au moins une terre avant d’accepter."
		return
	GameState.apply_terrain_layout(_draft)
	closed.emit(true)
	queue_free()
