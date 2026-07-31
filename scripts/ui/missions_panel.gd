class_name MissionsPanel
extends RefCounted
## Onglet Missions — compact mais lisible.


static func fill(host: VBoxContainer, textures: Dictionary, on_claim: Callable) -> void:
	GameState.ensure_board_quests(false)
	host.add_theme_constant_override("separation", 5)
	## Marge droite supplémentaire pour ne pas coller la scrollbar.
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 4)
	pad.add_theme_constant_override("margin_left", 0)
	pad.add_theme_constant_override("margin_top", 0)
	pad.add_theme_constant_override("margin_bottom", 0)
	host.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(col)
	col.add_child(_section_title("Quotidiennes", Color(0.42, 0.55, 0.78), "daily"))
	_add_quests(col, "daily", textures, on_claim)
	col.add_child(_section_title("Hebdomadaires", Color(0.55, 0.42, 0.68), "weekly"))
	_add_quests(col, "weekly", textures, on_claim)
	col.add_child(_section_title("Carrière", Color(0.48, 0.58, 0.36), ""))
	_add_quests(col, "all", textures, on_claim)


static func _section_title(text: String, accent: Color, reset_scope: String) -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 1)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var bar := ColorRect.new()
	bar.custom_minimum_size = Vector2(3, 12)
	bar.color = accent
	row.add_child(bar)
	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", 10)
	lab.add_theme_color_override("font_color", accent.darkened(0.12))
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lab)
	wrap.add_child(row)
	if reset_scope == "daily" or reset_scope == "weekly":
		var reset_l := Label.new()
		reset_l.name = "ResetTimer"
		reset_l.set_meta("reset_scope", reset_scope)
		reset_l.add_theme_font_size_override("font_size", 8)
		reset_l.add_theme_color_override("font_color", Color(0.50, 0.54, 0.48))
		reset_l.text = _reset_text(reset_scope)
		wrap.add_child(reset_l)
	return wrap


static func _reset_text(scope: String) -> String:
	var sec := GameState.seconds_until_daily_reset() if scope == "daily" else GameState.seconds_until_weekly_reset()
	return "Prochain reset dans %s" % GameState.format_reset_countdown(sec)


static func refresh_reset_timers(host: Node) -> void:
	if host == null:
		return
	for n in host.find_children("ResetTimer", "Label", true, false):
		var lab := n as Label
		if lab == null:
			continue
		var scope := str(lab.get_meta("reset_scope", ""))
		if scope == "daily" or scope == "weekly":
			lab.text = _reset_text(scope)


static func _add_quests(host: VBoxContainer, scope: String, textures: Dictionary, on_claim: Callable) -> void:
	for q in GameState.get_board_quests(scope):
		host.add_child(_quest_card(q, textures, on_claim))


static func _status_label(claimed: bool, ready: bool) -> String:
	if claimed:
		return "Terminé"
	if ready:
		return "Prêt"
	return "En cours"


static func _btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(1)
	st.set_corner_radius_all(5)
	st.content_margin_left = 5
	st.content_margin_right = 5
	st.content_margin_top = 2
	st.content_margin_bottom = 2
	return st


