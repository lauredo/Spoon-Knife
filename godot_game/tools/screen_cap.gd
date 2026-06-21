extends Node
## TEMPORARY validation hook. Registered as an autoload, it waits for the world to spawn and
## render, captures the real rendered viewport to user://terrain_shot.png and quits. Run the
## game WINDOWED (not --headless, which has no renderer):
##   & "<godot4.7 gui exe>" --path godot_game --quit-after 600
## Remove the autoload + this file afterwards. (To validate movement/direction art or effects,
## drive GameManager.player / ResourceNodes before capturing. Pure logic checks like idle bob
## can sample node state over frames and print it -- that runs fine headless.)

func _ready() -> void:
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "user://terrain_shot.png"
	img.save_png(path)
	print("SCREENSHOT_SAVED=", ProjectSettings.globalize_path(path))
	get_tree().quit()
