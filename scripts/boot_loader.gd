extends Control
## Écran de chargement — titre au-dessus, camion centré, barre en dessous.

const MAIN_SCENE := "res://scenes/main.tscn"
const LOGO_PATH := "res://assets/textures/ui/logo.png"
const TITLE_FONT_PATH := "res://assets/fonts/LilitaOne-Regular.ttf"
const GAME_TITLE := "Crops Express Idle"
const BG := Color(0.101961, 0.121569, 0.109804, 1.0)
const EXPECT_LOAD_SEC := 2.4
const BAR_W := 260.0
const BAR_H := 4.0
const STAGE_W := 340.0
const STAGE_H := 200.0
const DUST_BACK := Vector2(0.30, 0.78)
const DUST_FRONT := Vector2(0.62, 0.78)
const TITLE_GAP := 18.0
const FOOTER_GAP := 16.0

var _stage: Control
var _rig: Control
var _truck: TextureRect
var _dust_host: Control
var _title: Label
var _footer: VBoxContainer
var _bar_fill: ColorRect
var _pct_label: Label
var _dust_tex: Texture2D
var _t: float = 0.0
var _started_msec: int = 0
var _load_started: bool = false
var _switching: bool = false
var _scene_ready: bool = false
var _display_pct: float = 0.0
var _rig_base := Vector2.ZERO
var _finish_t: float = -1.0
var _packed: PackedScene = null
var _dust_cd: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_started_msec = Time.get_ticks_msec()
	_dust_tex = _make_dust_texture(48)
	_build_ui()
	ResourceLoader.load_threaded_request(MAIN_SCENE)
	_load_started = true
	resized.connect(_layout)
	call_deferred("_layout")


func _layout() -> void:
	if _stage == null:
		return
	_stage.position = (size - _stage.size) * 0.5
	if _title:
		_title.reset_size()
		_title.position = Vector2(
			(size.x - _title.size.x) * 0.5,
			_stage.position.y - _title.size.y - TITLE_GAP
		)
	if _footer:
		_footer.reset_size()
		_footer.position = Vector2(
			(size.x - _footer.size.x) * 0.5,
			_stage.position.y + _stage.size.y + FOOTER_GAP
		)


func _make_dust_texture(px: int) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var c := Vector2(px * 0.5, px * 0.5)
	var r := px * 0.5
	for y in px:
		for x in px:
			var d := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(c) / r
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * 0.55
			img.set_pixel(x, y, Color(0.78, 0.70, 0.55, a))
	return ImageTexture.create_from_image(img)


func _load_title_font() -> Font:
	if ResourceLoader.exists(TITLE_FONT_PATH):
		var f := load(TITLE_FONT_PATH)
		if f is Font:
			return f as Font
	# Fallback système arrondi / display
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Segoe UI Black", "Arial Black", "Impact", "Verdana"])
	sys.font_weight = 800
	return sys


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

	_title = Label.new()
	_title.text = GAME_TITLE
	_title.add_theme_font_override("font", _load_title_font())
	_title.add_theme_font_size_override("font_size", 48)
	_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.22, 1.0))
	_title.add_theme_color_override("font_outline_color", Color(0.18, 0.12, 0.04, 0.92))
	_title.add_theme_constant_override("outline_size", 8)
	_title.add_theme_color_override("font_shadow_color", Color(0.05, 0.08, 0.04, 0.45))
	_title.add_theme_constant_override("shadow_offset_x", 0)
	_title.add_theme_constant_override("shadow_offset_y", 4)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_title)

	_footer = VBoxContainer.new()
	_footer.alignment = BoxContainer.ALIGNMENT_CENTER
	_footer.add_theme_constant_override("separation", 6)
	_footer.custom_minimum_size = Vector2(BAR_W, 36.0)
	_footer.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_footer)

	var bar_wrap := ColorRect.new()
	bar_wrap.color = Color(1, 1, 1, 0.08)
	bar_wrap.custom_minimum_size = Vector2(BAR_W, BAR_H)
	bar_wrap.mouse_filter = MOUSE_FILTER_IGNORE
	_footer.add_child(bar_wrap)

	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.55, 0.72, 0.52, 1.0)
	_bar_fill.position = Vector2.ZERO
	_bar_fill.size = Vector2(2, BAR_H)
	_bar_fill.mouse_filter = MOUSE_FILTER_IGNORE
	bar_wrap.add_child(_bar_fill)

	_pct_label = Label.new()
	_pct_label.text = "0 %"
	_pct_label.add_theme_font_size_override("font_size", 12)
	_pct_label.add_theme_color_override("font_color", Color(0.70, 0.76, 0.64, 0.9))
	_pct_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pct_label.mouse_filter = MOUSE_FILTER_IGNORE
	_footer.add_child(_pct_label)

	_stage = Control.new()
	_stage.size = Vector2(STAGE_W, STAGE_H)
	_stage.custom_minimum_size = _stage.size
	_stage.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_stage)

	_dust_host = Control.new()
	_dust_host.size = _stage.size
	_dust_host.mouse_filter = MOUSE_FILTER_IGNORE
	_stage.add_child(_dust_host)

	_rig = Control.new()
	_rig.size = Vector2(STAGE_W, STAGE_H)
	_rig_base = Vector2.ZERO
	_rig.position = _rig_base
	_rig.mouse_filter = MOUSE_FILTER_IGNORE
	_stage.add_child(_rig)

	_truck = TextureRect.new()
	_truck.texture = load(LOGO_PATH) as Texture2D
	_truck.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_truck.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_truck.position = Vector2.ZERO
	_truck.size = Vector2(STAGE_W, STAGE_H)
	_truck.mouse_filter = MOUSE_FILTER_IGNORE
	_rig.add_child(_truck)


