extends Control
## Parchemin scrollable : largeur calée, tuiles empilées en Y (qualité native × échelle largeur).

var parchment: Texture2D = null
## Chevauchement entre tuiles pour masquer les joints (px à l'échelle affichée).
var seam_overlap := 2.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func setup(tex: Texture2D) -> void:
	parchment = tex
	queue_redraw()


func _draw() -> void:
	if parchment == null:
		return
	var tw := float(parchment.get_width())
	var th := float(parchment.get_height())
	if tw < 2.0 or th < 2.0 or size.x < 2.0 or size.y < 2.0:
		return
	## Largeur = largeur du panneau ; hauteur d'une tuile selon le ratio source.
	var tile_h := size.x * (th / tw)
	if tile_h < 4.0:
		return
	var step := maxf(4.0, tile_h - seam_overlap)
	var y := 0.0
	## Découpe source pleine largeur (alpha déjà nettoyé) → empilement vertical.
	var src := Rect2(0.0, 0.0, tw, th)
	while y < size.y - 0.5:
		var dst := Rect2(0.0, y, size.x, tile_h)
		draw_texture_rect_region(parchment, dst, src, Color.WHITE, false)
		y += step
