class_name SellModal
extends ColorRect
## Modal de vente directe — compact, friendly.


signal closed
signal sold(crop_id: StringName, amount: int, gold: int)

var _crop_id: StringName = &""
var _textures: Dictionary = {}
var _panel: PanelContainer
var _body: VBoxContainer
var _qty: int = 1
var _qty_edit: LineEdit
var _confirm_btn: Button
var _stock_label: Label


static func present(host: Node, crop_id: StringName, textures: Dictionary = {}) -> SellModal:
	var modal := SellModal.new()
	modal._crop_id = crop_id
	modal._textures = textures
	host.add_child(modal)
	modal._build()
	return modal


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.05, 0.08, 0.06, 0.58)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 260
	top_level = true
	gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if _panel and not _panel.get_global_rect().has_point(ev.global_position):
				dismiss()
	)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(320, 0)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.95, 0.96, 0.91, 0.99)
	st.border_color = Color(0.62, 0.52, 0.18, 0.85)
	st.set_border_width_all(2)
	st.set_corner_radius_all(14)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 12
	st.content_margin_bottom = 12
	st.shadow_color = Color(0, 0, 0, 0.25)
	st.shadow_size = 8
	_panel.add_theme_stylebox_override("panel", st)
	add_child(_panel)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	_panel.add_child(_body)

	_rebuild()
	call_deferred("_center_panel")


func _center_panel() -> void:
	if _panel == null:
		return
	var vp := get_viewport_rect().size
	_panel.reset_size()
	var sz := _panel.get_combined_minimum_size()
	_panel.position = (vp - sz) * 0.5


func _stock() -> int:
	return GameState.get_stock(_crop_id)


func _unit() -> int:
	return GameState.unit_sell_price(_crop_id)


func _make_close_btn() -> Control:
	## Cercle strict : wrapper fixe 28×28 (évite l’ovale dans le HBox header).
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(28, 28)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_PASS

	var btn := Button.new()
	btn.text = "×"
	btn.focus_mode = Control.FOCUS_NONE
	btn.flat = false
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.offset_left = 0
	btn.offset_top = 0
	btn.offset_right = 0
	btn.offset_bottom = 0
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 15)
	var bg := Color(0.92, 0.90, 0.84, 0.95)
	var bd := Color(0.62, 0.50, 0.32, 0.70)
	var fg := Color(0.32, 0.22, 0.12, 1.0)
	var hv := Color(0.98, 0.94, 0.86, 1.0)
	var pr := Color(0.86, 0.80, 0.70, 1.0)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg)
	btn.add_theme_color_override("font_pressed_color", fg.darkened(0.15))
	for pair in [["normal", bg, bd], ["hover", hv, bd.lightened(0.12)], ["pressed", pr, bd]]:
		var box := StyleBoxFlat.new()
		box.bg_color = pair[1]
		box.border_color = pair[2]
		box.set_border_width_all(1)
		box.set_corner_radius_all(14)
		box.content_margin_left = 0
		box.content_margin_right = 0
		box.content_margin_top = 0
		box.content_margin_bottom = 1
		btn.add_theme_stylebox_override(str(pair[0]), box)
	btn.pressed.connect(dismiss)
	holder.add_child(btn)
	return holder


