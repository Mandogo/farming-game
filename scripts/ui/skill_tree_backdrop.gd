extends Control
## Fond parchemin froissé / craquelé pour l'arbre de compétences.

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 8.0 or h < 8.0:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = 4173

	## Base parchemin (tons chauds papier)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.90, 0.83, 0.68, 1.0), true)

	## Zones d'ombre / relief (feuille pliée) — rectangles, pas de cercles
	for i in range(16):
		var rx := rng.randf() * w * 0.85
		var ry := rng.randf() * h * 0.85
		var rw := 40.0 + rng.randf() * 160.0
		var rh := 18.0 + rng.randf() * 70.0
		var shade := Color(0.52, 0.38, 0.22, 0.04 + rng.randf() * 0.05)
		draw_rect(Rect2(rx, ry, rw, rh), shade, true)
		draw_rect(Rect2(rx + 3.0, ry + 2.0, rw * 0.55, 3.0), Color(0.96, 0.91, 0.78, 0.07), true)

	## Bandes de plis horizontales (froissage)
	for i in range(12):
		var t := float(i) / 12.0
		var y0 := t * h + rng.randf_range(-18.0, 18.0)
		var fold := Color(0.55, 0.40, 0.24, 0.06 + (i % 2) * 0.03)
		var fold_hi := Color(0.97, 0.93, 0.82, 0.08)
		draw_rect(Rect2(0.0, y0, w, 8.0 + rng.randf() * 22.0), fold, true)
		draw_rect(Rect2(0.0, y0 + 1.0, w, 2.5), fold_hi, true)

	## Plis diagonaux plus marqués
	for _k in range(22):
		var x0 := rng.randf() * w
		var y0 := rng.randf() * h
		var len := 90.0 + rng.randf() * 260.0
		var ang := rng.randf_range(-1.1, 1.1)
		var c := Color(0.46, 0.34, 0.20, 0.07 + rng.randf() * 0.06)
		draw_line(Vector2(x0, y0), Vector2(x0 + cos(ang) * len, y0 + sin(ang) * len), c, 2.5 + rng.randf() * 4.0, true)
		## Contre-pli clair
		draw_line(
			Vector2(x0 + 2.0, y0 + 1.0),
			Vector2(x0 + cos(ang) * len * 0.7, y0 + sin(ang) * len * 0.7),
			Color(0.95, 0.90, 0.78, 0.05),
			1.5,
			true
		)

	## Fibres / grain papier
	for _i in range(380):
		var px := rng.randf() * w
		var py := rng.randf() * h
		var len := 5.0 + rng.randf() * 28.0
		var a := rng.randf_range(-0.55, 0.55)
		var c := Color(0.50, 0.38, 0.22, 0.035 + rng.randf() * 0.045)
		draw_line(Vector2(px, py), Vector2(px + cos(a) * len, py + sin(a) * len), c, 1.0, true)

	## Craquelures (réseau de fissures visibles)
	for _c in range(42):
		var sx := rng.randf() * w
		var sy := rng.randf() * h
		var pts := PackedVector2Array()
		pts.append(Vector2(sx, sy))
		var ang := rng.randf() * TAU
		var segs := 4 + rng.randi() % 5
		for _s in range(segs):
			ang += rng.randf_range(-0.85, 0.85)
			var step := 14.0 + rng.randf() * 48.0
			sx += cos(ang) * step
			sy += sin(ang) * step
			pts.append(Vector2(sx, sy))
			## Bifurcation occasionnelle
			if rng.randf() < 0.35:
				var bx := sx + cos(ang + 0.9) * (10.0 + rng.randf() * 22.0)
				var by := sy + sin(ang + 0.9) * (10.0 + rng.randf() * 22.0)
				draw_line(Vector2(sx, sy), Vector2(bx, by), Color(0.38, 0.26, 0.14, 0.14), 1.0, true)
		for i in range(pts.size() - 1):
			var a := 0.12 + rng.randf() * 0.10
			draw_line(pts[i], pts[i + 1], Color(0.38, 0.26, 0.14, a), 1.15, true)

	## Taches d'usure (rectangulaires / allongées, pas rondes)
	for _t in range(18):
		var tx := rng.randf() * w
		var ty := rng.randf() * h
		var tw := 8.0 + rng.randf() * 36.0
		var th := 3.0 + rng.randf() * 10.0
		draw_rect(Rect2(tx, ty, tw, th), Color(0.48, 0.34, 0.18, 0.05 + rng.randf() * 0.06), true)

	## Bords usés / brûlés
	for i in range(10):
		var t := float(i) / 10.0
		var a := 0.18 * (1.0 - t)
		var ec := Color(0.38, 0.26, 0.14, a)
		draw_rect(Rect2(0.0, 0.0, w, 10.0 + t * 28.0), ec, true)
		draw_rect(Rect2(0.0, h - (10.0 + t * 28.0), w, 10.0 + t * 28.0), ec, true)
		draw_rect(Rect2(0.0, 0.0, 8.0 + t * 20.0, h), ec, true)
		draw_rect(Rect2(w - (8.0 + t * 20.0), 0.0, 8.0 + t * 20.0, h), ec, true)

	## Contour froissé (hachures bord)
	for i in range(int(w / 14.0)):
		var x := float(i) * 14.0 + rng.randf_range(-5.0, 5.0)
		var dy := rng.randf_range(3.0, 14.0)
		draw_line(Vector2(x, 0.0), Vector2(x + 7.0, dy), Color(0.42, 0.28, 0.14, 0.16), 1.4, true)
		draw_line(Vector2(x, h), Vector2(x + 7.0, h - dy), Color(0.42, 0.28, 0.14, 0.16), 1.4, true)
	for i in range(int(h / 16.0)):
		var y := float(i) * 16.0 + rng.randf_range(-4.0, 4.0)
		var dx := rng.randf_range(3.0, 12.0)
		draw_line(Vector2(0.0, y), Vector2(dx, y + 5.0), Color(0.42, 0.28, 0.14, 0.12), 1.2, true)
		draw_line(Vector2(w, y), Vector2(w - dx, y + 5.0), Color(0.42, 0.28, 0.14, 0.12), 1.2, true)
