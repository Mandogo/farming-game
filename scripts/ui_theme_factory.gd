extends RefCounted
class_name UiThemeFactory
## Thème serre douce — sauge muted, pas de blanc cramé, texte net sans ombre.


static func build() -> Theme:
	var theme := Theme.new()

	# Palette : serre moss (adoucie, lisible, sans glare)
	var panel_bg := Color(0.78, 0.86, 0.80, 0.94)
	var panel_bg_soft := Color(0.72, 0.82, 0.74, 0.92)
	var panel_border := Color(0.38, 0.52, 0.42, 0.55)
	var accent_gold := Color(0.82, 0.64, 0.22, 1.0)
	var text := Color(0.14, 0.22, 0.16, 1.0)
	var text_muted := Color(0.36, 0.46, 0.38, 1.0)
	## Boutons modernes : vitre légère + ombre (plus de fond vert opaque).
	var btn_glass := Color(1.0, 1.0, 1.0, 0.22)
	var btn_glass_hover := Color(1.0, 1.0, 1.0, 0.38)
	var btn_glass_pressed := Color(1.0, 1.0, 1.0, 0.14)
	var btn_glass_disabled := Color(0.85, 0.88, 0.85, 0.12)
	var btn_border := Color(0.20, 0.28, 0.22, 0.10)
	var btn_shadow := Color(0.08, 0.12, 0.10, 0.28)

	theme.set_color("font_color", "Label", text)
	# Pas d'ombre / outline : évite le texte flou / "sale"
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	theme.set_constant("shadow_offset_x", "Label", 0)
	theme.set_constant("shadow_offset_y", "Label", 0)
	theme.set_constant("outline_size", "Label", 0)
	theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0))

	theme.set_stylebox("panel", "PanelContainer", _flat(panel_bg, panel_border, 14, 1, 12, 6, Vector2(0, 2)))
	theme.set_stylebox("panel", "Panel", _flat(panel_bg_soft, panel_border, 12, 1, 10, 5, Vector2(0, 2)))

	theme.set_stylebox("normal", "Button", _glass_btn(btn_glass, btn_border, btn_shadow, 10, 4, Vector2(0, 2)))
	theme.set_stylebox("hover", "Button", _glass_btn(btn_glass_hover, Color(0.25, 0.35, 0.28, 0.16), btn_shadow, 10, 5, Vector2(0, 2)))
	theme.set_stylebox("pressed", "Button", _glass_btn(btn_glass_pressed, btn_border, Color(0.08, 0.12, 0.10, 0.16), 10, 2, Vector2(0, 1)))
	theme.set_stylebox("disabled", "Button", _glass_btn(btn_glass_disabled, Color(0.40, 0.45, 0.40, 0.08), Color(0, 0, 0, 0), 10, 0, Vector2.ZERO))
	theme.set_stylebox("focus", "Button", _glass_btn(btn_glass_hover, accent_gold, btn_shadow, 10, 4, Vector2(0, 2)))
	theme.set_color("font_color", "Button", text)
	theme.set_color("font_hover_color", "Button", Color(0.10, 0.18, 0.12))
	theme.set_color("font_pressed_color", "Button", Color(0.18, 0.26, 0.20))
	theme.set_color("font_disabled_color", "Button", text_muted)
	theme.set_color("font_shadow_color", "Button", Color(0, 0, 0, 0))
	theme.set_constant("shadow_offset_x", "Button", 0)
	theme.set_constant("shadow_offset_y", "Button", 0)
	theme.set_constant("h_separation", "Button", 6)

	# Onglets : même langage vitre + ombre
	var tab_off := _chrome_tab(false, false)
	var tab_hover := _chrome_tab(false, true)
	var tab_on := _chrome_tab(true, false)
	var tab_locked := _chrome_tab(false, false, true)
	theme.set_stylebox("normal", "ButtonTab", tab_off)
	theme.set_stylebox("hover", "ButtonTab", tab_hover)
	theme.set_stylebox("pressed", "ButtonTab", tab_on)
	theme.set_stylebox("disabled", "ButtonTab", tab_locked)
	theme.set_stylebox("focus", "ButtonTab", tab_on)
	theme.set_color("font_color", "ButtonTab", text)
	theme.set_color("font_hover_color", "ButtonTab", text)
	theme.set_color("font_pressed_color", "ButtonTab", text)
	theme.set_color("font_disabled_color", "ButtonTab", text_muted)
	theme.set_constant("h_separation", "ButtonTab", 0)
	theme.set_constant("icon_max_width", "ButtonTab", 34)

	var strip := _flat(Color(1.0, 1.0, 1.0, 0.14), Color(0.20, 0.28, 0.22, 0.10), 10, 0, 2, 3, Vector2(0, 1))
	strip.shadow_color = Color(0.08, 0.12, 0.10, 0.20)
	theme.set_stylebox("panel", "TabStrip", strip)

	var bar_bg := _flat(Color(0.62, 0.72, 0.64, 0.95), Color(0.42, 0.55, 0.45, 0.4), 8, 1, 2, 1, Vector2(0, 1))
	var bar_fill := _flat(Color(0.38, 0.70, 0.44, 1.0), Color(0.55, 0.85, 0.50, 0.65), 8, 1, 2, 0, Vector2.ZERO)
	theme.set_stylebox("background", "ProgressBar", bar_bg)
	theme.set_stylebox("fill", "ProgressBar", bar_fill)
	theme.set_color("font_color", "ProgressBar", text)

	var chip := _flat(Color(0.88, 0.86, 0.72, 0.95), Color(0.72, 0.58, 0.24, 0.70), 12, 1, 10, 4, Vector2(0, 2))
	theme.set_stylebox("panel", "Chip", chip)

	var card := _flat(Color(0.82, 0.89, 0.83, 0.94), Color(0.42, 0.58, 0.46, 0.42), 12, 1, 8, 4, Vector2(0, 2))
	theme.set_stylebox("panel", "Card", card)

	var seed_card := _flat(Color(0.76, 0.85, 0.78, 0.96), Color(0.42, 0.60, 0.46, 0.50), 12, 1, 8, 4, Vector2(0, 2))
	theme.set_stylebox("panel", "SeedCard", seed_card)

	var inv_panel := _flat(Color(0.78, 0.86, 0.80, 0.96), Color(0.45, 0.65, 0.42, 0.50), 12, 1, 8, 4, Vector2(0, 2))
	theme.set_stylebox("panel", "InvPanel", inv_panel)

	var inv_slot := _flat(Color(0.68, 0.78, 0.70, 0.95), Color(0.45, 0.58, 0.48, 0.45), 8, 1, 4, 2, Vector2(0, 1))
	theme.set_stylebox("panel", "InvSlot", inv_slot)

	var keycap := _flat(Color(0.68, 0.78, 0.70, 0.98), Color(0.45, 0.62, 0.38, 0.80), 6, 1, 3, 1, Vector2(0, 1))
	theme.set_stylebox("panel", "Keycap", keycap)

	# Rush = corail doux
	var rush_card := _flat(Color(0.90, 0.82, 0.76, 0.96), Color(0.82, 0.42, 0.30, 0.80), 10, 2, 8, 4, Vector2(0, 2))
	rush_card.shadow_color = Color(0.55, 0.25, 0.15, 0.18)
	theme.set_stylebox("panel", "RushCard", rush_card)

	var rush_bar_bg := _flat(Color(0.82, 0.74, 0.70, 0.95), Color(0.72, 0.45, 0.35, 0.45), 8, 1, 2, 1, Vector2(0, 1))
	var rush_bar_fill := _flat(Color(0.88, 0.48, 0.32, 1.0), Color(0.95, 0.65, 0.42, 0.70), 8, 1, 2, 0, Vector2.ZERO)
	theme.set_stylebox("background", "RushProgressBar", rush_bar_bg)
	theme.set_stylebox("fill", "RushProgressBar", rush_bar_fill)

	# Cadre champ : prairie soft (plus de vitre blanche)
	var field_frame := _flat(Color(0.58, 0.72, 0.55, 0.72), Color(0.42, 0.52, 0.32, 0.50), 16, 2, 6, 8, Vector2(0, 3))
	field_frame.shadow_color = Color(0.15, 0.22, 0.14, 0.20)
	theme.set_stylebox("panel", "FieldFrame", field_frame)

	theme.set_stylebox("normal", "BtnCheck", _action_btn(Color(0.36, 0.70, 0.48, 0.55), Color(0.28, 0.55, 0.38), false))
	theme.set_stylebox("hover", "BtnCheck", _action_btn(Color(0.42, 0.78, 0.54, 0.72), Color(0.32, 0.62, 0.42), false))
	theme.set_stylebox("pressed", "BtnCheck", _action_btn(Color(0.28, 0.56, 0.38, 0.80), Color(0.22, 0.45, 0.30), true))
	theme.set_stylebox("disabled", "BtnCheck", _action_btn(Color(0.62, 0.68, 0.64, 0.35), Color(0.52, 0.56, 0.52), true))

	theme.set_stylebox("normal", "BtnCancel", _action_btn(Color(0.78, 0.42, 0.40, 0.50), Color(0.62, 0.32, 0.30), false))
	theme.set_stylebox("hover", "BtnCancel", _action_btn(Color(0.86, 0.48, 0.46, 0.68), Color(0.70, 0.36, 0.34), false))
	theme.set_stylebox("pressed", "BtnCancel", _action_btn(Color(0.64, 0.32, 0.30, 0.78), Color(0.50, 0.24, 0.22), true))
	theme.set_stylebox("disabled", "BtnCancel", _action_btn(Color(0.66, 0.60, 0.60, 0.32), Color(0.54, 0.50, 0.50), true))

	theme.set_color("font_color", "Hint", text_muted)

	return theme


