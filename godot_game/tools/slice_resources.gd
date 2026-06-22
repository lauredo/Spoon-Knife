extends SceneTree
## Re-runnable: slices assets/external-sprites/resources.png (a labeled concept sheet — each
## sprite sits on a solid brown DIRT tile, with a dark frame, over a dark-blue background).
## Goal: cut out JUST the sprite (transparent bg).
##
## Most sprites have a colour clearly distinct from the brown dirt, so we keep pixels of that
## colour family plus the dark outline hugging them ("color" modes) — robust, no flooding.
## The WOOD drop is brown like the dirt, so colour can't separate it; for that one we flood the
## background inward from the border, ERODING the fill by 1px so it can't leak through tiny gaps
## in the log's outline, and keep the largest interior blob.
##   & "<godot4.7>" --headless --path godot_game -s res://tools/slice_resources.gd
const SRC := "res://assets/external-sprites/resources.png"

const CELLS := [
	{"out": "resources/rock.png", "x": 120, "y": 268, "w": 322, "h": 322, "mode": "solid", "color": "gray"},  # Pedra grande
	{"out": "resources/bush.png", "x": 623, "y": 44,  "w": 168, "h": 164, "mode": "green"},  # Arbusto
	{"out": "drops/stone.png",    "x": 648, "y": 276, "w": 104, "h": 108, "mode": "gray"},   # Pedra caída (tight rect = no frame)
	{"out": "drops/meat.png",     "x": 635, "y": 460, "w": 135, "h": 122, "mode": "red"},    # Carne caída
	{"out": "drops/wood.png",     "x": 644, "y": 653, "w": 120, "h": 113, "mode": "flood"},  # Madeira caída
]

var img: Image
var W: int
var H: int

func _initialize() -> void:
	img = Image.new()
	if img.load(SRC) != OK:
		push_error("slice_resources: cannot load %s" % SRC)
		quit()
		return
	img.convert(Image.FORMAT_RGBA8)
	W = img.get_width()
	H = img.get_height()
	for cell in CELLS:
		var mode: String = cell.mode
		if mode == "flood":
			_extract_flood(cell)
		elif mode == "solid":
			_extract_solid(cell, cell.get("color", "gray"))
		else:
			_extract_color(cell, mode)
	print("SLICE_RESOURCES DONE")
	quit()

# ---- colour-family test for the sprite body -------------------------------------------------
func _is_core(c: Color, mode: String) -> bool:
	if c.a < 0.5:
		return false
	var r := c.r * 255.0
	var g := c.g * 255.0
	var b := c.b * 255.0
	var lum := 0.299 * r + 0.587 * g + 0.114 * b
	var mx: float = max(r, max(g, b))
	var mn: float = min(r, min(g, b))
	match mode:
		"gray":
			return lum > 45.0 and (mx - mn) < 22.0  # desaturated stone, brighter than navy
		"green":
			return g > r + 5.0 and g > b + 5.0 and g > 55.0  # foliage
		"red":
			return (r - g) > 35.0 and (r - b) > 35.0 and r > 90.0  # meat
	return false

## Saved sprite = core-colour pixels + any dark pixel (outline/shading) within 2px of a core
## pixel. This keeps the sprite's own outline but never the far-off dirt frame.
func _extract_color(cell: Dictionary, mode: String) -> void:
	var x0: int = cell.x
	var y0: int = cell.y
	var x1: int = mini(int(cell.x + cell.w), W)
	var y1: int = mini(int(cell.y + cell.h), H)
	var cw := x1 - x0
	var ch := y1 - y0

	var core := PackedByteArray()
	core.resize(cw * ch)
	for ly in range(ch):
		for lx in range(cw):
			core[ly * cw + lx] = 1 if _is_core(img.get_pixel(x0 + lx, y0 + ly), mode) else 0

	var keep := PackedByteArray()
	keep.resize(cw * ch)
	for ly in range(ch):
		for lx in range(cw):
			var i := ly * cw + lx
			if core[i] == 1:
				keep[i] = 1
				continue
			var c := img.get_pixel(x0 + lx, y0 + ly)
			var rr := c.r * 255.0
			var gg := c.g * 255.0
			var bb := c.b * 255.0
			var lum := 0.299 * rr + 0.587 * gg + 0.114 * bb
			if lum >= 45.0 or not _near_core(core, cw, ch, lx, ly, 2):
				continue
			# Keep the sprite's own dark outline, but for gray/green sprites reject the warm dirt
			# frame (the outline there is neutral; the frame is warm). Meat's outline IS warm red.
			var neutral: bool = (max(rr, max(gg, bb)) - min(rr, min(gg, bb))) <= 7.0
			if mode == "red" or neutral:
				keep[i] = 1  # dark outline hugging the sprite
	_save_keep(cell.out, keep, cw, ch, x0, y0)

