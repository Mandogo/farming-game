class_name PlotTile
extends Control

signal action_requested(index: int)

const IsoBlockBuilderScript = preload("res://scripts/iso_block_builder.gd")
const ReadyAuraScript = preload("res://scripts/ready_aura.gd")

@onready var soil: TextureRect = %Soil
@onready var crop: TextureRect = %Crop
@onready var status: Label = %Status
@onready var hover_hint: HBoxContainer = %HoverHint
@onready var hover_icon: TextureRect = %HoverIcon
@onready var hover_label: Label = %HoverLabel

var index: int = 0
var _textures: Dictionary = {}
var _plot_cache: Dictionary = {}
var _progress_cache: float = 0.0
var _ready_aura: Control
var _base_modulate: Color = Color.WHITE
var _ready_pulse: bool = false
var _soil_key: String = "soil_a"
var _bold_font: Font
var _bold_applied: bool = false
var _hover_tw: Tween
var _shake_tw: Tween
var _click_crop_tw: Tween
var _status_flash_tw: Tween
var _is_hovered: bool = false
var _shake_t: float = 0.0
var _shake_dur: float = 0.0


func _ensure_bold_status() -> void:
	if status == null:
		return
	if _bold_font == null:
		_bold_font = SystemFont.new()
		(_bold_font as SystemFont).font_weight = 700
	if not _bold_applied:
		status.add_theme_font_override("font", _bold_font)
		_bold_applied = true


func setup(p_index: int, textures: Dictionary) -> void:
	index = p_index
	_textures = textures
	# Variantes de terre pour casser la répétition (style tuiles plateforme)
	var soil_keys := ["soil_a", "soil_b", "soil_c"]
	_soil_key = soil_keys[p_index % soil_keys.size()]
	if not _textures.has(_soil_key) or _textures[_soil_key] == null:
		_soil_key = "soil_a"
	# IGNORE : le picking iso est centralisé dans main (évite mauvais clic gauche/droite)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	custom_minimum_size = Vector2(104, 182)
	size = Vector2(104, 182)
	if soil:
		soil.position = Vector2.ZERO
		soil.size = Vector2(104, 182)
		soil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		soil.stretch_mode = TextureRect.STRETCH_SCALE
		soil.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		soil.modulate = Color(1, 1, 1, 1)
		soil.z_index = 0
	if crop:
		crop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		crop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		crop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		crop.z_index = 2
		_layout_crop()
	if hover_hint:
		hover_hint.visible = false
	_ensure_ready_aura()


func _layout_crop(pulse_y: float = 0.0) -> void:
	## Contrat sprites (process_crop_stages.py) : pieds = bord bas de la texture,
	## contenu centré en X. On place ce bord bas sur le centre du losange de terre.
	if crop == null:
		return
	var ch_canvas := float(IsoBlockBuilderScript.CANVAS_H)
	var top_h := float(IsoBlockBuilderScript.TOP_H)
	var depth := float(IsoBlockBuilderScript.DEPTH_FALLBACK)
	var oy := ch_canvas - top_h - depth - 8.0
	## Centre exact du losange (même formule que _has_point).
	var dirt_cx := size.x * 0.5
	var dirt_cy := size.y * (oy + top_h * 0.5) / ch_canvas
	## Taille intermédiaire (entre trop petit et trop gros).
	var max_w := size.x * 0.78
	var max_h := size.y * 0.48
	var cw := max_w
	var ch := max_h
	if crop.texture != null:
		var ts := crop.texture.get_size()
		if ts.x > 0.0 and ts.y > 0.0:
			var s := minf(max_w / ts.x, max_h / ts.y)
			cw = ts.x * s
			ch = ts.y * s
	crop.size = Vector2(cw, ch)
	## +2 px pour enfoncer légèrement les pieds dans la terre (visuel planté).
	var foot_sink := 2.0
	crop.position = Vector2(dirt_cx - cw * 0.5, dirt_cy - ch + foot_sink + pulse_y)
	crop.stretch_mode = TextureRect.STRETCH_SCALE


