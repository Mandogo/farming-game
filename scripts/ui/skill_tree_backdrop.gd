extends Control
## Fond sombre élégant pour l'arbre de compétences (UI, pas d'illustration d'arbre).

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 8.0 or h < 8.0:
		return

	## Base nuit mousse
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.14, 0.12, 1.0), true)

	## Dégradé vertical doux (plus clair vers le haut = « canopée »)
	for i in range(12):
		var t := float(i) / 12.0
		var y0 := t * h
		var col := Color(0.12, 0.18, 0.15, 0.55).lerp(Color(0.08, 0.11, 0.10, 0.0), t)
		draw_rect(Rect2(0.0, y0, w, h / 12.0 + 2.0), col, true)

	## Vignette
	var hub := Vector2(w * 0.5, h * 0.72)
	for i in range(8):
		var t := float(i) / 8.0
		var r := lerpf(maxf(w, h) * 0.15, maxf(w, h) * 0.85, t)
		draw_circle(hub, r, Color(0.04, 0.06, 0.05, 0.04 + t * 0.03))

	## Lueur centrale douce (sous le tronc)
	draw_circle(Vector2(w * 0.5, h * 0.78), 120.0, Color(0.28, 0.42, 0.28, 0.10))
	draw_circle(Vector2(w * 0.5, h * 0.78), 60.0, Color(0.40, 0.55, 0.32, 0.08))

	## Guides horizontaux discrets (niveaux)
	for gy in [0.22, 0.38, 0.54, 0.70]:
		var y := h * gy
		draw_line(Vector2(40, y), Vector2(w - 40, y), Color(0.35, 0.48, 0.38, 0.08), 1.5, true)

	## Piste verticale centrale (tronc hint)
	draw_line(
		Vector2(w * 0.5, h * 0.18),
		Vector2(w * 0.5, h * 0.88),
		Color(0.32, 0.45, 0.34, 0.10),
		18.0,
		true
	)
