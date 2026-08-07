extends Control
## Anneau segmenté autour d'un nœud (1 step = 1 niveau max).
## Ex. max 4 → 4 arcs ; niveau 1/4 → 1 arc rempli.

var steps: int = 1
var filled: int = 0
var track_color: Color = Color(0.28, 0.24, 0.18, 0.55)
var fill_color: Color = Color(0.42, 0.72, 0.92, 1.0)
var line_w: float = 9.0
## Écart angulaire entre segments (rad).
var gap_rad: float = 0.12


func _draw() -> void:
	var c := size * 0.5
	## Centre du trait à mi-épaisseur : bord interne colle au disque (size = disc + 2*line_w).
	var r := mini(size.x, size.y) * 0.5 - line_w * 0.5
	if r <= 1.0:
		return
	var n := maxi(steps, 1)
	var filled_n := clampi(filled, 0, n)
	var seg := TAU / float(n)
	var gap := mini(gap_rad, seg * 0.35)
	for i in n:
		var a0 := -PI * 0.5 + seg * float(i) + gap * 0.5
		var a1 := -PI * 0.5 + seg * float(i + 1) - gap * 0.5
		if a1 <= a0:
			continue
		var col := fill_color if i < filled_n else track_color
		var pts := maxi(10, int(22.0 * (a1 - a0) / seg))
		draw_arc(c, r, a0, a1, pts, col, line_w, true)