func _rebuild() -> void:
	## Nouveau body + queue_free de l’ancien : évite free() sur nœud verrouillé (pressed)
	## et l’agrandissement dû aux enfants encore présents 1 frame.
	_confirm_btn = null
	_qty_edit = null
	_stock_label = null
	var old_body := _body
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	_panel.add_child(_body)
	if old_body != null and is_instance_valid(old_body):
		_panel.remove_child(old_body)
		old_body.queue_free()

	var crop := GameState.get_crop(_crop_id)
	if crop == null:
		dismiss()
		return
	var stock := _stock()
	_qty = clampi(_qty if _qty > 0 else 1, 1, maxi(1, stock)) if stock > 0 else 0

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	_body.add_child(head)

	var icon_key := "icon_%s" % String(_crop_id)
	if _textures.has(icon_key):
		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(36, 36)
		ic.texture = _textures[icon_key]
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		head.add_child(ic)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 1)
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(titles)

	var title := Label.new()
	title.text = "Vendre — %s" % crop.display_name
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.20, 0.16, 0.10))
	titles.add_child(title)

	_stock_label = Label.new()
	_stock_label.add_theme_font_size_override("font_size", 11)
	_stock_label.add_theme_color_override("font_color", Color(0.42, 0.38, 0.28))
	titles.add_child(_stock_label)

	head.add_child(_make_close_btn())

	if stock <= 0:
		_stock_label.text = "Stock : x0"
		var empty := Label.new()
		empty.text = "Rien à vendre pour l’instant."
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", Color(0.50, 0.46, 0.38))
		_body.add_child(empty)
		call_deferred("_center_panel")
		return

	_stock_label.text = "Stock : x%d  ·  %d or / unité" % [stock, _unit()]

	## Stepper −− / − / qty (saisissable) / + / ++
	var stepper := HBoxContainer.new()
	stepper.add_theme_constant_override("separation", 6)
	stepper.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.add_child(stepper)
	stepper.add_child(_step_btn("--", -10))
	stepper.add_child(_step_btn("−", -1))

	_qty_edit = LineEdit.new()
	_qty_edit.custom_minimum_size = Vector2(72, 32)
	_qty_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qty_edit.add_theme_font_size_override("font_size", 18)
	_qty_edit.add_theme_color_override("font_color", Color(0.18, 0.22, 0.14))
	_qty_edit.add_theme_color_override("font_uneditable_color", Color(0.18, 0.22, 0.14))
	_qty_edit.add_theme_color_override("caret_color", Color(0.40, 0.48, 0.28))
	_qty_edit.placeholder_text = "1"
	_qty_edit.context_menu_enabled = false
	var le_n := StyleBoxFlat.new()
	le_n.bg_color = Color(1, 1, 1, 0.95)
	le_n.border_color = Color(0.55, 0.60, 0.48, 0.7)
	le_n.set_border_width_all(1)
	le_n.set_corner_radius_all(7)
	le_n.content_margin_left = 6
	le_n.content_margin_right = 6
	_qty_edit.add_theme_stylebox_override("normal", le_n)
	var le_f := le_n.duplicate() as StyleBoxFlat
	le_f.border_color = Color(0.72, 0.58, 0.18, 0.95)
	le_f.bg_color = Color(1, 0.99, 0.94, 1.0)
	_qty_edit.add_theme_stylebox_override("focus", le_f)
	_qty_edit.text_changed.connect(_on_qty_text_changed)
	_qty_edit.text_submitted.connect(func(_t: String):
		_apply_qty_from_edit()
		_qty_edit.release_focus()
	)
	_qty_edit.focus_exited.connect(_apply_qty_from_edit)
	_qty_edit.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_qty_edit.select_all()
	)
	stepper.add_child(_qty_edit)

	stepper.add_child(_step_btn("+", 1))
	stepper.add_child(_step_btn("++", 10))

	## Raccourcis : ½ et Tout seulement
	var shortcuts := HBoxContainer.new()
	shortcuts.add_theme_constant_override("separation", 8)
	shortcuts.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.add_child(shortcuts)
	shortcuts.add_child(_chip_btn("½", -2, stock >= 2))
	shortcuts.add_child(_chip_btn("Tout", -1, stock >= 1))

	## Bouton vendre compact
	_confirm_btn = Button.new()
	_confirm_btn.focus_mode = Control.FOCUS_NONE
	_confirm_btn.custom_minimum_size = Vector2(0, 36)
	_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_btn.add_theme_font_size_override("font_size", 13)
	var cn := StyleBoxFlat.new()
	cn.bg_color = Color(0.78, 0.58, 0.16, 1.0)
	cn.border_color = Color(0.58, 0.40, 0.10, 1.0)
	cn.set_border_width_all(1)
	cn.set_corner_radius_all(8)
	cn.content_margin_left = 10
	cn.content_margin_right = 10
	cn.content_margin_top = 6
	cn.content_margin_bottom = 6
	_confirm_btn.add_theme_stylebox_override("normal", cn)
	var ch := cn.duplicate() as StyleBoxFlat
	ch.bg_color = Color(0.88, 0.68, 0.22, 1.0)
	_confirm_btn.add_theme_stylebox_override("hover", ch)
	var cp := cn.duplicate() as StyleBoxFlat
	cp.bg_color = Color(0.68, 0.50, 0.14, 1.0)
	_confirm_btn.add_theme_stylebox_override("pressed", cp)
	var cd := cn.duplicate() as StyleBoxFlat
	cd.bg_color = Color(0.62, 0.64, 0.58, 0.9)
	_confirm_btn.add_theme_stylebox_override("disabled", cd)
	_confirm_btn.add_theme_color_override("font_color", Color(1, 0.98, 0.92))
	_confirm_btn.add_theme_color_override("font_disabled_color", Color(0.85, 0.86, 0.82))
	_confirm_btn.set_meta("tut_sell_confirm", true)
	_confirm_btn.pressed.connect(_confirm_sell)
	_body.add_child(_confirm_btn)

	_refresh_qty_ui()
	call_deferred("_center_panel")


