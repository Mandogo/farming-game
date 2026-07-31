class_name DebugCheatPanel
extends ColorRect
## Panneau de cheats (F1) — build debug / éditeur.


signal closed
signal applied


static func cheats_available() -> bool:
	return OS.is_debug_build()


static func present(host: Node) -> DebugCheatPanel:
	var modal := DebugCheatPanel.new()
	host.add_child(modal)
	modal._build()
	return modal


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.04, 0.05, 0.06, 0.55)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 320
	top_level = true

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.94, 0.95, 0.92, 0.99)
	st.border_color = Color(0.35, 0.55, 0.38, 0.95)
	st.set_border_width_all(2)
	st.set_corner_radius_all(12)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 12
	st.content_margin_bottom = 12
	st.shadow_color = Color(0, 0, 0, 0.28)
	st.shadow_size = 10
	panel.add_theme_stylebox_override("panel", st)
	add_child(panel)

	gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if not panel.get_global_rect().has_point(ev.global_position):
				dismiss()
	)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	root.add_child(head)
	var title := Label.new()
	title.text = "Debug  ·  F1"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.22, 0.36, 0.24))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := _btn("✕", dismiss, Vector2(36, 32))
	head.add_child(close)

	var status := Label.new()
	status.name = "StatusLabel"
	status.add_theme_font_size_override("font_size", 11)
	status.add_theme_color_override("font_color", Color(0.38, 0.42, 0.36))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status)
	_refresh_status(status)

	## Action star
	root.add_child(_btn("Tout faire pousser (instant)", func():
		_run(func(): GameState.debug_instant_grow_field())
	, Vector2(0, 40), true))

	root.add_child(_sep("Ressources"))
	root.add_child(_row([
		_btn("+1k or", func(): _run(func(): GameState.debug_add_money(1000))),
		_btn("+10k or", func(): _run(func(): GameState.debug_add_money(10000))),
		_btn("+100k or", func(): _run(func(): GameState.debug_add_money(100000))),
	]))
	root.add_child(_custom_row("Or", func(n: int): _run(func(): GameState.debug_add_money(n))))

	root.add_child(_row([
		_btn("+500 XP", func(): _run(func(): GameState.debug_add_xp(500))),
		_btn("+5k XP", func(): _run(func(): GameState.debug_add_xp(5000))),
		_btn("+50k XP", func(): _run(func(): GameState.debug_add_xp(50000))),
	]))
	root.add_child(_custom_row("XP", func(n: int): _run(func(): GameState.debug_add_xp(maxi(0, n)))))

	root.add_child(_row([
		_btn("+5 PC", func(): _run(func(): GameState.debug_add_skill_points(5))),
		_btn("Nv. → prestige", func(): _run(func(): GameState.debug_set_player_level(GameState.prestige_level_required()))),
	]))

	root.add_child(_sep("Prestige / meta"))
	root.add_child(_row([
		_btn("+5 pts", func(): _run(func(): GameState.debug_add_prestige_points(5))),
		_btn("+20 pts", func(): _run(func(): GameState.debug_add_prestige_points(20))),
		_btn("P +1", func(): _run(func(): GameState.debug_add_prestige_level(1))),
	]))
	root.add_child(_row([
		_btn("→ P1", func(): _run(func(): GameState.debug_set_prestige_level(1))),
		_btn("→ P3", func(): _run(func(): GameState.debug_set_prestige_level(3))),
		_btn("→ P6", func(): _run(func(): GameState.debug_set_prestige_level(6))),
		_btn("→ P10", func(): _run(func(): GameState.debug_set_prestige_level(10))),
	]))
	root.add_child(_row([
		_btn("Reliques max", func(): _run(func(): GameState.debug_grant_all_relics(GameState.RELIC_MAX_LEVEL))),
		_btn("Skip tuto", func(): _run(func(): GameState.debug_skip_tutorial())),
	]))

	root.add_child(_sep("Terrain"))
	root.add_child(_row([
		_btn("Parcelles max", func(): _run(func(): GameState.debug_unlock_all_plots())),
		_btn("Shop max", func(): _run(func(): GameState.debug_max_shop())),
		_btn("Stock +50", func(): _run(func(): GameState.debug_fill_stock(50))),
	]))

	var tip := Label.new()
	tip.text = "Échap / F1 pour fermer · build debug uniquement"
	tip.add_theme_font_size_override("font_size", 10)
	tip.add_theme_color_override("font_color", Color(0.50, 0.54, 0.48))
	root.add_child(tip)

	call_deferred("_center", panel)


func _sep(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.32, 0.48, 0.34))
	return l


func _row(buttons: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for b in buttons:
		var btn := b as Button
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(btn)
	return row


func _custom_row(label: String, on_ok: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var edit := LineEdit.new()
	edit.placeholder_text = "Montant %s…" % label
	edit.custom_minimum_size = Vector2(0, 36)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", 13)
	edit.add_theme_color_override("font_color", Color(0.18, 0.22, 0.16))
	row.add_child(edit)
	var apply := _btn("OK", func():
		var raw := edit.text.strip_edges()
		if raw.is_empty() or not raw.is_valid_int():
			GameState.toast.emit("[Debug] Entier invalide")
			return
		on_ok.call(int(raw))
		edit.text = ""
	, Vector2(56, 36))
	edit.text_submitted.connect(func(_s: String): apply.pressed.emit())
	row.add_child(apply)
	return row


func _btn(text: String, on_press: Callable, min_size: Vector2 = Vector2(0, 36), accent: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 13)
	var n := StyleBoxFlat.new()
	if accent:
		n.bg_color = Color(0.42, 0.62, 0.38, 1.0)
		n.border_color = Color(0.28, 0.45, 0.26, 1.0)
	else:
		n.bg_color = Color(0.86, 0.90, 0.82, 1.0)
		n.border_color = Color(0.55, 0.62, 0.48, 0.85)
	n.set_border_width_all(1)
	n.set_corner_radius_all(8)
	n.content_margin_left = 10
	n.content_margin_right = 10
	n.content_margin_top = 6
	n.content_margin_bottom = 6
	b.add_theme_stylebox_override("normal", n)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = n.bg_color.lightened(0.08)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_color_override("font_color", Color(0.98, 0.99, 0.96) if accent else Color(0.18, 0.24, 0.16))
	b.pressed.connect(on_press)
	return b


func _run(action: Callable) -> void:
	action.call()
	applied.emit()
	var status := find_child("StatusLabel", true, false) as Label
	if status:
		_refresh_status(status)


func _refresh_status(status: Label) -> void:
	status.text = "Or %d   ·   Nv.%d (%d PC)   ·   P%d · %d pts" % [
		GameState.money,
		GameState.player_level,
		GameState.skill_points,
		GameState.prestige_level,
		GameState.prestige_points,
	]


func _center(panel: Control) -> void:
	var vp := get_viewport_rect().size
	panel.reset_size()
	panel.custom_minimum_size = Vector2(400, 0)
	var sz := panel.get_combined_minimum_size()
	panel.position = (vp - sz) * 0.5


func dismiss() -> void:
	closed.emit()
	queue_free()