static func _action_btn(bg: Color, border: Color, flat: bool = false) -> StyleBoxFlat:
	## Boutons commande : plat, sans bordure, intégré à la carte.
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(0)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(4)
	s.shadow_size = 0
	s.shadow_offset = Vector2.ZERO
	s.shadow_color = Color(0, 0, 0, 0)
	if flat:
		s.bg_color = Color(bg.r * 0.92, bg.g * 0.92, bg.b * 0.92, bg.a)
	return s


static func _glass_btn(
	bg: Color,
	border: Color,
	shadow: Color,
	radius: int = 10,
	shadow_size: int = 4,
	shadow_offset: Vector2 = Vector2(0, 2)
) -> StyleBoxFlat:
	## Bouton vitre : fond quasi transparent + ombre douce.
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(0 if border.a < 0.05 else 1)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(10)
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	s.shadow_color = shadow
	s.shadow_size = shadow_size
	s.shadow_offset = shadow_offset
	return s


static func _chrome_tab(selected: bool, hover: bool = false, locked: bool = false) -> StyleBoxFlat:
	## Onglet vitre + ombre (sélection un peu plus opaque).
	var s := StyleBoxFlat.new()
	if selected:
		s.bg_color = Color(1.0, 1.0, 1.0, 0.42)
		s.border_color = Color(0.72, 0.55, 0.18, 0.55)
		s.border_width_left = 0
		s.border_width_top = 0
		s.border_width_right = 0
		s.border_width_bottom = 2
		s.corner_radius_top_left = 10
		s.corner_radius_top_right = 10
		s.corner_radius_bottom_left = 0
		s.corner_radius_bottom_right = 0
		s.content_margin_left = 6
		s.content_margin_top = 6
		s.content_margin_right = 6
		s.content_margin_bottom = 6
		s.expand_margin_bottom = 2
		s.shadow_color = Color(0.08, 0.12, 0.10, 0.26)
		s.shadow_size = 4
		s.shadow_offset = Vector2(0, 2)
	elif locked:
		s.bg_color = Color(1.0, 1.0, 1.0, 0.08)
		s.border_color = Color(0.40, 0.42, 0.40, 0.12)
		s.set_border_width_all(0)
		s.set_corner_radius_all(8)
		s.set_content_margin_all(6)
		s.shadow_size = 0
		s.shadow_offset = Vector2.ZERO
		s.shadow_color = Color(0, 0, 0, 0)
	else:
		s.bg_color = Color(1.0, 1.0, 1.0, 0.16) if not hover else Color(1.0, 1.0, 1.0, 0.30)
		s.border_color = Color(0.20, 0.28, 0.22, 0.08)
		s.set_border_width_all(0)
		s.set_corner_radius_all(8)
		s.set_content_margin_all(6)
		s.expand_margin_bottom = 0
		s.shadow_color = Color(0.08, 0.12, 0.10, 0.22 if not hover else 0.28)
		s.shadow_size = 3 if not hover else 4
		s.shadow_offset = Vector2(0, 2)
	return s


static func _flat(
	bg: Color,
	border: Color,
	radius: int,
	border_w: int,
	content_margin: int,
	shadow_size: int = 4,
	shadow_offset: Vector2 = Vector2(0, 2)
) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(content_margin)
	s.shadow_color = Color(0.12, 0.18, 0.12, 0.16)
	s.shadow_size = shadow_size
	s.shadow_offset = shadow_offset
	return s