## "Solid" extraction: keep the colour-family body PLUS everything enclosed by it (interior
## crevices), dropping only what's reachable from the border (navy, the dirt tile and its
## straight frame/edge halo). Used for the big rock, whose blocky bbox made the frame read as a
## square that color/flood keys couldn't tell from a real outline.
func _extract_solid(cell: Dictionary, mode: String) -> void:
	var x0: int = cell.x
	var y0: int = cell.y
	var x1: int = mini(int(cell.x + cell.w), W)
	var y1: int = mini(int(cell.y + cell.h), H)
	var cw := x1 - x0
	var ch := y1 - y0

	var core := PackedByteArray()
	core.resize(cw * ch)
	for ly in range(ch):
		for lx in range(cw):
			core[ly * cw + lx] = 1 if _is_core(img.get_pixel(x0 + lx, y0 + ly), mode) else 0

	# Flood "exterior" inward from the border through NON-core pixels.
	var ext := PackedByteArray()
	ext.resize(cw * ch)
	var stack: Array[int] = []
	for lx in range(cw):
		_sseed(lx, 0, cw, ch, core, ext, stack)
		_sseed(lx, ch - 1, cw, ch, core, ext, stack)
	for ly in range(ch):
		_sseed(0, ly, cw, ch, core, ext, stack)
		_sseed(cw - 1, ly, cw, ch, core, ext, stack)
	while not stack.is_empty():
		var p: int = stack.pop_back()
		var px := p % cw
		var py := p / cw
		_sseed(px + 1, py, cw, ch, core, ext, stack)
		_sseed(px - 1, py, cw, ch, core, ext, stack)
		_sseed(px, py + 1, cw, ch, core, ext, stack)
		_sseed(px, py - 1, cw, ch, core, ext, stack)

	# Keep everything that isn't exterior (= body + enclosed interior).
	var keep := PackedByteArray()
	keep.resize(cw * ch)
	for i in range(cw * ch):
		keep[i] = 1 if ext[i] == 0 else 0
	_save_keep(cell.out, keep, cw, ch, x0, y0)

func _sseed(lx: int, ly: int, cw: int, ch: int, core: PackedByteArray, ext: PackedByteArray, stack: Array) -> void:
	if lx < 0 or lx >= cw or ly < 0 or ly >= ch:
		return
	var i := ly * cw + lx
	if ext[i] == 1 or core[i] == 1:
		return
	ext[i] = 1
	stack.append(i)

func _near_core(core: PackedByteArray, cw: int, ch: int, lx: int, ly: int, rad: int) -> bool:
	for dy in range(-rad, rad + 1):
		for dx in range(-rad, rad + 1):
			var nx := lx + dx
			var ny := ly + dy
			if nx < 0 or nx >= cw or ny < 0 or ny >= ch:
				continue
			if core[ny * cw + nx] == 1:
				return true
	return false

