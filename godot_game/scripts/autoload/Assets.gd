extends Node
## Central asset loader (autoload singleton "Assets").
##
## Convention-based with GRACEFUL FALLBACK: every getter returns null when the file
## is missing, so callers fall back to their procedural _draw() instead of crashing.
## This is what makes the workflow "drop a PNG in the right folder and it appears".
##
## Folders:
##   res://assets/sprites/items/<id>.png        -> item icons
##   res://assets/sprites/<category>/<name>.png -> static sprites (resources, structures)
##   res://assets/sprites/<name>/<anim>_<i>.png -> animation frames (player, mobs, ...)

const SPRITES_DIR := "res://assets/sprites/"

var _tex_cache: Dictionary = {}
var _frames_cache: Dictionary = {}

## Generic, exists-checked, cached texture load. Returns null if absent.
func texture(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_tex_cache[path] = tex
	return tex

## Static sprite by category+name, e.g. sprite("resources", "tree").
func sprite(category: String, name: String) -> Texture2D:
	return texture(SPRITES_DIR + category + "/" + name + ".png")

## Item icon by item id, e.g. item_icon("wood").
func item_icon(id: String) -> Texture2D:
	return texture(SPRITES_DIR + "items/" + id + ".png")

## Build a SpriteFrames at runtime from convention-named PNG frames.
##   name  -> subfolder under sprites/ (e.g. "player", "boar")
##   specs -> Array of { "anim": String, "count": int, "fps": float, "loop": bool }
##            frames loaded from sprites/<name>/<anim>_<i>.png  (i = 0..count-1)
## Returns null if NO frame exists (caller then keeps procedural drawing).
func sprite_frames(name: String, specs: Array) -> SpriteFrames:
	if _frames_cache.has(name):
		return _frames_cache[name]
	var sf := SpriteFrames.new()
	var first := true
	var any := false
	for spec in specs:
		var anim: String = spec["anim"]
		if first:
			sf.rename_animation("default", anim)
			first = false
		elif not sf.has_animation(anim):
			sf.add_animation(anim)
		sf.set_animation_speed(anim, float(spec.get("fps", 8.0)))
		sf.set_animation_loop(anim, bool(spec.get("loop", true)))
		for i in int(spec.get("count", 1)):
			var tex := texture(SPRITES_DIR + "%s/%s_%d.png" % [name, anim, i])
			if tex:
				sf.add_frame(anim, tex)
				any = true
	var result: SpriteFrames = sf if any else null
	_frames_cache[name] = result
	return result