func _ensure_ready_aura() -> void:
	if _ready_aura != null:
		return
	_ready_aura = ReadyAuraScript.new() as Control
	_ready_aura.name = "ReadyAura"
	_ready_aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sur le losange de terre (dessus du bloc iso)
	_ready_aura.position = Vector2(6, 96)
	_ready_aura.size = Vector2(92, 48)
	_ready_aura.z_index = 1
	_ready_aura.visible = false
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_ready_aura.material = mat
	add_child(_ready_aura)
	if soil:
		move_child(_ready_aura, soil.get_index() + 1)


func _has_point(point: Vector2) -> bool:
	## Hitbox stricte = losange du dessus uniquement (pas les faces trop larges).
	## Évite qu'un clic à droite active la parcelle de gauche qui chevauche en rectangle.
	if size.x < 1.0 or size.y < 1.0:
		return false
	var tw := float(IsoBlockBuilderScript.TILE_W)
	var ch := float(IsoBlockBuilderScript.CANVAS_H)
	var top_h := float(IsoBlockBuilderScript.TOP_H)
	var depth := float(IsoBlockBuilderScript.DEPTH_FALLBACK)
	var sx := point.x / size.x * tw
	var sy := point.y / size.y * ch
	var oy := ch - top_h - depth - 8.0
	var cx := tw * 0.5
	var half_w := tw * 0.5
	var half_h := top_h * 0.5
	var cy := oy + half_h

	var dx := absf(sx - cx) / maxf(half_w, 0.001)
	var dy := absf(sy - cy) / maxf(half_h, 0.001)
	# Légèrement < 1 pour limiter le chevauchement entre voisins iso
	if dx + dy <= 0.98:
		return true

	# Petite zone faces (étroite) juste sous le losange — pour cliquer le "bloc"
	var south_y := oy + top_h
	if sy < south_y or sy > south_y + depth * 0.55:
		return false
	var t := (sy - south_y) / maxf(depth * 0.55, 0.001)
	var max_x := half_w * (0.72 - 0.35 * t)
	return absf(sx - cx) <= max_x


func contains_global_mouse() -> bool:
	return _has_point(get_local_mouse_position())


func _gui_input(_event: InputEvent) -> void:
	# Picking géré par main._pick_plot_at_mouse
	pass