# ---- flood mode (wood: brown like the dirt) -------------------------------------------------
func _is_fillable(c: Color) -> bool:
	if c.a < 0.5:
		return true
	var r := c.r * 255.0
	var g := c.g * 255.0
	var b := c.b * 255.0
	var lum := 0.299 * r + 0.587 * g + 0.114 * b
	if lum < 12.0:
		return false  # dark outline = barrier
	if b >= r + 3.0 and b >= g + 3.0 and lum < 55.0:
		return true  # navy background
	if r > g and r >= b and (r - b) > 6.0 and (r - g) < 30.0 and lum < 120.0:
		return true  # warm dirt tile + dark frame
	return false

func _extract_flood(cell: Dictionary) -> void:
	var x0: int = cell.x
	var y0: int = cell.y
	var x1: int = mini(int(cell.x + cell.w), W)
	var y1: int = mini(int(cell.y + cell.h), H)
	var cw := x1 - x0
	var ch := y1 - y0

	var fillable := PackedByteArray()
	fillable.resize(cw * ch)
	for ly in range(ch):
		for lx in range(cw):
			fillable[ly * cw + lx] = 1 if _is_fillable(img.get_pixel(x0 + lx, y0 + ly)) else 0

	# Erode the fillable region by 1px (a pixel only floods if all 8 neighbours are also fillable);
	# this seals 1px gaps in the log outline so the flood can't leak into the brown log.
	var floodable := PackedByteArray()
	floodable.resize(cw * ch)
	for ly in range(ch):
		for lx in range(cw):
			var i := ly * cw + lx
			if fillable[i] == 0:
				floodable[i] = 0
				continue
			var ok := 1
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := lx + dx
					var ny := ly + dy
					if nx < 0 or nx >= cw or ny < 0 or ny >= ch:
						continue  # out of cell counts as fillable
					if fillable[ny * cw + nx] == 0:
						ok = 0
			floodable[i] = ok

	# Flood the background from the rect border (4-connected) over the eroded region.
	var flood := PackedByteArray()
	flood.resize(cw * ch)
	var stack: Array[int] = []
	for lx in range(cw):
		_fseed(lx, 0, cw, ch, floodable, flood, stack)
		_fseed(lx, ch - 1, cw, ch, floodable, flood, stack)
	for ly in range(ch):
		_fseed(0, ly, cw, ch, floodable, flood, stack)
		_fseed(cw - 1, ly, cw, ch, floodable, flood, stack)
	# Also seed from points just inside the dirt tile (the log is centred, so its corners/edges
	# at ~12% inset are dirt). This starts the fill INSIDE the dark frame, which would otherwise
	# wall the border-fill out of the dirt. Center is skipped (that's the log).
	var ix0 := int(cw * 0.12)
	var iy0 := int(ch * 0.12)
	var ix1 := cw - 1 - ix0
	var iy1 := ch - 1 - iy0
	for s in [Vector2i(ix0, iy0), Vector2i(ix1, iy0), Vector2i(ix0, iy1), Vector2i(ix1, iy1), Vector2i(cw / 2, iy0), Vector2i(cw / 2, iy1), Vector2i(ix0, ch / 2), Vector2i(ix1, ch / 2)]:
		_fseed(s.x, s.y, cw, ch, floodable, flood, stack)
	while not stack.is_empty():
		var p: int = stack.pop_back()
		var px := p % cw
		var py := p / cw
		_fseed(px + 1, py, cw, ch, floodable, flood, stack)
		_fseed(px - 1, py, cw, ch, floodable, flood, stack)
		_fseed(px, py + 1, cw, ch, floodable, flood, stack)
		_fseed(px, py - 1, cw, ch, floodable, flood, stack)

	# Kept = not flooded. Label 8-connected kept components; keep the largest that doesn't touch
	# the cell border (= the log, not the leftover dirt frame which hugs the border).
	var keep := PackedByteArray()
	keep.resize(cw * ch)
	for i in range(cw * ch):
		keep[i] = 1 if flood[i] == 0 else 0
	_open_mask(keep, cw, ch)  # drop thin (1px) stray bits like leftover frame slivers
	_keep_main_blob(keep, cw, ch)
	_save_keep(cell.out, keep, cw, ch, x0, y0)

