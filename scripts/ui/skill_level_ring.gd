extends Control
## Anneau de progression autour d'un nœud de compétence (niv / max).

var ratio: float = 0.0
var track_color: Color = Color(0.35, 0.32, 0.28, 0.45)
var fill_color: Color = Color(0.55, 0.78, 0.48, 1.0)
var line_w: float = 3.5


func _draw() -> void:
	var c := size * 0.5
	var r := mini(size.x, size.y) * 0.5 - line_w * 0.5
	if r <= 1.0:
		return
	draw_arc(c, r, 0.0, TAU, 48, track_color, line_w, true)
	var t := clampf(ratio, 0.0, 1.0)
	if t <= 0.001:
		return
	## Départ en haut (−PI/2), sens horaire.
	draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * t, 48, fill_color, line_w, true)
