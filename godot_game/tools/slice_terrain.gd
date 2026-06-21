extends SceneTree
## Re-runnable: builds a LARGE, varied, seamlessly-tileable dirt ground texture out of the
## isometric dirt field in assets/external-sprites/ground.png and saves it as the tiling
## ground texture assets/sprites/terrain/ground.png.
##   & "<godot4.7>" --headless --path godot_game -s res://tools/slice_terrain.gd
##
## ground.png is an AI concept SHEET (title banner + "ISOMETRIC DIRT TILES" / "SEAMLESS
## EDGES" labels + a raccoon baked in) and it's all ONE material (dirt). The sheet is an
## isometric TILE set, so straight off it reads as an obvious repeating diamond lattice;
## we turn it into organic mottled dirt:
##   1.  crop a big BASE out of the diamond field, on edge-matched periods (W=976, H=360);
##   1b. flatten the field's top-to-bottom brightness gradient (keeping the diamond rows);
##   2.  "texture bomb" several PATCHES from OTHER field spots (same ~140x90 lattice phase)
##       for pebble/shade variation;
##   2b. DOMAIN WARP -- displace pixels by smooth noise so the straight diamond seams become
##       irregular organic cracked-earth lines (kills the obvious grid);
##   2c. lift the remaining dark seams toward their local tone, softening the lattice;
##   3.  make it seamlessly tileable by cross-fading each pair of opposite edges.
const SRC := "res://assets/external-sprites/ground.png"
const OUT := "res://assets/sprites/terrain/ground.png"

# Diamond lattice period (used to phase-align variant patches). Horizontal ~140, vertical
# ~90 (one full bright-face+dark-seam row cycle).
const PERIOD_X := 140
const PERIOD_Y := 90

# Big clean base crop from the diamond field. Width/height were tuned by an edge-mismatch
# search (minimize the difference between opposite edges) so the crop tiles cleanly: W=976
# is near-seamless horizontally; H=360 is the best vertical period. Origin is the grid phase
# reference: output x=0 maps to sheet x=BASE_X, output y=0 to sheet y=BASE_Y.
const BASE_X := 175
const BASE_Y := 108
const BASE_W := 976
const BASE_H := 360

# Clean field extent in the sheet (no banner/labels/raccoon) used to sample variant patches.
const FIELD_X1 := 1180
const FIELD_Y1 := 456

# Texture bombing: variant patches blended onto the base for variation. Kept partial
# (PATCH_ALPHA) so the base diamonds stay crisp -- the patches only nudge pebble/shade
# detail; at full strength, slight AI lattice drift doubles the diamond edges (muddy).
const PATCHES := 8
const PATCH_W := 280  # 2 * PERIOD_X
const PATCH_H := 174  # 2 * PERIOD_Y
const PATCH_FEATHER := 44.0
const PATCH_ALPHA := 0.5

# De-grid step 1 -- domain warp: the diamonds read as an obvious lattice mostly because the
# seams are dead-straight and regular. We displace every pixel by a smooth noise field, so
# the straight seams become wavy, irregular cracked-earth lines -- organic, not a grid.
const WARP_AMP := 24.0    # max pixel displacement
const WARP_FREQ := 0.018  # noise frequency (smaller = larger, smoother wobble)

# De-grid step 2 -- lift dark seams toward their local tone, softening what's left of the
# lattice. GRID_SOFTEN = strength (0..1); BLUR_DOWNSCALE = smoothness of the "local tone".
const GRID_SOFTEN := 0.5
const BLUR_DOWNSCALE := 16

# De-blue: the sheet scatters cold blue-gray pebbles that read as odd blue specks in dirt.
# Any pixel that isn't warm (blue >= red) is converted toward a warm dirt tone of the same
# brightness, so the speck becomes brown/gravel instead of blue. 0..1 strength.
const DEBLUE := 0.92

# Final tone: the warped dirt comes out dark and cold (reads as swamp/mud, esp. next to the
# green bushes). Lift the black point, brighten the midtones and warm the hue so it reads as
# dry earth. Tune these against a real in-game screenshot, not the raw texture.
const TONE_LIFT := 0.12                    # raise the black point (kills muddy near-blacks)
const TONE_GAMMA := 0.80                   # <1 brightens midtones
const TONE_GAIN := 1.14                    # overall brightness
const TONE_WARM := Vector3(1.06, 1.0, 0.88)  # per-channel warm tint (R up, B down)

# Seamless edges: cross-fade each pair of opposite edges (mirror partners across the wrap)
# over a band of this width. Blends REAL content from both edges, so a mismatched pebble at
# the boundary becomes a faint ghost instead of a stretched streak (which a ramp-heal caused).
const SEAM_BLEND := 22

