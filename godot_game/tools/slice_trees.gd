extends SceneTree
## Re-runnable: slices assets/external-sprites/trees.png (a labeled concept sheet with
## HEALTHY trees, an "RTE" chop sequence and HIT EFFECTS particles) into game sprites.
## Keys out the navy background AND the gray cell borders/labels, then tight-crops each
## cell's content onto a transparent canvas.
##   & "<godot4.7>" --headless --path godot_game -s res://tools/slice_trees.gd
const SRC := "res://assets/external-sprites/trees.png"

# out path (under assets/sprites/), and the source cell rect -- each must contain exactly
# ONE sprite (borders/labels inside the rect are keyed out, so generous rects are fine).
const SPRITES := [
	{"out": "resources/tree.png",     "x": 14,   "y": 56,  "w": 230, "h": 220},
	{"out": "effects/wood_chips.png", "x": 806,  "y": 386, "w": 236, "h": 108},
]

# The leaves cell is split into INDIVIDUAL leaves (connected components) -> effects/leaf_<i>.png,
# so the hit effect can drop a few separate leaves.
const LEAF_CELL := {"x": 1064, "y": 388, "w": 210, "h": 104}
const LEAF_MIN_PX := 20

var _img: Image

func _initialize() -> void:
	_img = Image.new()
	if _img.load(SRC) != OK:
		push_error("slice_trees: cannot load %s" % SRC)
		quit()
		return
	_img.convert(Image.FORMAT_RGBA8)
	for s in SPRITES:
		_extract(s)
	_extract_leaves()
	print("SLICE_TREES DONE")
	quit()

## Background = the navy fill OR the (lighter) gray cell borders / label text. Dark sprite
## outlines (low luminance) are preserved so the trees keep their outline.
func _is_bg(c: Color) -> bool:
	if c.a < 0.5:
		return true
	var r := c.r * 255.0
	var g := c.g * 255.0
	var b := c.b * 255.0
	var lum := 0.299 * r + 0.587 * g + 0.114 * b
	# Navy background: blue clearly dominant over BOTH other channels. Requiring b > g by a
	# good margin avoids eating dark green/teal foliage shadows (where g ~= b), which was
	# punching holes in the canopy.
	if b > r + 14.0 and b > g + 14.0 and lum < 95.0:
		return true
	if lum > 60.0 and absf(r - g) < 16.0 and absf(g - b) < 16.0 and absf(r - b) < 16.0:
		return true  # gray border / label (light, desaturated)
	return false

func _extract(s: Dictionary) -> void:
	var x0: int = s.x
	var y0: int = s.y
	var x1: int = min(int(s.x + s.w), _img.get_width())
	var y1: int = min(int(s.y + s.h), _img.get_height())
	var minx := 999999
	var miny := 999999
	var maxx := -1
	var maxy := -1
	for y in range(y0, y1):
		for x in range(x0, x1):
			if not _is_bg(_img.get_pixel(x, y)):
				minx = min(minx, x)
				maxx = max(maxx, x)
				miny = min(miny, y)
				maxy = max(maxy, y)
	if maxx < 0:
		push_error("slice_trees: no content in cell %s" % s.out)
		return
	var w := maxx - minx + 1
	var h := maxy - miny + 1
	var canvas := Image.create(w, h, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	for y in range(h):
		for x in range(w):
			var c := _img.get_pixel(minx + x, miny + y)
			if not _is_bg(c):
				canvas.set_pixel(x, y, c)
	var out: String = "res://assets/sprites/" + s.out
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	canvas.save_png(out)
	print("  %s -> %dx%d (from %d,%d)" % [s.out, w, h, minx, miny])

## Flood-fill the leaves cell into connected components, saving each as effects/leaf_<i>.png.
func _extract_leaves() -> void:
	var x0: int = LEAF_CELL.x
	var y0: int = LEAF_CELL.y
	var x1: int = min(int(LEAF_CELL.x + LEAF_CELL.w), _img.get_width())
	var y1: int = min(int(LEAF_CELL.y + LEAF_CELL.h), _img.get_height())
	var seen := {}
	var idx := 0
	DirAccess.make_dir_recursive_absolute("res://assets/sprites/effects")
	for sy in range(y0, y1):
		for sx in range(x0, x1):
			var p0 := Vector2i(sx, sy)
			if seen.has(p0) or _is_bg(_img.get_pixel(sx, sy)):
				continue
			# BFS over this component
			var comp: Array[Vector2i] = []
			var stack: Array[Vector2i] = [p0]
			seen[p0] = true
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				comp.append(p)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var np: Vector2i = p + d
					if np.x < x0 or np.x >= x1 or np.y < y0 or np.y >= y1:
						continue
					if seen.has(np) or _is_bg(_img.get_pixel(np.x, np.y)):
						continue
					seen[np] = true
					stack.append(np)
			if comp.size() < LEAF_MIN_PX:
				continue
			var minx := 999999
			var miny := 999999
			var maxx := -1
			var maxy := -1
			for q in comp:
				minx = min(minx, q.x)
				maxx = max(maxx, q.x)
				miny = min(miny, q.y)
				maxy = max(maxy, q.y)
			var cw := maxx - minx + 1
			var ch := maxy - miny + 1
			var canvas := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
			canvas.fill(Color(0, 0, 0, 0))
			for q in comp:
				canvas.set_pixel(q.x - minx, q.y - miny, _img.get_pixel(q.x, q.y))
			canvas.save_png("res://assets/sprites/effects/leaf_%d.png" % idx)
			idx += 1
	print("  leaves -> %d individual leaf_*.png" % idx)