func get_confirm_button() -> Button:
	return _confirm_btn


func _step_btn(text: String, delta: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(40 if text.length() > 1 else 36, 32)
	btn.add_theme_font_size_override("font_size", 13 if text.length() > 1 else 16)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.90, 0.92, 0.86, 1.0)
	n.border_color = Color(0.55, 0.60, 0.48, 0.65)
	n.set_border_width_all(1)
	n.set_corner_radius_all(7)
	btn.add_theme_stylebox_override("normal", n)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.96, 0.94, 0.82, 1.0)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_color_override("font_color", Color(0.22, 0.26, 0.18))
	btn.pressed.connect(func(): _change_qty(delta))
	return btn


func _chip_btn(text: String, amount_or_code: int, enabled: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.disabled = not enabled
	btn.custom_minimum_size = Vector2(72, 28)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 12)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.88, 0.90, 0.84, 1.0) if enabled else Color(0.82, 0.84, 0.80, 0.65)
	n.border_color = Color(0.55, 0.60, 0.48, 0.65)
	n.set_border_width_all(1)
	n.set_corner_radius_all(6)
	n.content_margin_left = 10
	n.content_margin_right = 10
	btn.add_theme_stylebox_override("normal", n)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.94, 0.92, 0.78, 1.0)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_color_override("font_color", Color(0.24, 0.28, 0.18))
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.58, 0.52))
	var code := amount_or_code
	btn.pressed.connect(func(): _set_quick(code))
	return btn


func _change_qty(delta: int) -> void:
	var stock := _stock()
	if stock <= 0:
		return
	_qty = clampi(_qty + delta, 1, stock)
	_refresh_qty_ui()


func _set_quick(code: int) -> void:
	var stock := _stock()
	if stock <= 0:
		return
	if code == -1:
		_qty = stock
	elif code == -2:
		_qty = maxi(1, int(floor(float(stock) * 0.5)))
	else:
		_qty = clampi(code, 1, stock)
	_refresh_qty_ui()


func _on_qty_text_changed(new_text: String) -> void:
	## Filtre : chiffres uniquement pendant la saisie.
	var cleaned := ""
	for i in new_text.length():
		var ch := new_text[i]
		if ch >= "0" and ch <= "9":
			cleaned += ch
	if cleaned != new_text:
		var caret := _qty_edit.caret_column
		_qty_edit.text = cleaned
		_qty_edit.caret_column = mini(caret, cleaned.length())
	if cleaned.is_empty():
		return
	var stock := _stock()
	var v := clampi(int(cleaned), 1, maxi(1, stock))
	_qty = v
	## Met à jour le bouton or sans écraser le texte en cours de frappe.
	if _confirm_btn:
		var gold := GameState.preview_sell_gold(_crop_id, _qty)
		_confirm_btn.disabled = stock <= 0 or _qty <= 0
		_confirm_btn.text = "Vendre  ·  +%d or" % gold


func _apply_qty_from_edit() -> void:
	if _qty_edit == null:
		return
	var stock := _stock()
	if stock <= 0:
		_qty = 0
		_refresh_qty_ui()
		return
	var t := _qty_edit.text.strip_edges()
	if t.is_empty() or not t.is_valid_int():
		_qty = clampi(_qty, 1, stock)
	else:
		_qty = clampi(int(t), 1, stock)
	_refresh_qty_ui()


func _refresh_qty_ui() -> void:
	var stock := _stock()
	if _qty_edit and not _qty_edit.has_focus():
		_qty_edit.text = str(_qty) if _qty > 0 else ""
	var gold := GameState.preview_sell_gold(_crop_id, _qty) if _qty > 0 else 0
	if _confirm_btn:
		_confirm_btn.disabled = stock <= 0 or _qty <= 0
		_confirm_btn.text = ("Vendre  ·  +%d or" % gold) if _qty > 0 else "Vendre"
	if _stock_label and stock > 0:
		_stock_label.text = "Stock : x%d  ·  %d or / unité" % [stock, _unit()]


func _confirm_sell() -> void:
	_apply_qty_from_edit()
	if _qty <= 0:
		return
	var gold := GameState.sell_crop_amount(_crop_id, _qty)
	if gold <= 0:
		return
	var sold_crop := _crop_id
	var sold_qty := _qty
	sold.emit(sold_crop, sold_qty, gold)
	## Fermeture différée : ne pas liberer le modal pendant le pressed.
	call_deferred("dismiss")


func dismiss() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()