func _process(delta: float) -> void:
	_t += delta
	_animate_drive(delta)
	_spawn_dust(delta)
	_update_progress(delta)
	if _finish_t >= 0.0 and not _switching:
		_try_finish(delta)


func _animate_drive(_delta: float) -> void:
	if _rig == null:
		return
	var bounce := absf(sin(_t * 8.4)) * 1.6
	var sway := sin(_t * 2.1) * 0.006
	_rig.position = _rig_base + Vector2(0.0, -bounce)
	_rig.rotation = sway


func _spawn_dust(delta: float) -> void:
	_dust_cd -= delta
	if _dust_cd > 0.0 or _dust_host == null or _dust_tex == null:
		return
	_dust_cd = 0.085

	var from_front := randf() > 0.45
	var rel := DUST_FRONT if from_front else DUST_BACK
	var origin := Vector2(STAGE_W * rel.x, STAGE_H * rel.y) + _rig.position

	var puff := TextureRect.new()
	puff.texture = _dust_tex
	puff.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	puff.stretch_mode = TextureRect.STRETCH_SCALE
	var s := 18.0 + randf() * 16.0
	puff.size = Vector2(s, s * 0.7)
	puff.position = origin + Vector2(-6.0 + randf() * 8.0, -2.0 + randf() * 4.0) - puff.size * 0.5
	puff.modulate = Color(1, 1, 1, 0.0)
	puff.mouse_filter = MOUSE_FILTER_IGNORE
	_dust_host.add_child(puff)

	var life := 0.55 + randf() * 0.35
	var drift := Vector2(-28.0 - randf() * 36.0, -6.0 - randf() * 10.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(puff, "modulate:a", 0.5, life * 0.15)
	tw.tween_property(puff, "position", puff.position + drift, life).set_ease(Tween.EASE_OUT)
	tw.tween_property(puff, "scale", Vector2(1.45, 1.3), life).set_ease(Tween.EASE_OUT)
	tw.chain()
	tw.tween_property(puff, "modulate:a", 0.0, life * 0.4)
	tw.tween_callback(puff.queue_free)


func _target_pct(engine_pct: float, loaded: bool) -> float:
	if loaded:
		return 1.0
	var elapsed := (Time.get_ticks_msec() - _started_msec) / 1000.0
	var time_pct := (1.0 - exp(-elapsed / (EXPECT_LOAD_SEC * 0.55))) * 0.90
	var eng := clampf(engine_pct, 0.0, 0.92)
	return maxf(time_pct, eng)


func _update_progress(delta: float) -> void:
	if not _load_started or _switching:
		return

	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(MAIN_SCENE, progress)
	var engine_pct := 0.0
	if progress.size() > 0:
		engine_pct = float(progress[0])

	if status == ResourceLoader.THREAD_LOAD_FAILED:
		_switching = true
		push_error("BootLoader: échec chargement main.tscn")
		get_tree().change_scene_to_file(MAIN_SCENE)
		return

	if status == ResourceLoader.THREAD_LOAD_LOADED and not _scene_ready:
		_scene_ready = true
		_packed = ResourceLoader.load_threaded_get(MAIN_SCENE)
		_finish_t = 0.0

	var target := _target_pct(engine_pct, _scene_ready)
	var speed := 2.8 if not _scene_ready else 5.5
	_display_pct = move_toward(_display_pct, target, delta * speed)

	if _bar_fill:
		_bar_fill.size.x = maxf(2.0, _display_pct * BAR_W)
	if _pct_label:
		_pct_label.text = "%d %%" % int(round(_display_pct * 100.0))


func _try_finish(delta: float) -> void:
	_finish_t += delta
	if _display_pct < 0.995 and _finish_t < 1.2:
		return
	_switching = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.22).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		if _packed:
			get_tree().change_scene_to_packed(_packed)
		else:
			get_tree().change_scene_to_file(MAIN_SCENE)
	)