func set_hovered(hovered: bool) -> void:
	## Léger "pop" du bloc de terre au survol.
	_is_hovered = hovered
	if _hover_tw != null and is_instance_valid(_hover_tw):
		_hover_tw.kill()
		_hover_tw = null
	pivot_offset = size * 0.5
	var target := _rest_scale()
	if hovered:
		if _plot_cache.get("unlocked", true) and absf(scale.x - target.x) > 0.01:
			_hover_tw = create_tween()
			_hover_tw.tween_property(self, "scale", target, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		if scale.x > 1.01:
			_hover_tw = create_tween()
			_hover_tw.tween_property(self, "scale", Vector2.ONE, 0.1)


func _rest_scale() -> Vector2:
	if _is_hovered and _plot_cache.get("unlocked", true):
		return Vector2(1.05, 1.05)
	return Vector2.ONE


func _process(delta: float) -> void:
	if _shake_t <= 0.0:
		return
	_shake_t = maxf(0.0, _shake_t - delta)
	var p := _shake_t / maxf(_shake_dur, 0.001)  # 1 → 0
	var elapsed := _shake_dur - _shake_t

	# Vibration légère sur sol + culture seulement (le % status reste fixe).
	var amp := 4.0 * p
	var off := Vector2(
		sin(elapsed * 88.0) * amp,
		cos(elapsed * 74.0) * amp * 0.5
	)
	var rot := sin(elapsed * 90.0) * 0.028 * p

	# Squash local léger (le zoom hover reste sur le PlotTile parent).
	var squash_y := 1.0
	if elapsed < 0.07:
		squash_y = lerpf(1.0, 0.90, elapsed / 0.07)
	elif elapsed < 0.15:
		squash_y = lerpf(0.90, 1.04, (elapsed - 0.07) / 0.08)
	else:
		squash_y = lerpf(1.04, 1.0, clampf((elapsed - 0.15) / 0.15, 0.0, 1.0))
	var squash_x := 1.0 + (1.0 - squash_y) * 0.55
	var local_scale := Vector2(squash_x, squash_y)

	if soil:
		soil.pivot_offset = Vector2(soil.size.x * 0.5, soil.size.y * 0.78)
		soil.position = off
		soil.rotation = rot
		soil.scale = local_scale
		# Assombrissement très léger (lisible, pas trop foncé).
		var flash := clampf(p * 1.1, 0.0, 1.0)
		soil.modulate = Color.WHITE.lerp(Color(0.88, 0.80, 0.68, 1.0), flash * 0.45)
	if crop:
		_layout_crop()
		crop.pivot_offset = Vector2(crop.size.x * 0.5, crop.size.y * 0.78)
		crop.position += off
		crop.rotation = rot
		crop.scale = local_scale
	if _ready_aura:
		_ready_aura.position = Vector2(6, 96) + off

	if _shake_t <= 0.0:
		_finish_soil_shake()


func _finish_soil_shake() -> void:
	if is_instance_valid(soil):
		soil.position = Vector2.ZERO
		soil.rotation = 0.0
		soil.scale = Vector2.ONE
		soil.pivot_offset = Vector2.ZERO
		soil.modulate = Color.WHITE
	if is_instance_valid(crop):
		crop.rotation = 0.0
		crop.scale = Vector2.ONE
		_layout_crop()
		crop.pivot_offset = crop.size * 0.5
	if _ready_aura:
		_ready_aura.position = Vector2(6, 96)
	set_meta("_soil_shake", false)
	set_process(false)


func _notification(what: int) -> void:
	pass


func _update_hover_hint(_show_hint: bool) -> void:
	if hover_hint:
		hover_hint.visible = false


func refresh(plot: Dictionary, progress: float, pulse_t: float = 0.0) -> void:
	if soil == null:
		return

	_plot_cache = plot
	_progress_cache = progress
	_ensure_ready_aura()
	# Pendant la secousse, garder le pivot bas (squash terre) — ne pas le resetter.
	if not bool(get_meta("_soil_shake", false)):
		pivot_offset = size * 0.5

	if not plot["unlocked"]:
		soil.texture = _textures.get(_soil_key)
		soil.modulate = Color(0.75, 0.76, 0.78, 0.85)
		crop.texture = null
		status.text = ""
		_base_modulate = Color.WHITE
		modulate = _base_modulate
		_ready_pulse = false
		if _ready_aura:
			_ready_aura.call("set_active", false)
		if hover_hint:
			hover_hint.visible = false
		return

	_base_modulate = Color.WHITE
	if not bool(get_meta("_soil_shake", false)):
		modulate = _base_modulate
	soil.texture = _textures.get(_soil_key)
	if not bool(get_meta("_soil_shake", false)):
		soil.modulate = Color.WHITE
		soil.position = Vector2.ZERO
		soil.scale = Vector2.ONE

	if plot["crop"] == null:
		crop.texture = null
		_layout_crop()
		crop.scale = Vector2.ONE
		status.text = ""
		_ready_pulse = false
		if _ready_aura:
			_ready_aura.call("set_active", false)
		if hover_hint:
			hover_hint.visible = false
		return

	var crop_data: CropData = plot["crop"]
	var stage := 1
	if plot["ready"]:
		stage = 6
	else:
		# Stages 1–5 pendant la pousse ; le 6 (adulte) uniquement une fois prêt.
		stage = clampi(int(floor(progress * 4.999)) + 1, 1, 5)

	var key := "%s_%d" % [String(crop_data.id), stage]
	crop.texture = _textures.get(key)

	if plot["ready"]:
		status.text = "Prêt !"
		status.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		status.modulate = Color.WHITE
		status.add_theme_font_size_override("font_size", 16)
		_ensure_bold_status()
		if not bool(get_meta("_status_flash", false)):
			status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
			status.add_theme_constant_override("outline_size", 3)
		_ready_pulse = true
		if _ready_aura:
			_ready_aura.call("set_active", true)
		if not bool(get_meta("_click_fx", false)) and not bool(get_meta("_soil_shake", false)):
			crop.modulate = Color(1.04, 1.02, 0.95, 1.0)
		var pulse_y := 0.0
		if not bool(get_meta("_soil_shake", false)):
			pulse_y = -1.0 * absf(sin(pulse_t * 2.8))
		if not bool(get_meta("_soil_shake", false)):
			_layout_crop(pulse_y)
	else:
		var secs_left := GameState.plot_remaining_seconds(index)
		status.text = "%d%% (%.0fs)" % [int(progress * 100.0), secs_left]
		# Rempli blanc ; le contour peut être vert pendant le flash accélération.
		status.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		status.modulate = Color.WHITE
		status.add_theme_font_size_override("font_size", 13)
		_ensure_bold_status()
		if not bool(get_meta("_status_flash", false)):
			status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
			status.add_theme_constant_override("outline_size", 3)
		_ready_pulse = false
		if _ready_aura:
			_ready_aura.call("set_active", false)
		# Ne pas écraser un flash / secousse de clic en cours
		if not bool(get_meta("_click_fx", false)) and not bool(get_meta("_soil_shake", false)):
			crop.modulate = Color.WHITE
		if not bool(get_meta("_soil_shake", false)):
			_layout_crop()


func play_click_boost_fx(seconds_gained: float = 0.0, show_float: bool = true) -> void:
	## Feedback visuel : le clic accélère vraiment la pousse + léger mouvement de terre.
	if crop == null:
		return
	set_meta("_click_fx", true)
	if _click_crop_tw != null and is_instance_valid(_click_crop_tw):
		_click_crop_tw.kill()
	crop.pivot_offset = crop.size * 0.5
	_click_crop_tw = create_tween()
	_click_crop_tw.set_parallel(true)
	_click_crop_tw.tween_property(crop, "scale", Vector2(1.10, 0.90), 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_click_crop_tw.tween_property(crop, "modulate", Color(0.80, 1.12, 0.72, 1.0), 0.05)
	_click_crop_tw.chain().set_parallel(true)
	_click_crop_tw.tween_property(crop, "scale", Vector2(0.97, 1.06), 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_click_crop_tw.tween_property(crop, "modulate", Color(1.08, 1.15, 0.88, 1.0), 0.07)
	_click_crop_tw.chain().set_parallel(true)
	_click_crop_tw.tween_property(crop, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_click_crop_tw.tween_property(crop, "modulate", Color.WHITE, 0.10)
	_click_crop_tw.chain().tween_callback(func():
		set_meta("_click_fx", false)
	)

	_play_soil_click_shake()
	_flash_status_accel()

	if not show_float:
		return
	# Affiche le temps réellement ajouté par CE clic (pas un cumul).
	var gained := maxf(0.0, seconds_gained)
	if gained < 0.05:
		return
	var popup := Label.new()
	popup.text = "-%.1fs" % gained
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.z_index = 40
	popup.top_level = true
	popup.add_theme_font_size_override("font_size", 13)
	popup.add_theme_color_override("font_color", Color(0.55, 1.0, 0.45, 1.0))
	popup.add_theme_color_override("font_outline_color", Color(0.05, 0.18, 0.08, 0.95))
	popup.add_theme_constant_override("outline_size", 3)
	add_child(popup)
	var rect := crop.get_global_rect()
	# Léger décalage aléatoire pour empiler visuellement les clics successifs
	var jitter := Vector2(randf_range(-10.0, 12.0), randf_range(-4.0, 4.0))
	var anchor := rect.position + Vector2(rect.size.x * 0.55, rect.size.y * 0.28) + jitter
	popup.global_position = anchor
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(popup, "global_position", anchor + Vector2(4, -24), 0.45).set_ease(Tween.EASE_OUT)
	tw2.tween_property(popup, "modulate:a", 0.0, 0.45).set_delay(0.12)
	tw2.chain().tween_callback(popup.queue_free)


func _flash_status_accel() -> void:
	## Contour vert rapide sur le % / chrono — rempli blanc pour rester lisible.
	if status == null:
		return
	if _status_flash_tw != null and is_instance_valid(_status_flash_tw):
		_status_flash_tw.kill()
		_status_flash_tw = null
	set_meta("_status_flash", true)
	status.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	status.add_theme_color_override("font_outline_color", Color(0.20, 0.95, 0.38, 1.0))
	status.add_theme_constant_override("outline_size", 5)
	var green := Color(0.20, 0.95, 0.38, 1.0)
	var back := Color(0, 0, 0, 0.75)
	_status_flash_tw = create_tween()
	_status_flash_tw.tween_interval(0.10)
	_status_flash_tw.tween_method(_set_status_outline_color, green, back, 0.18)
	_status_flash_tw.tween_callback(_end_status_accel_flash.bind(back))


func _set_status_outline_color(c: Color) -> void:
	if is_instance_valid(status):
		status.add_theme_color_override("font_outline_color", c)


func _end_status_accel_flash(back: Color) -> void:
	if is_instance_valid(status):
		status.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		status.add_theme_color_override("font_outline_color", back)
		status.add_theme_constant_override("outline_size", 3)
	set_meta("_status_flash", false)
	_status_flash_tw = null


func _play_soil_click_shake() -> void:
	## SOIL_CLICK_SHAKE_V7 — vibre sol+plante seulement (status % stable), effet plus doux.
	if _shake_tw != null and is_instance_valid(_shake_tw):
		_shake_tw.kill()
		_shake_tw = null

	# Reset local si on reclique pendant une secousse.
	if _shake_t > 0.0:
		_shake_t = 0.0
		if is_instance_valid(soil):
			soil.position = Vector2.ZERO
			soil.rotation = 0.0
			soil.scale = Vector2.ONE
		if is_instance_valid(crop):
			crop.rotation = 0.0
			crop.scale = Vector2.ONE
			_layout_crop()
		if _ready_aura:
			_ready_aura.position = Vector2(6, 96)

	set_meta("_soil_shake", true)
	_shake_dur = 0.28
	_shake_t = _shake_dur
	_spawn_dirt_specks()
	set_process(true)


func _spawn_dirt_specks() -> void:
	## Mottes plus larges qui jaillissent autour du plot.
	var origin := Vector2(size.x * 0.5, size.y * 0.56)
	for _i in 10:
		var speck := ColorRect.new()
		speck.mouse_filter = Control.MOUSE_FILTER_IGNORE
		speck.z_index = 55
		var s := randf_range(3.5, 7.0)
		speck.size = Vector2(s, s * randf_range(0.7, 1.3))
		var brown := Color(
			randf_range(0.38, 0.58),
			randf_range(0.24, 0.38),
			randf_range(0.12, 0.22),
			0.95
		)
		speck.color = brown
		speck.position = origin + Vector2(randf_range(-28.0, 28.0), randf_range(-8.0, 10.0))
		add_child(speck)
		var end := speck.position + Vector2(randf_range(-42.0, 42.0), randf_range(-48.0, -18.0))
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(speck, "position", end, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(speck, "modulate:a", 0.0, 0.38).set_delay(0.08)
		tw.tween_property(speck, "rotation", randf_range(-1.6, 1.6), 0.38)
		tw.chain().tween_callback(speck.queue_free)
