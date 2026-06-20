extends SceneTree
## One-off: slices assets/external-sprites/racoon.png into per-frame PNGs under
## assets/sprites/player/, keying out the (blue) background to transparency and
## centering each frame horizontally + bottom-aligning (feet) on a uniform canvas.
##   & "<godot4.7>" --headless --path godot_game -s res://tools/slice_raccoon.gd

const SRC := "res://assets/external-sprites/racoon.png"
const OUT := "res://assets/sprites/player/"
# Fixed canvas for EVERY frame across all anims, so feet stay anchored when switching.
const CANVAS_W := 124
const CANVAS_H := 110

# anim name, band y range, x search range (to isolate left/right groups), frame count
const ANIMS := [
	{"name": "idle_se",   "y0": 104, "y1": 196, "x0": 0,   "x1": 400,  "n": 3},
	{"name": "walk_se",   "y0": 259, "y1": 368, "x0": 0,   "x1": 820,  "n": 6},
	{"name": "walk_sw",   "y0": 447, "y1": 549, "x0": 0,   "x1": 840,  "n": 6},
	{"name": "attack_se", "y0": 447, "y1": 549, "x0": 845, "x1": 1408, "n": 4},
	{"name": "walk_ne",   "y0": 633, "y1": 737, "x0": 0,   "x1": 840,  "n": 6},
	{"name": "attack_sw", "y0": 633, "y1": 737, "x0": 845, "x1": 1408, "n": 4},
]

var _img: Image

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_img = Image.new()
	_img.load(SRC)
	_img.convert(Image.FORMAT_RGBA8)
	for a in ANIMS:
		_process_anim(a)
	print("SLICE_RACCOON DONE")
	quit()

func _is_bg(c: Color) -> bool:
	# Background/grid/highlight are all blue-dominant; the raccoon (gray/brown/white/
	# black outline) and the yellow claw arc are not. Also treat transparent as bg.
	if c.a < 0.5:
		return true
	var r := c.r * 255.0
	var g := c.g * 255.0
	var b := c.b * 255.0
	return b > r + 10.0 and b > g + 6.0

func _is_body(c: Color) -> bool:
	# Raccoon body only (used to split frames). Excludes background AND the yellow
	# claw arc, which otherwise bridges adjacent attack frames.
	if _is_bg(c):
		return false
	var r := c.r * 255.0
	var g := c.g * 255.0
	var b := c.b * 255.0
	var is_yellow := r > 140.0 and g > 110.0 and b < 115.0 and (r - b) > 55.0 and (g - b) > 35.0
	return not is_yellow

func _process_anim(a: Dictionary) -> void:
	var y0: int = a.y0
	var y1: int = min(int(a.y1), _img.get_height() - 1)
	var x0: int = a.x0
	var x1: int = min(int(a.x1), _img.get_width() - 1)
	var n: int = a.n

	# Column profile of BODY pixels (so the yellow claw doesn't merge frames).
	var col := []
	for x in range(x0, x1 + 1):
		var has := false
		for y in range(y0, y1 + 1):
			if _is_body(_img.get_pixel(x, y)):
				has = true
				break
		col.append(has)

	# Segment columns into body runs (merge gaps < 10, min width 10)
	var segs := []
	var s := -1
	var gap := 0
	for i in col.size():
		if col[i]:
			if s < 0:
				s = i
			gap = 0
		else:
			if s >= 0:
				gap += 1
				if gap > 10:
					if (i - gap) - s > 10:
						segs.append([x0 + s, x0 + (i - gap)])
					s = -1
					gap = 0
	if s >= 0:
		segs.append([x0 + s, x0 + col.size() - 1])

	# Frame x-ranges: expand each body run to the midpoints of the gaps so each
	# frame keeps its claw arc. Fall back to equal division if count is wrong.
	var frames := []
	if segs.size() == n:
		for i in n:
			var l: int = (segs[i][0] - 6) if i == 0 else int((segs[i - 1][1] + segs[i][0]) / 2)
			var r: int = (segs[i][1] + 6) if i == n - 1 else int((segs[i][1] + segs[i + 1][0]) / 2)
			frames.append([max(l, x0), min(r, x1)])
	else:
		var cx0: int = segs[0][0] if segs.size() > 0 else x0
		var cx1: int = segs[segs.size() - 1][1] if segs.size() > 0 else x1
		var step := float(cx1 - cx0 + 1) / n
		for i in n:
			frames.append([int(cx0 + i * step), int(cx0 + (i + 1) * step) - 1])

	# Composite each frame onto a FIXED canvas (same size for every anim) so the feet
	# stay at a consistent position when switching animations. Center-x, bottom-align.
	for i in frames.size():
		var bb = _bbox(frames[i][0], frames[i][1], y0, y1)
		var canvas := Image.create(CANVAS_W, CANVAS_H, false, Image.FORMAT_RGBA8)
		canvas.fill(Color(0, 0, 0, 0))
		if bb != null:
			var bx: int = bb[0]
			var by: int = bb[1]
			var bw: int = bb[2]
			var bh: int = bb[3]
			var dx := int((CANVAS_W - bw) / 2)
			var dy := CANVAS_H - bh
			for yy in bh:
				for xx in bw:
					var c := _img.get_pixel(bx + xx, by + yy)
					if not _is_bg(c):
						canvas.set_pixel(dx + xx, dy + yy, c)
		canvas.save_png(OUT + "%s_%d.png" % [a.name, i])
		if a.name == "walk_sw" and i == 0:
			canvas.save_png(OUT + "idle_sw_0.png")
		if a.name == "walk_ne" and i == 0:
			canvas.save_png(OUT + "idle_ne_0.png")
	var segstr := ""
	for sg in segs:
		segstr += "[%d-%d]" % [sg[0], sg[1]]
	print("  ", a.name, " segs=", segs.size(), "/", n, " ", segstr)

func _bbox(fx0: int, fx1: int, fy0: int, fy1: int):
	var minx := 999999
	var miny := 999999
	var maxx := -1
	var maxy := -1
	for y in range(fy0, fy1 + 1):
		for x in range(fx0, fx1 + 1):
			if not _is_bg(_img.get_pixel(x, y)):
				minx = min(minx, x)
				maxx = max(maxx, x)
				miny = min(miny, y)
				maxy = max(maxy, y)
	if maxx < 0:
		return null
	return [minx, miny, maxx - minx + 1, maxy - miny + 1]