static func _quest_card(q: Dictionary, textures: Dictionary, on_claim: Callable) -> PanelContainer:
	var claimed := bool(q.get("claimed", false))
	var goal := maxi(1, int(q.get("goal", 1)))
	var progress := clampi(int(q.get("progress", 0)), 0, goal)
	var ready := (not claimed) and progress >= goal
	var status := _status_label(claimed, ready)

	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	if claimed:
		## Archive — neutre, pas un vert « CTA »
		st.bg_color = Color(0.88, 0.90, 0.87, 0.72)
		st.border_color = Color(0.58, 0.62, 0.56, 0.40)
	elif ready:
		st.bg_color = Color(0.94, 0.95, 0.84, 0.97)
		st.border_color = Color(0.72, 0.58, 0.18, 0.85)
	else:
		st.bg_color = Color(0.90, 0.93, 0.88, 0.92)
		st.border_color = Color(0.55, 0.62, 0.50, 0.45)
	st.set_border_width_all(1)
	st.set_corner_radius_all(6)
	st.content_margin_left = 6
	st.content_margin_right = 6
	st.content_margin_top = 5
	st.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", st)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 3)
	panel.add_child(root)

	## Titre + statut collés + récompense à droite
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	root.add_child(head)

	var title := Label.new()
	title.text = "%s (%s)" % [str(q.get("title", "Mission")), status]
	title.add_theme_font_size_override("font_size", 10)
	if claimed:
		title.add_theme_color_override("font_color", Color(0.42, 0.46, 0.40))
	else:
		title.add_theme_color_override("font_color", Color(0.20, 0.24, 0.16))
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)

	var rl := Label.new()
	rl.text = "+%d" % int(q.get("reward_gold", 0))
	rl.add_theme_font_size_override("font_size", 10)
	if claimed:
		rl.add_theme_color_override("font_color", Color(0.55, 0.52, 0.42))
	else:
		rl.add_theme_color_override("font_color", Color(0.55, 0.42, 0.12))
	head.add_child(rl)
	if textures.has("ui_coin"):
		var coin := TextureRect.new()
		coin.custom_minimum_size = Vector2(11, 11)
		coin.texture = textures["ui_coin"]
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if claimed:
			coin.modulate = Color(1, 1, 1, 0.55)
		head.add_child(coin)

	## Description de l’objectif
	var desc := Label.new()
	desc.text = str(q.get("desc", ""))
	desc.add_theme_font_size_override("font_size", 9)
	if claimed:
		desc.add_theme_color_override("font_color", Color(0.52, 0.55, 0.50))
	else:
		desc.add_theme_color_override("font_color", Color(0.42, 0.46, 0.38))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(desc)

	## Barre fine (+ bouton seulement si pas encore claimé)
	var prog_row := HBoxContainer.new()
	prog_row.add_theme_constant_override("separation", 5)
	prog_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(prog_row)

	var bar_wrap := Control.new()
	bar_wrap.custom_minimum_size = Vector2(0, 10)
	bar_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prog_row.add_child(bar_wrap)
	var track := ColorRect.new()
	track.color = Color(0.72, 0.76, 0.70, 0.85)
	track.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar_wrap.add_child(track)
	var fill := ColorRect.new()
	if claimed:
		fill.color = Color(0.52, 0.62, 0.50, 0.85)
	elif ready:
		fill.color = Color(0.55, 0.78, 0.32, 1.0)
	else:
		fill.color = Color(0.48, 0.68, 0.36, 1.0)
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill.anchor_right = 1.0 if claimed or ready else (float(progress) / float(goal))
	bar_wrap.add_child(fill)
	var prog_l := Label.new()
	prog_l.text = "%d/%d" % [progress, goal]
	prog_l.add_theme_font_size_override("font_size", 8)
	prog_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prog_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prog_l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if claimed:
		prog_l.add_theme_color_override("font_color", Color(0.32, 0.36, 0.30))
	else:
		prog_l.add_theme_color_override("font_color", Color(0.16, 0.20, 0.14))
	prog_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_wrap.add_child(prog_l)

	## Option C : mission claimée = pas de bouton (carte archive).
	if claimed:
		return panel

	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(72, 20)
	btn.add_theme_font_size_override("font_size", 9)
	if ready:
		## Vert — à récupérer (disparaît après claim, plus de confusion)
		btn.text = "Récupérer"
		var g := _btn_style(Color(0.34, 0.68, 0.38, 1.0), Color(0.24, 0.52, 0.28, 1.0))
		btn.add_theme_stylebox_override("normal", g)
		var gh := g.duplicate() as StyleBoxFlat
		gh.bg_color = Color(0.42, 0.78, 0.46, 1.0)
		btn.add_theme_stylebox_override("hover", gh)
		btn.add_theme_stylebox_override("pressed", g)
		btn.add_theme_color_override("font_color", Color(0.95, 0.98, 0.94))
		var qid := str(q.get("id", ""))
		if qid == GameState.TUTORIAL_INTRO_QUEST_ID:
			btn.set_meta("tut_claim_btn", true)
		btn.pressed.connect(func(): on_claim.call(qid))
	else:
		## Grisé — pas encore fait
		btn.text = "Valider"
		var gray := _btn_style(Color(0.68, 0.70, 0.68, 0.9), Color(0.52, 0.54, 0.52, 0.7))
		btn.add_theme_stylebox_override("disabled", gray)
		btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.48, 0.45))
		btn.disabled = true
	prog_row.add_child(btn)
	return panel
