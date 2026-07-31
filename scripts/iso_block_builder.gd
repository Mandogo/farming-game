extends RefCounted
class_name IsoBlockBuilder
## Assemble un bloc iso 2:1 à partir de 2 PNG : top + side (même face sur tous les côtés).
## Formats attendus : top 256×256, side 256×170 (autres tailles OK).

const TILE_W := 160
const TOP_H := 80
const CANVAS_H := 280
## Hauteur des faces dérivée du ratio side (256×170 → ~53 px)
const DEPTH_FALLBACK := 53


static func build_block_dir(block_dir: String) -> ImageTexture:
	var top_p := "%s/top.png" % block_dir
	var side_p := "%s/side.png" % block_dir
	var top := _load_image(top_p)
	var side := _load_image(side_p)
	if top == null or side == null:
		push_warning("IsoBlockBuilder: besoin de top.png + side.png dans %s" % block_dir)
		return null
	return build(top, side)


static func build(top: Image, side: Image) -> ImageTexture:
	var depth := DEPTH_FALLBACK
	if side.get_width() > 0:
		depth = clampi(int(round(float(TILE_W / 2) * float(side.get_height()) / float(side.get_width()))), 24, 80)

	var out := Image.create(TILE_W, CANVAS_H, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))

	var oy := CANVAS_H - TOP_H - depth - 8
	var cx := TILE_W / 2
	var top_e := Vector2i(cx + TILE_W / 2 - 1, oy + TOP_H / 2)
	var top_s := Vector2i(cx, oy + TOP_H - 1)
	var top_w := Vector2i(cx - TILE_W / 2, oy + TOP_H / 2)

	_fill_parallelogram(
		out, top_w, top_s,
		Vector2i(top_s.x, top_s.y + depth), Vector2i(top_w.x, top_w.y + depth),
		side
	)
	_fill_parallelogram(
		out, top_e, top_s,
		Vector2i(top_s.x, top_s.y + depth), Vector2i(top_e.x, top_e.y + depth),
		side
	)
	_fill_top(out, oy, top)
	# Contours style tuile plateforme : sépare clairement les blocs voisins
	_stroke_block_edges(out, oy, depth)
	_soft_top_light(out, oy)
	return ImageTexture.create_from_image(out)


static func _load_image(path: String) -> Image:
	var img: Image = null
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Image:
			img = (res as Image).duplicate()
		elif res is Texture2D:
			img = (res as Texture2D).get_image()
			if img != null and img.is_compressed():
				img.decompress()
	# Fallback : PNG frais pas encore importé par Godot
	if img == null:
		img = Image.new()
		var abs_path := ProjectSettings.globalize_path(path)
		if img.load(abs_path) != OK:
			push_warning("IsoBlockBuilder: impossible de charger %s" % path)
			return null
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


static func _in_diamond(x: int, y: int, oy: int) -> bool:
	var dy := y - oy
	if dy < 0 or dy >= TOP_H:
		return false
	var half_h := TOP_H / 2
	var max_span: int
	if dy <= half_h:
		max_span = int(round((TILE_W / 2.0) * (float(dy) / float(maxi(half_h, 1)))))
	else:
		max_span = int(round((TILE_W / 2.0) * (float(TOP_H - 1 - dy) / float(maxi(half_h, 1)))))
	return absi(x - TILE_W / 2) <= max_span


static func _fill_top(out: Image, oy: int, top: Image) -> void:
	var tw := top.get_width()
	var th := top.get_height()
	var cx := float(TILE_W) / 2.0
	var half_w := float(TILE_W) / 2.0
	var half_h := float(TOP_H) / 2.0
	for y in range(oy, oy + TOP_H):
		for x in range(TILE_W):
			if not _in_diamond(x, y, oy):
				continue
			var lx := (float(x) - cx) / half_w
			var ly := (float(y - oy) / half_h) - 1.0
			var u := clampf((lx + ly + 1.0) * 0.5, 0.0, 1.0)
			var v := clampf((-lx + ly + 1.0) * 0.5, 0.0, 1.0)
			var col := _sample_bilinear(top, u * float(tw - 1), v * float(th - 1))
			# Atténue le grain quasi-blanc (stippling source) qui devient du "sel" en petit
			col = _soften_speckles(col)
			_set_px(out, x, y, col)


static func _fill_parallelogram(
	out: Image, a: Vector2i, b: Vector2i, c: Vector2i, d: Vector2i, side: Image
) -> void:
	var min_x := mini(mini(a.x, b.x), mini(c.x, d.x))
	var max_x := maxi(maxi(a.x, b.x), maxi(c.x, d.x))
	var min_y := mini(mini(a.y, b.y), mini(c.y, d.y))
	var max_y := maxi(maxi(a.y, b.y), maxi(c.y, d.y))
	var sw := float(side.get_width() - 1)
	var sh := float(side.get_height() - 1)
	var A := Vector2(a)
	var e1 := Vector2(b) - A
	var e2 := Vector2(d) - A
	var det := e1.x * e2.y - e1.y * e2.x
	if absf(det) < 0.0001:
		return
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var op := Vector2(x, y) - A
			var u := (op.x * e2.y - op.y * e2.x) / det
			var v := (e1.x * op.y - e1.y * op.x) / det
			if u < 0.0 or v < 0.0 or u > 1.0 or v > 1.0:
				continue
			var col := _sample_bilinear(side, u * sw, v * sh)
			if col.a < 0.05:
				continue
			_set_px(out, x, y, _soften_speckles(col))


