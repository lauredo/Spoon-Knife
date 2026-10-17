class_name FloatText
extends Label

## Small world-space floating text (e.g. "+10 sanidade" when striking a shadow): rises and
## fades, then frees itself. Spawn via the static helper.

static func spawn(parent: Node, world_pos: Vector2, msg: String, color: Color = Color.WHITE) -> void:
	if parent == null:
		return
	var f := FloatText.new()
	f.text = msg
	f.z_index = 200
	f.z_as_relative = false
	f.add_theme_font_size_override("font_size", 12)
	f.add_theme_color_override("font_color", color)
	f.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	f.add_theme_constant_override("outline_size", 3)
	f.position = world_pos + Vector2(-28, -46)
	parent.add_child(f)
	var tw := f.create_tween()
	tw.tween_property(f, "position:y", f.position.y - 26.0, 0.9)
	var tw2 := f.create_tween()
	tw2.tween_property(f, "modulate:a", 0.0, 0.5).set_delay(0.4)
	tw2.tween_callback(f.queue_free)
