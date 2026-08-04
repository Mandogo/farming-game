extends Control
## Halo au sol quand une culture est prête — anneaux iso + poussière dorée.

var active: bool = false
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func set_active(on: bool) -> void:
	active = on
	visible = on
	set_process(on)
	if on:
		queue_redraw()


func _process(delta: float) -> void:
	if not active:
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	if not active or size.x < 2.0:
		return

	var center := size * 0.5
	# Squash vertical pour un losange / ellipse au sol iso
	var squash := Vector2(1.0, 0.42)
	draw_set_transform(center, 0.0, squash)

	var breath := 0.88 + 0.12 * sin(_t * 2.6)
	var base_r := minf(size.x, size.y / squash.y) * 0.42 * breath

	# Glow central doux (plusieurs disques)
	for i in 4:
		var t := float(i) / 3.0
		var r := base_r * (0.35 + t * 0.75)
		var a := (1.0 - t) * (0.18 + 0.10 * absf(sin(_t * 2.6)))
		draw_circle(Vector2.ZERO, r, Color(1.0, 0.82, 0.28, a))

	# Anneaux qui s'expandent et fondent
	for k in 2:
		var phase := fposmod(_t * 0.55 + float(k) * 0.5, 1.0)
		var r := base_r * (0.45 + phase * 0.75)
		var a := (1.0 - phase) * 0.55
		_draw_ring(Vector2.ZERO, r, 2.2 - phase, Color(1.0, 0.9, 0.45, a))

	# Contour fixe subtil du plateau
	_draw_ring(Vector2.ZERO, base_r * 0.92, 1.6, Color(1.0, 0.95, 0.6, 0.28 + 0.12 * absf(sin(_t * 2.6))))

	# Petites poussieres lumineuses pres des racines
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in 5:
		var seed := float(i) * 1.7
		var life := fposmod(_t * 0.7 + seed * 0.37, 1.0)
		var ang := seed * 2.3 + _t * 0.9
		var rad := 10.0 + 16.0 * (1.0 - life)
		var px := center.x + cos(ang) * rad
		var py := center.y + sin(ang) * rad * 0.35 - life * 10.0
		var pa := (1.0 - life) * 0.75
		var pr := 1.2 + (1.0 - life) * 1.8
		draw_circle(Vector2(px, py), pr, Color(1.0, 0.95, 0.55, pa))


func _draw_ring(center: Vector2, radius: float, width: float, color: Color) -> void:
	## Anneau approxime par un arc dense de petits segments.
	if radius <= 0.5:
		return
	var steps := 28
	var pts: PackedVector2Array = PackedVector2Array()
	for i in steps + 1:
		var a := TAU * float(i) / float(steps)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	for i in steps:
		draw_line(pts[i], pts[i + 1], color, width, true)
