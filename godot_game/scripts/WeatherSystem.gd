class_name WeatherSystem
extends Node

## Per-day weather so no two days feel the same. Rolls a condition at each dawn, announces it, and
## owns the screen overlays. Effects live where they belong (Campfire reads is_raining, ResourceNode
## gives rain berries, PlayerStats-adjacent fog unease is applied here). State is mirrored on
## GameManager so any system can read it without a reference.

const FOG_SANITY_DRAIN := 3.0  # per minute — a foggy day is quietly unsettling

var _overlay_layer: CanvasLayer
var _fog: TextureRect
var _rain: CPUParticles2D
var _rng := RandomNumberGenerator.new()

func setup() -> void:
	_rng.randomize()
	_build_overlays()
	GameManager.new_day.connect(_on_new_day)
	_roll_weather(true)  # day-1 weather

func _build_overlays() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 5  # above the world, below the HUD (10)
	add_child(_overlay_layer)

	# Fog: a radial haze — clear-ish around the player, thick toward the screen edges (short sight).
	_fog = TextureRect.new()
	_fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog.texture = _make_fog_texture()
	_fog.visible = false
	_overlay_layer.add_child(_fog)

	# Rain: thin pale streaks falling across the whole screen.
	_rain = CPUParticles2D.new()
	_rain.position = Vector2(640, -30)
	_rain.emitting = false
	_rain.amount = 150
	_rain.lifetime = 1.0
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(720, 8)
	_rain.direction = Vector2(0.15, 1)
	_rain.spread = 0.0
	_rain.gravity = Vector2(60, 900)
	_rain.initial_velocity_min = 700.0
	_rain.initial_velocity_max = 850.0
	_rain.scale_amount_min = 1.0
	_rain.scale_amount_max = 2.0
	_rain.color = Color(0.65, 0.72, 0.85, 0.55)
	_overlay_layer.add_child(_rain)

func _make_fog_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0.62, 0.64, 0.68, 0.0))
	g.set_color(1, Color(0.55, 0.57, 0.62, 0.6))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 256
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t

func _on_new_day(_day: int) -> void:
	_roll_weather(false)

## Weighted roll: clear is the calm baseline; fog/rain are the flavour days.
func _roll_weather(first: bool) -> void:
	var r := _rng.randf()
	if first:
		GameManager.weather = GameManager.WEATHER_CLEAR  # always start gently
	elif r < 0.5:
		GameManager.weather = GameManager.WEATHER_CLEAR
	elif r < 0.78:
		GameManager.weather = GameManager.WEATHER_RAIN
	else:
		GameManager.weather = GameManager.WEATHER_FOG
	_apply()

func _apply() -> void:
	_fog.visible = GameManager.is_foggy()
	_rain.emitting = GameManager.is_raining()
	if GameManager.hud and GameManager.hud.has_method("show_notification"):
		GameManager.hud.show_notification(_weather_text(), 3.5)

func _weather_text() -> String:
	match GameManager.weather:
		GameManager.WEATHER_RAIN: return "🌧 Chuva — a fogueira consome mais, mas os arbustos rendem mais"
		GameManager.WEATHER_FOG: return "🌫 Névoa — visão curta, algo inquieta a mente"
		_: return "☀ Céu limpo"

func _process(delta: float) -> void:
	# Fog quietly frays the nerves (small, applies day or night).
	if GameManager.is_foggy():
		var p = GameManager.player
		if p and is_instance_valid(p) and p.stats:
			p.stats.drain_sanity(FOG_SANITY_DRAIN / 60.0 * delta)
