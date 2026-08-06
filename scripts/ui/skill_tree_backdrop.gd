extends Control
## Fond atmosphérique « clairière / grand arbre » — palette serre moss.
## Soft wedges pour les 5 axes (inspiration PoE / talent trees idle).

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 8.0 or h < 8.0:
		return

	## Sol clairière — crème verdâtre (pas le gris sombre d'avant)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.86, 0.90, 0.78, 1.0), true)

	## Soft radial vignette (plus clair au centre)
	var hub := Vector2(w * 0.5, h * 0.5)
	for i in range(10):
		var t := float(i) / 10.0
		var r := lerpf(80.0, maxf(w, h) * 0.72, t)
		var a := 0.045 * (1.0 - t)
		draw_circle(hub, r, Color(0.72, 0.82, 0.58, a))

	## Canopée / feuillage haut
	_draw_canopy(w, h)

	## Anneaux de chemin (type idle talent map)
	for ring_r in [220.0, 420.0, 640.0, 860.0]:
		draw_arc(hub, ring_r, 0.0, TAU, 64, Color(0.55, 0.68, 0.42, 0.10), 2.0, true)

	## Pétales / secteurs colorés (5 axes écartés)
	var sectors := [
		{"ang": -PI * 0.5, "col": Color(0.92, 0.48, 0.20, 0.07)}, ## combo — haut
		{"ang": -PI * 0.5 + TAU / 5.0, "col": Color(0.32, 0.58, 0.92, 0.07)}, ## xp
		{"ang": -PI * 0.5 + 2.0 * TAU / 5.0, "col": Color(0.86, 0.68, 0.16, 0.07)}, ## money
		{"ang": -PI * 0.5 + 3.0 * TAU / 5.0, "col": Color(0.58, 0.48, 0.72, 0.07)}, ## atelier
		{"ang": -PI * 0.5 + 4.0 * TAU / 5.0, "col": Color(0.18, 0.68, 0.62, 0.07)}, ## orders
	]
	var half := TAU / 10.0 ## demi-ouverture ~36°
	var petal_len := mini(w, h) * 0.48
	for s in sectors:
		var a0: float = s["ang"] - half
		var a1: float = s["ang"] + half
		var pts := PackedVector2Array([hub])
		var steps := 10
		for i in range(steps + 1):
			var a := lerpf(a0, a1, float(i) / float(steps))
			pts.append(hub + Vector2.from_angle(a) * petal_len)
		draw_colored_polygon(pts, s["col"])
		## Nervure centrale du pétale
		var tip := hub + Vector2.from_angle(s["ang"]) * petal_len
		draw_line(hub, tip, Color(s["col"].r, s["col"].g, s["col"].b, 0.22), 14.0, true)

	## Tronc stylisé
	var trunk_top := hub + Vector2(0, -40)
	var trunk_bot := hub + Vector2(0, 120)
	draw_colored_polygon(
		PackedVector2Array([
			trunk_top + Vector2(-10, 0),
			trunk_top + Vector2(10, 0),
			trunk_bot + Vector2(16, 0),
			trunk_bot + Vector2(-16, 0),
		]),
		Color(0.50, 0.36, 0.22, 0.40)
	)
	## Racines
	for root in [
		Vector2(-110, 90), Vector2(110, 90), Vector2(-55, 120), Vector2(55, 120), Vector2(0, 140)
	]:
		draw_line(trunk_bot, hub + root, Color(0.50, 0.36, 0.22, 0.22), 5.0, true)

	## Lueur hub
	draw_circle(hub, 70.0, Color(0.95, 0.90, 0.50, 0.10))
	draw_circle(hub, 36.0, Color(0.55, 0.78, 0.45, 0.14))

	## Herbe / points décoratifs bas
	var rng_seed := 42
	for i in range(28):
		rng_seed = (rng_seed * 1103515245 + 12345) & 0x7fffffff
		var px := float(rng_seed % 1000) / 1000.0 * w
		rng_seed = (rng_seed * 1103515245 + 12345) & 0x7fffffff
		var py := h * 0.55 + float(rng_seed % 1000) / 1000.0 * h * 0.42
		draw_circle(Vector2(px, py), 3.0 + float(i % 4), Color(0.45, 0.62, 0.34, 0.10))


func _draw_canopy(w: float, h: float) -> void:
	var leaves := [
		Vector2(0.12, 0.08), Vector2(0.28, 0.04), Vector2(0.50, 0.02), Vector2(0.72, 0.05), Vector2(0.90, 0.10),
		Vector2(0.06, 0.22), Vector2(0.94, 0.24), Vector2(0.18, 0.18), Vector2(0.82, 0.16),
		Vector2(0.40, 0.10), Vector2(0.60, 0.12),
	]
	var cols := [
		Color(0.40, 0.66, 0.36, 0.18),
		Color(0.52, 0.74, 0.40, 0.14),
		Color(0.32, 0.56, 0.30, 0.16),
		Color(0.58, 0.78, 0.48, 0.10),
	]
	for i in range(leaves.size()):
		var p: Vector2 = leaves[i] * Vector2(w, h)
		var r := 70.0 + float((i * 41) % 80)
		draw_circle(p, r, cols[i % cols.size()])
		draw_circle(p + Vector2(r * 0.25, r * 0.15), r * 0.55, cols[(i + 1) % cols.size()])