const SEED := 1337

var _sheet: Image
var _rng := RandomNumberGenerator.new()

func _initialize() -> void:
	_rng.seed = SEED
	_sheet = Image.new()
	if _sheet.load(SRC) != OK:
		push_error("slice_terrain: cannot load %s" % SRC)
		quit()
		return
	_sheet.convert(Image.FORMAT_RGBA8)

	var img := _sheet.get_region(Rect2i(BASE_X, BASE_Y, BASE_W, BASE_H))
	_flatten_vertical(img)
	_bomb_patches(img)
	_deblue(img)
	img = _warp(img)
	_soften_grid(img)
	_tone(img)
	_make_seamless(img)

	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	if img.save_png(OUT) != OK:
		push_error("slice_terrain: cannot save %s" % OUT)
	else:
		print("SLICE_TERRAIN DONE -> %s (%dx%d)" % [OUT, img.get_width(), img.get_height()])
	quit()

# --- Step 1b: flatten vertical gradient --------------------------------------------------

## The dirt field is darker at the top than the middle (a low-frequency vertical gradient on
## top of the diamond-row oscillation), so the crop's top and bottom edges don't match and a
## brightness step shows at the seam. We equalize each row's brightness toward the global mean
## using a TREND smoothed over one diamond period -- this removes the gradient while preserving
## the bright-face / dark-seam diamond oscillation.
func _flatten_vertical(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var means: Array[float] = []
	for y in h:
		var s := 0.0
		for x in range(0, w, 2):
			var c := img.get_pixel(x, y)
			s += 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
		means.append(s / float((w + 1) / 2))
	var global := 0.0
	for m in means:
		global += m
	global /= float(h)
	var half := int(PERIOD_Y / 2)  # ~half a diamond period -> window ~= one full period
	for y in h:
		var s := 0.0
		var n := 0
		for k in range(y - half, y + half + 1):
			s += means[clampi(k, 0, h - 1)]
			n += 1
		var trend: float = s / float(n)
		var factor: float = clampf(global / maxf(trend, 0.001), 0.75, 1.35)
		for x in w:
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(clampf(c.r * factor, 0.0, 1.0), clampf(c.g * factor, 0.0, 1.0), clampf(c.b * factor, 0.0, 1.0), c.a))

# --- Step 2: texture bombing -------------------------------------------------------------

func _bomb_patches(img: Image) -> void:
	var max_k: int = int((FIELD_X1 - BASE_X - PATCH_W) / PERIOD_X)  # source x steps
	var max_m: int = int((FIELD_Y1 - BASE_Y - PATCH_H) / PERIOD_Y)  # source y steps
	var max_c: int = int((BASE_W - PATCH_W) / PERIOD_X)             # dest x steps
	var max_d: int = int((BASE_H - PATCH_H) / PERIOD_Y)             # dest y steps
	for _i in PATCHES:
		var c := _rng.randi_range(0, max_c)
		var d := _rng.randi_range(0, max_d)
		var k := _rng.randi_range(0, max_k)
		var m := _rng.randi_range(0, max_m)
		# Don't paste the same content that's already under the destination.
		if k == c and m == d:
			k = (k + 1) % (max_k + 1)
		_blend_patch(img, BASE_X + k * PERIOD_X, BASE_Y + m * PERIOD_Y, c * PERIOD_X, d * PERIOD_Y)

func _blend_patch(img: Image, sx: int, sy: int, dx: int, dy: int) -> void:
	for py in PATCH_H:
		var fy := _feather(py, PATCH_H, PATCH_FEATHER)
		for px in PATCH_W:
			var a := _feather(px, PATCH_W, PATCH_FEATHER) * fy * PATCH_ALPHA
			if a <= 0.001:
				continue
			var src := _sheet.get_pixel(sx + px, sy + py)
			var dst := img.get_pixel(dx + px, dy + py)
			img.set_pixel(dx + px, dy + py, dst.lerp(src, a))

## Smoothstep feather: 0 at the edges of [0,size), ramping to 1 within f px of either edge.
func _feather(i: int, size: int, f: float) -> float:
	var d: float = float(min(i, size - 1 - i))
	if d >= f:
		return 1.0
	var t: float = d / f
	return t * t * (3.0 - 2.0 * t)

# --- Step 2b: domain warp (break the regular grid into organic shapes) -------------------

