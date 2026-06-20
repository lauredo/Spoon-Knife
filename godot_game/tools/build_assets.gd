extends SceneTree
## Headless asset builder. Rasterizes every SVG under res://assets/_svg_src/ to a PNG
## at the mirrored path under res://assets/sprites/.
##
## Run after editing/adding any SVG:
##   & "<godot 4.7>" --headless --path godot_game -s res://tools/build_assets.gd
##
## NOTE: this only rasterizes SVG -> PNG. Animation SpriteFrames are assembled at
## runtime by Assets.sprite_frames() from the individual PNG frames, so there is no
## .tres build step (and no import-ordering problem).

const SRC_DIR := "res://assets/_svg_src/"
const OUT_DIR := "res://assets/sprites/"
const SUPERSAMPLE := 4.0  # render SVGs at 4x for crisp downscaling in-game

func _initialize() -> void:
	var n := _rasterize_dir(SRC_DIR)
	print("ASSET BUILD DONE — rasterized %d SVG(s)." % n)
	quit()

func _rasterize_dir(dir_path: String) -> int:
	var count := 0
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("No source dir: " + dir_path)
		return 0
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		var full := dir_path + fname
		if dir.current_is_dir():
			count += _rasterize_dir(full + "/")
		elif fname.to_lower().ends_with(".svg"):
			if _rasterize_one(full):
				count += 1
		fname = dir.get_next()
	dir.list_dir_end()
	return count

func _rasterize_one(svg_path: String) -> bool:
	var f := FileAccess.open(svg_path, FileAccess.READ)
	if f == null:
		push_warning("cannot read " + svg_path)
		return false
	var svg := f.get_as_text()
	f.close()
	var img := Image.new()
	var err := img.load_svg_from_string(svg, SUPERSAMPLE)
	if err != OK:
		push_error("SVG parse failed (%d): %s" % [err, svg_path])
		return false
	var rel := svg_path.substr(SRC_DIR.length())
	var out_path := OUT_DIR + rel.get_basename() + ".png"
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var serr := img.save_png(out_path)
	if serr != OK:
		push_error("save_png failed (%d): %s" % [serr, out_path])
		return false
	print("  ", out_path, "  (", img.get_width(), "x", img.get_height(), ")")
	return true
