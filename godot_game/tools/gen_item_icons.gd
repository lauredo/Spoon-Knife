extends SceneTree
## One-off generator: writes an editable SVG per item to assets/_svg_src/items/.
## Skips files that already exist (so your hand-edits are never overwritten).
## Colors come from ItemDatabase, so icons match item colors automatically.
##   & "<godot4.7>" --headless --path godot_game -s res://tools/gen_item_icons.gd
## Then run tools/build_assets.gd to rasterize to PNG.

const OUT := "res://assets/_svg_src/items/"
var _done := false

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)

func _process(_d: float) -> bool:
	if _done:
		return true
	_done = true
	var db = get_root().get_node_or_null("ItemDatabase")
	if db == null:
		print("ERROR: no ItemDatabase autoload")
		return true
	var n := 0
	for id in db.items:
		var item = db.items[id]
		var path := OUT + str(id) + ".svg"
		if FileAccess.file_exists(path):
			continue
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(_icon(str(id), int(item.type), item.color))
		f.close()
		n += 1
	print("GEN_ITEM_ICONS DONE wrote=", n)
	return true

func _hex(c: Color) -> String:
	return "#" + c.to_html(false)

func _icon(id: String, type: int, color: Color) -> String:
	var c := _hex(color)
	var d := _hex(color.darkened(0.4))
	var l := _hex(color.lightened(0.4))
	var inner := ""
	match id:
		"wood", "twig": inner = _logs(c, d, l)
		"berries", "cooked_berries": inner = _berries(c, d, l)
		"meat", "monster_meat", "cooked_meat": inner = _meat(c, d, l)
		"rope": inner = _coil(c, d)
		"silk": inner = _strands(c)
		"seeds": inner = _seeds(c, d)
		"torch": inner = _torch()
		"campfire": inner = _campfire()
		"chest": inner = _box(c, d, l)
		_:
			match type:
				1: inner = _tool(c, d)        # TOOL
				4: inner = _weapon(c, d)      # WEAPON
				2: inner = _blob(c, d, l)     # FOOD
				3: inner = _box(c, d, l)      # STRUCTURE
				_: inner = _gem(c, d, l)      # RESOURCE / default
	return '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">' + inner + '</svg>'

func _gem(c: String, d: String, l: String) -> String:
	return '<polygon points="32,8 54,28 32,58 10,28" fill="%s" stroke="%s" stroke-width="2.5" stroke-linejoin="round"/><polygon points="32,8 54,28 32,30 10,28" fill="%s" opacity="0.55"/>' % [c, d, l]

func _logs(c: String, d: String, l: String) -> String:
	return '<rect x="10" y="22" width="44" height="14" rx="7" fill="%s" stroke="%s" stroke-width="2"/><rect x="10" y="37" width="44" height="14" rx="7" fill="%s" stroke="%s" stroke-width="2"/><ellipse cx="15" cy="29" rx="4" ry="6" fill="%s"/><ellipse cx="15" cy="44" rx="4" ry="6" fill="%s"/>' % [c, d, c, d, l, l]

func _berries(c: String, d: String, l: String) -> String:
	return '<path d="M30 20 q4 -8 11 -6" stroke="#3a7d2c" stroke-width="3" fill="none" stroke-linecap="round"/><circle cx="24" cy="38" r="11" fill="%s" stroke="%s" stroke-width="2"/><circle cx="41" cy="35" r="11" fill="%s" stroke="%s" stroke-width="2"/><circle cx="33" cy="48" r="11" fill="%s" stroke="%s" stroke-width="2"/><circle cx="21" cy="34" r="3" fill="%s"/>' % [c, d, c, d, c, d, l]

func _meat(c: String, d: String, l: String) -> String:
	return '<ellipse cx="29" cy="37" rx="18" ry="15" fill="%s" stroke="%s" stroke-width="2"/><ellipse cx="25" cy="31" rx="6" ry="4" fill="%s" opacity="0.6"/><circle cx="48" cy="45" r="5" fill="#f3ead2" stroke="#cbbf9c" stroke-width="1.5"/>' % [c, d, l]

func _coil(c: String, d: String) -> String:
	return '<ellipse cx="32" cy="36" rx="20" ry="16" fill="none" stroke="%s" stroke-width="9"/><ellipse cx="32" cy="36" rx="20" ry="16" fill="none" stroke="%s" stroke-width="3" stroke-dasharray="5 6"/>' % [c, d]

func _strands(c: String) -> String:
	return '<g stroke="%s" stroke-width="4" fill="none" stroke-linecap="round"><path d="M20 12 q6 20 0 40"/><path d="M32 12 q-6 20 0 40"/><path d="M44 12 q6 20 0 40"/></g>' % [c]

func _seeds(c: String, d: String) -> String:
	return '<g fill="%s" stroke="%s" stroke-width="1.5"><ellipse cx="24" cy="30" rx="5" ry="7" transform="rotate(-20 24 30)"/><ellipse cx="41" cy="28" rx="5" ry="7" transform="rotate(15 41 28)"/><ellipse cx="32" cy="43" rx="5" ry="7"/><ellipse cx="44" cy="43" rx="4" ry="6" transform="rotate(25 44 43)"/></g>' % [c, d]

func _tool(c: String, d: String) -> String:
	return '<rect x="29" y="14" width="6" height="40" rx="3" fill="#7a5230"/><path d="M30 16 q15 -6 19 9 q-11 2 -19 -1 z" fill="%s" stroke="%s" stroke-width="2" stroke-linejoin="round"/>' % [c, d]

func _weapon(c: String, d: String) -> String:
	return '<rect x="29" y="22" width="6" height="34" rx="3" fill="#7a5230"/><polygon points="32,6 41,23 32,27 23,23" fill="%s" stroke="%s" stroke-width="2" stroke-linejoin="round"/>' % [c, d]

func _blob(c: String, d: String, l: String) -> String:
	return '<circle cx="32" cy="34" r="18" fill="%s" stroke="%s" stroke-width="2"/><ellipse cx="26" cy="28" rx="6" ry="4" fill="%s" opacity="0.6"/>' % [c, d, l]

func _box(c: String, d: String, l: String) -> String:
	return '<rect x="12" y="27" width="40" height="25" rx="3" fill="%s" stroke="%s" stroke-width="2"/><rect x="12" y="19" width="40" height="13" rx="3" fill="%s" stroke="%s" stroke-width="2"/><rect x="28" y="29" width="8" height="9" rx="1" fill="#caa14a" stroke="#6e5018" stroke-width="1.5"/>' % [c, d, l, d]

func _torch() -> String:
	return '<rect x="29" y="28" width="6" height="28" rx="3" fill="#7a5230"/><path d="M32 8 q11 10 5 21 q-2 7 -10 4 q-9 -3 -4 -13 q3 -7 9 -12 z" fill="#ff9a2e"/><path d="M32 17 q5 6 1 14 q-4 3 -7 -2 q-2 -5 6 -12 z" fill="#ffd24a"/>'

func _campfire() -> String:
	return '<g stroke="#5c3818" stroke-width="6" stroke-linecap="round"><line x1="16" y1="49" x2="48" y2="45"/><line x1="16" y1="45" x2="48" y2="49"/></g><path d="M32 12 q12 12 5 25 q-2 7 -10 5 q-9 -3 -4 -14 q3 -8 9 -16 z" fill="#ff7a1e"/><path d="M32 21 q6 7 2 16 q-4 3 -8 -2 q-3 -6 6 -14 z" fill="#ffd24a"/>'
