class_name CraftingMenu
extends CanvasLayer

var player: Player
var is_open: bool = false

var panel: Panel
var recipe_list: VBoxContainer
var title_label: Label
var close_btn: Button
var scroll: ScrollContainer

const PANEL_W := 320
const PANEL_H := 480

func _ready() -> void:
	_build_ui()
	hide_menu()

func _build_ui() -> void:
	panel = Panel.new()
	panel.size = Vector2(PANEL_W, PANEL_H)
	panel.position = Vector2(640 - PANEL_W * 0.5, 720 * 0.5 - PANEL_H * 0.5)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.06, 0.95)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.45, 0.35, 0.2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	title_label = Label.new()
	title_label.text = "Crafting"
	title_label.position = Vector2(12, 10)
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	panel.add_child(title_label)

	close_btn = Button.new()
	close_btn.text = "X"
	close_btn.size = Vector2(28, 28)
	close_btn.position = Vector2(PANEL_W - 36, 8)
	close_btn.pressed.connect(hide_menu)
	panel.add_child(close_btn)

	# Separator line
	var sep := ColorRect.new()
	sep.color = Color(0.35, 0.28, 0.18)
	sep.size = Vector2(PANEL_W - 12, 2)
	sep.position = Vector2(6, 40)
	panel.add_child(sep)

	scroll = ScrollContainer.new()
	scroll.position = Vector2(6, 48)
	scroll.size = Vector2(PANEL_W - 12, PANEL_H - 60)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(scroll)

	recipe_list = VBoxContainer.new()
	recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(recipe_list)

func setup(p: Player) -> void:
	player = p

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("open_crafting"):
		if is_open:
			hide_menu()
		else:
			show_menu()

func show_menu() -> void:
	is_open = true
	panel.visible = true
	_refresh_recipes()

func hide_menu() -> void:
	is_open = false
	panel.visible = false

func _refresh_recipes() -> void:
	for child in recipe_list.get_children():
		child.queue_free()

	if not player:
		return

	var near_structures := GameManager.get_nearby_structures(player.global_position, 150.0)
	var all_recipes := CraftingSystem.get_all_recipes()

	# Group by category
	var categories := {}
	for recipe in all_recipes:
		if not recipe.category in categories:
			categories[recipe.category] = []
		categories[recipe.category].append(recipe)

	for category in categories:
		# Category header
		var cat_label := Label.new()
		cat_label.text = category.capitalize()
		cat_label.add_theme_font_size_override("font_size", 13)
		cat_label.add_theme_color_override("font_color", Color(0.75, 0.65, 0.4))
		recipe_list.add_child(cat_label)

		for recipe in categories[category]:
			_add_recipe_row(recipe, near_structures)

		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 6)
		recipe_list.add_child(spacer)

func _add_recipe_row(recipe, near_structures: Array) -> void:
	var can_craft := CraftingSystem.can_craft(recipe, player.inventory.items, near_structures)
	var result_data = ItemDatabase.get_item(recipe.result_item)

	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(PANEL_W - 24, 44)
	recipe_list.add_child(row)

	# Item icon (fallback to color swatch when no sprite exists)
	var icon := Assets.item_icon(recipe.result_item)
	if icon:
		var tr := TextureRect.new()
		tr.texture = icon
		tr.custom_minimum_size = Vector2(36, 36)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(tr)
	else:
		var swatch := ColorRect.new()
		swatch.color = result_data.color if result_data else Color(0.5, 0.5, 0.5)
		swatch.custom_minimum_size = Vector2(36, 36)
		row.add_child(swatch)

	# Item info
	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_col)

	var name_label := Label.new()
	name_label.text = result_data.display_name if result_data else recipe.result_item
	name_label.add_theme_font_size_override("font_size", 13)
	var name_color := Color(0.95, 0.92, 0.85) if can_craft else Color(0.5, 0.5, 0.5)
	name_label.add_theme_color_override("font_color", name_color)
	info_col.add_child(name_label)

	# Ingredients
	var ingredients_text := ""
	for item_id in recipe.ingredients:
		var required: int = recipe.ingredients[item_id]
		var have: int = player.inventory.get_count(item_id)
		var ing_data = ItemDatabase.get_item(item_id)
		var ing_name: String = ing_data.display_name if ing_data else str(item_id)
		ingredients_text += "%s %d/%d  " % [ing_name, have, required]

	if recipe.requires_structure != "":
		ingredients_text += "[needs %s]" % recipe.requires_structure

	var ing_label := Label.new()
	ing_label.text = ingredients_text
	ing_label.add_theme_font_size_override("font_size", 10)
	ing_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65))
	info_col.add_child(ing_label)

	# Craft button
	var craft_btn := Button.new()
	craft_btn.text = "Craft"
	craft_btn.disabled = not can_craft
	craft_btn.custom_minimum_size = Vector2(55, 36)
	craft_btn.pressed.connect(_on_craft_pressed.bind(recipe))
	row.add_child(craft_btn)

	# Separator
	var sep := ColorRect.new()
	sep.color = Color(0.2, 0.18, 0.15, 0.5)
	sep.custom_minimum_size = Vector2(0, 1)
	recipe_list.add_child(sep)

func _on_craft_pressed(recipe) -> void:
	if not player:
		return
	var near_structures := GameManager.get_nearby_structures(player.global_position, 150.0)
	if not CraftingSystem.can_craft(recipe, player.inventory.items, near_structures):
		return

	var new_inventory := CraftingSystem.apply_craft(recipe, player.inventory.items)
	player.inventory.apply_crafting_result(new_inventory)

	# If it's a structure, place it near the player
	var result_data = ItemDatabase.get_item(recipe.result_item)
	if result_data and result_data.type == ItemDatabase.ItemType.STRUCTURE:
		if player.inventory.has_item(recipe.result_item):
			# Remove from inventory and place in world
			player.inventory.remove_item(recipe.result_item, 1)
			var place_pos := player.global_position + player.facing * 80.0
			GameManager.world.get_node("WorldGenerator").place_structure(recipe.result_item, place_pos, player)

	_refresh_recipes()