static func _sample_bilinear(img: Image, fx: float, fy: float) -> Color:
	var w := img.get_width()
	var h := img.get_height()
	fx = clampf(fx, 0.0, float(w - 1))
	fy = clampf(fy, 0.0, float(h - 1))
	var x0 := int(floor(fx))
	var y0 := int(floor(fy))
	var x1 := mini(x0 + 1, w - 1)
	var y1 := mini(y0 + 1, h - 1)
	var tx := fx - float(x0)
	var ty := fy - float(y0)
	var c00 := img.get_pixel(x0, y0)
	var c10 := img.get_pixel(x1, y0)
	var c01 := img.get_pixel(x0, y1)
	var c11 := img.get_pixel(x1, y1)
	return c00.lerp(c10, tx).lerp(c01.lerp(c11, tx), ty)


static func _soften_speckles(c: Color) -> Color:
	## Les micro-highlights blancs du PNG deviennent des points parasites une fois réduits.
	var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	if lum < 0.78:
		return c
	var t := clampf((lum - 0.78) / 0.22, 0.0, 1.0)
	var muted := Color(c.r * 0.82, c.g * 0.80, c.b * 0.72, c.a)
	return c.lerp(muted, t * 0.85)


static func _soft_top_light(out: Image, oy: int) -> void:
	## Légère lumière du haut-gauche sur le losange (cozy daylight).
	for y in range(oy, oy + TOP_H):
		for x in range(TILE_W):
			if not _in_diamond(x, y, oy):
				continue
			var c := out.get_pixel(x, y)
			if c.a < 0.05:
				continue
			var u := float(x) / float(TILE_W)
			var v := float(y - oy) / float(TOP_H)
			var light := clampf(0.10 * (1.0 - u) * (1.0 - v * 0.7) - 0.04 * u * v, -0.05, 0.12)
			out.set_pixel(x, y, Color(
				clampf(c.r + light, 0.0, 1.0),
				clampf(c.g + light * 0.95, 0.0, 1.0),
				clampf(c.b + light * 0.7, 0.0, 1.0),
				c.a
			))


static func _stroke_block_edges(out: Image, oy: int, depth: int) -> void:
	## Assombrit le pourtour du losange + arêtes des faces (joint entre tuiles).
	var edge := Color(0.22, 0.16, 0.10, 1.0)
	var cx := TILE_W / 2
	var n := Vector2i(cx, oy)
	var e := Vector2i(cx + TILE_W / 2 - 1, oy + TOP_H / 2)
	var s := Vector2i(cx, oy + TOP_H - 1)
	var w := Vector2i(cx - TILE_W / 2, oy + TOP_H / 2)
	_stroke_line(out, n, e, edge, 0.48)
	_stroke_line(out, e, s, edge, 0.55)
	_stroke_line(out, s, w, edge, 0.55)
	_stroke_line(out, w, n, edge, 0.48)
	# Arêtes verticales / joint face
	_stroke_line(out, e, Vector2i(e.x, e.y + depth), edge, 0.42)
	_stroke_line(out, w, Vector2i(w.x, w.y + depth), edge, 0.42)
	_stroke_line(out, s, Vector2i(s.x, s.y + depth), edge, 0.48)
	_stroke_line(out, Vector2i(e.x, e.y + depth), Vector2i(s.x, s.y + depth), edge, 0.35)
	_stroke_line(out, Vector2i(w.x, w.y + depth), Vector2i(s.x, s.y + depth), edge, 0.35)


static func _stroke_line(img: Image, a: Vector2i, b: Vector2i, ink: Color, mix: float) -> void:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
	if steps <= 0:
		_blend_px(img, a.x, a.y, ink, mix)
		return
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var x := int(round(lerpf(float(a.x), float(b.x), t)))
		var y := int(round(lerpf(float(a.y), float(b.y), t)))
		_blend_px(img, x, y, ink, mix)
		# léger épaississement
		_blend_px(img, x + 1, y, ink, mix * 0.45)
		_blend_px(img, x, y + 1, ink, mix * 0.45)


static func _blend_px(img: Image, x: int, y: int, ink: Color, mix: float) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var c := img.get_pixel(x, y)
	if c.a < 0.05:
		return
	img.set_pixel(x, y, c.lerp(ink, mix))


static func _set_px(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, c)