## Resample the image with each pixel pulled from a noise-displaced source position. Straight
## diamond seams become irregular wavy lines. Sampling wraps within the tile so it stays
## tileable (edges are cross-faded afterwards anyway).
func _warp(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var nx := FastNoiseLite.new()
	nx.noise_type = FastNoiseLite.TYPE_SIMPLEX
	nx.frequency = WARP_FREQ
	nx.seed = SEED
	var ny := FastNoiseLite.new()
	ny.noise_type = FastNoiseLite.TYPE_SIMPLEX
	ny.frequency = WARP_FREQ
	ny.seed = SEED + 7
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var dx := int(round(nx.get_noise_2d(x, y) * WARP_AMP))
			var dy := int(round(ny.get_noise_2d(x, y) * WARP_AMP))
			out.set_pixel(x, y, img.get_pixel(wrapi(x + dx, 0, w), wrapi(y + dy, 0, h)))
	return out

# --- Step 2c: de-grid (dissolve the diamond seam lattice) --------------------------------

## Lift dark seam pixels toward the local dirt tone so the regular diamond grid dissolves
## into organic mottled dirt. The "local tone" is a heavily downscaled+upscaled blur (so it
## holds the macro shading but not the diamonds); any pixel darker than it -- i.e. a seam --
## is pulled toward it, proportional to how dark it is. Lighter pebbles stay untouched.
func _soften_grid(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var blur := Image.new()
	blur.copy_from(img)
	blur.resize(maxi(1, w / BLUR_DOWNSCALE), maxi(1, h / BLUR_DOWNSCALE), Image.INTERPOLATE_BILINEAR)
	blur.resize(w, h, Image.INTERPOLATE_BILINEAR)
	for y in h:
		for x in w:
			var o := img.get_pixel(x, y)
			var b := blur.get_pixel(x, y)
			var lo := 0.299 * o.r + 0.587 * o.g + 0.114 * o.b
			var lb := 0.299 * b.r + 0.587 * b.g + 0.114 * b.b
			if lo < lb:
				var f: float = clampf((lb - lo) / maxf(lb, 0.001) * GRID_SOFTEN, 0.0, GRID_SOFTEN)
				img.set_pixel(x, y, o.lerp(b, f))

# --- Step 2c2: de-blue (kill the cold blue pebbles) --------------------------------------

func _deblue(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.b + 0.02 >= c.r:  # cool / neutral, not warm dirt (which has r > b)
				var lum := 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
				var warm := Color(clampf(lum * 1.20, 0.0, 1.0), clampf(lum * 0.92, 0.0, 1.0), clampf(lum * 0.60, 0.0, 1.0))
				img.set_pixel(x, y, c.lerp(warm, DEBLUE))

# --- Step 2d: tone (dry warm earth, not cold mud) ----------------------------------------

func _tone(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var r: float = (TONE_LIFT + pow(c.r, TONE_GAMMA) * (1.0 - TONE_LIFT)) * TONE_GAIN * TONE_WARM.x
			var g: float = (TONE_LIFT + pow(c.g, TONE_GAMMA) * (1.0 - TONE_LIFT)) * TONE_GAIN * TONE_WARM.y
			var b: float = (TONE_LIFT + pow(c.b, TONE_GAMMA) * (1.0 - TONE_LIFT)) * TONE_GAIN * TONE_WARM.z
			img.set_pixel(x, y, Color(clampf(r, 0.0, 1.0), clampf(g, 0.0, 1.0), clampf(b, 0.0, 1.0), c.a))

# --- Step 3: seamless edges --------------------------------------------------------------

## Make the texture tile by cross-fading each pair of opposite edges. For band index i,
## pixel i is blended toward its mirror partner (w-1-i) across the wrap, at most 50% at the
## very edge and decaying to 0 over SEAM_BLEND px. Both samples are REAL texture, so the
## boundary softens into a faint pebble ghost -- never a stretched streak.
func _make_seamless(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var f := SEAM_BLEND
	# Left/right edges (x-wrap).
	for y in h:
		for i in f:
			var bl := 0.5 * (1.0 - _smoothstep(float(i) / float(f)))
			var a := img.get_pixel(i, y)
			var b := img.get_pixel(w - 1 - i, y)
			img.set_pixel(i, y, a.lerp(b, bl))
			img.set_pixel(w - 1 - i, y, b.lerp(a, bl))
	# Top/bottom edges (y-wrap).
	for x in w:
		for i in f:
			var bl := 0.5 * (1.0 - _smoothstep(float(i) / float(f)))
			var a := img.get_pixel(x, i)
			var b := img.get_pixel(x, h - 1 - i)
			img.set_pixel(x, i, a.lerp(b, bl))
			img.set_pixel(x, h - 1 - i, b.lerp(a, bl))

func _smoothstep(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