## Morphological opening (erode then dilate, 4-connected): removes 1px-thin protrusions/specks
## while leaving solid shapes intact.
func _open_mask(keep: PackedByteArray, cw: int, ch: int) -> void:
	var eroded := PackedByteArray()
	eroded.resize(cw * ch)
	for ly in range(ch):
		for lx in range(cw):
			var i := ly * cw + lx
			var on := keep[i] == 1
			if on and lx > 0 and keep[i - 1] == 0: on = false
			if on and lx < cw - 1 and keep[i + 1] == 0: on = false
			if on and ly > 0 and keep[i - cw] == 0: on = false
			if on and ly < ch - 1 and keep[i + cw] == 0: on = false
			eroded[i] = 1 if on else 0
	for ly in range(ch):
		for lx in range(cw):
			var i := ly * cw + lx
			var on := eroded[i] == 1
			if not on and lx > 0 and eroded[i - 1] == 1: on = true
			if not on and lx < cw - 1 and eroded[i + 1] == 1: on = true
			if not on and ly > 0 and eroded[i - cw] == 1: on = true
			if not on and ly < ch - 1 and eroded[i + cw] == 1: on = true
			keep[i] = 1 if on else 0

func _fseed(lx: int, ly: int, cw: int, ch: int, floodable: PackedByteArray, flood: PackedByteArray, stack: Array) -> void:
	if lx < 0 or lx >= cw or ly < 0 or ly >= ch:
		return
	var i := ly * cw + lx
	if flood[i] == 1 or floodable[i] == 0:
		return
	flood[i] = 1
	stack.append(i)

## Reduce `keep` to its largest 8-connected component that does not touch the cell border.
func _keep_main_blob(keep: PackedByteArray, cw: int, ch: int) -> void:
	var seen := PackedByteArray()
	seen.resize(cw * ch)
	var best: Array[int] = []
	var best_area := -1
	for sy in range(ch):
		for sx in range(cw):
			var si := sy * cw + sx
			if keep[si] == 0 or seen[si] == 1:
				continue
			var comp: Array[int] = []
			var stack: Array[int] = [si]
			seen[si] = 1
			var touches := false
			while not stack.is_empty():
				var p: int = stack.pop_back()
				comp.append(p)
				var px := p % cw
				var py := p / cw
				if px == 0 or py == 0 or px == cw - 1 or py == ch - 1:
					touches = true
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
					var nx: int = px + d.x
					var ny: int = py + d.y
					if nx < 0 or nx >= cw or ny < 0 or ny >= ch:
						continue
					var ni: int = ny * cw + nx
					if keep[ni] == 0 or seen[ni] == 1:
						continue
					seen[ni] = 1
					stack.append(ni)
			if not touches and comp.size() > best_area:
				best_area = comp.size()
				best = comp
	# Rewrite keep to only the chosen component.
	for i in range(cw * ch):
		keep[i] = 0
	for p in best:
		keep[p] = 1

# ---- shared save ----------------------------------------------------------------------------
func _save_keep(out_rel: String, keep: PackedByteArray, cw: int, ch: int, x0: int, y0: int) -> void:
	var minx := cw
	var miny := ch
	var maxx := -1
	var maxy := -1
	for ly in range(ch):
		for lx in range(cw):
			if keep[ly * cw + lx] == 1:
				minx = mini(minx, lx)
				maxx = maxi(maxx, lx)
				miny = mini(miny, ly)
				maxy = maxi(maxy, ly)
	if maxx < 0:
		push_error("slice_resources: nothing kept for %s" % out_rel)
		return
	var ow := maxx - minx + 1
	var oh := maxy - miny + 1
	var canvas := Image.create(ow, oh, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	for ly in range(oh):
		for lx in range(ow):
			if keep[(miny + ly) * cw + (minx + lx)] == 1:
				canvas.set_pixel(lx, ly, img.get_pixel(x0 + minx + lx, y0 + miny + ly))
	var out: String = "res://assets/sprites/" + out_rel
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	canvas.save_png(out)
	print("  %s -> %dx%d" % [out_rel, ow, oh])
