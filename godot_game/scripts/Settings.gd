extends Node

## Autoload. Holds the player's options (fullscreen, master volume), applies them to the
## engine, and persists them to user://settings.cfg so they survive across runs. Loaded once
## at startup; the SettingsMenu reads/writes through here.

const PATH := "user://settings.cfg"

var fullscreen: bool = false
var master_volume: float = 1.0  # linear 0..1
# Accessibility: 0 = the designed (very dark) night; 1 = up to 50% less darkness.
# Read every frame by DayNightCycle._update_darkness — no apply step needed.
var night_brightness: float = 0.0

func _ready() -> void:
	load_settings()
	apply_all()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return  # no file yet — keep defaults
	fullscreen = cfg.get_value("video", "fullscreen", false)
	master_volume = clampf(cfg.get_value("audio", "master_volume", 1.0), 0.0, 1.0)
	night_brightness = clampf(cfg.get_value("video", "night_brightness", 0.0), 0.0, 1.0)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "night_brightness", night_brightness)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.save(PATH)

func apply_all() -> void:
	apply_fullscreen()
	apply_master_volume()

func set_fullscreen(v: bool) -> void:
	fullscreen = v
	apply_fullscreen()
	save_settings()

func apply_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	apply_master_volume()
	save_settings()

func set_night_brightness(v: float) -> void:
	night_brightness = clampf(v, 0.0, 1.0)
	save_settings()

func apply_master_volume() -> void:
	# Master is always bus 0. Below ~0 treat as silence rather than a huge negative dB.
	var db: float = linear_to_db(master_volume) if master_volume > 0.001 else -80.0
	AudioServer.set_bus_volume_db(0, db)
