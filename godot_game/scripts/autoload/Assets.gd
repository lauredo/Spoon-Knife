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
var _light_tex: GradientTexture2D = null
var _hit_shader: Shader = null

# Shared "hit flash" canvas_item shader: lerps a sprite toward `flash_color` by the `flash`
# uniform (0..1) while keeping its alpha — used for the white flash + solid-silhouette pop that
# plays when a tree/rock/bush/mob is struck. One Shader instance, reused by every hit effect.
const _HIT_SHADER_CODE: String = "shader_type canvas_item;\nuniform float flash : hint_range(0.0, 1.0) = 0.0;\nuniform vec4 flash_color : source_color = vec4(1.0);\nvoid fragment() {\n\tvec4 base = COLOR;\n\tvec4 tex = texture(TEXTURE, UV);\n\tvec3 rgb = mix(tex.rgb, flash_color.rgb, flash);\n\tCOLOR = vec4(rgb * base.rgb, tex.a * base.a);\n}\n"

func hit_shader() -> Shader:
	if _hit_shader == null:
		_hit_shader = Shader.new()
		_hit_shader.code = _HIT_SHADER_CODE
	return _hit_shader

## A soft radial light mask (white opaque centre → transparent edge) for PointLight2D, built once
## and cached. At texture_scale 1 the lit radius is ~128 px; scale it up per light source.
func light_texture() -> GradientTexture2D:
	if _light_tex != null:
		return _light_tex
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	_light_tex = tex
	return tex

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
