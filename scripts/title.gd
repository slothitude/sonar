extends Node2D
## THE TITLE — the fear-setting first scene (milestone 3).
## Black water, the title logo, slowly rising bubbles, a pulsing
## "TAP TO DIVE", and a faint lurker silhouette drifting past BEHIND the
## title (tree order: silhouette sits under the logo). Jam-necessary bits:
## "TFS Jam '26" + theme line "It Came From Below" + "DIVE N" (the next dive
## number, from the user:// save). Any tap — or SPACE — dives. The mute
## toggle lives here and persists through Save.

const LOGO_TEXTURE_PATH := "res://assets/generated/title_logo.png"
const LURKER_TEXTURE_PATH := "res://assets/generated/creature_lurker.png"
const WATER_TEXTURE_PATH := "res://assets/generated/tile_water_dark.png"
const GAME_SCENE := "res://scenes/main.tscn"

@onready var water: Sprite2D = $Water
@onready var silhouette: Sprite2D = $Silhouette
@onready var logo: Sprite2D = $Logo
@onready var bubbles: CPUParticles2D = $Bubbles
@onready var ui: CanvasLayer = $UI

var _t := 0.0
var _sfx: Sfx
var _hint: Label
var _dive_label: Label
var _mute_button: Button
var _starting := false


func _ready() -> void:
	_sfx = Sfx.new()
	add_child(_sfx)
	_setup_water()
	_setup_logo()
	_setup_silhouette()
	_setup_bubbles()
	_setup_ui()


func _setup_water() -> void:
	water.centered = true
	water.position = Vector2(Feel.VIEW_WIDTH, Feel.VIEW_HEIGHT) * 0.5
	water.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	water.region_enabled = true
	water.region_rect = Rect2(0.0, 0.0, Feel.VIEW_WIDTH + 360.0, Feel.VIEW_HEIGHT + 540.0)
	if ResourceLoader.exists(WATER_TEXTURE_PATH):
		water.texture = load(WATER_TEXTURE_PATH)
	else:
		water.texture = _make_water_texture()
	water.modulate = Color(0.26, 0.3, 0.38)   # even darker than the dive


## Code-drawn fallback water tile (never block on art).
func _make_water_texture() -> Texture2D:
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var n := 0.5 + 0.5 * sin(float(x) * 0.35 + float(y) * 0.21) * cos(float(y) * 0.17)
			var v := 0.02 + 0.04 * n
			img.set_pixel(x, y, Color(v * 0.7, v, v * 1.15))
	return ImageTexture.create_from_image(img)


func _setup_logo() -> void:
	logo.position = Vector2(Feel.VIEW_WIDTH * 0.5, 270.0)
	if ResourceLoader.exists(LOGO_TEXTURE_PATH):
		var tex: Texture2D = load(LOGO_TEXTURE_PATH)
		logo.texture = tex
		var s := Feel.TITLE_LOGO_WIDTH_PX / float(tex.get_width())
		logo.scale = Vector2(s, s)


## The faint lurker: bigger than life, barely there, drifting behind the title.
func _setup_silhouette() -> void:
	silhouette.position = Vector2(-120.0, 640.0)
	silhouette.modulate = Color(0.04, 0.07, 0.11, Feel.TITLE_SILHOUETTE_ALPHA)
	if ResourceLoader.exists(LURKER_TEXTURE_PATH):
		var tex: Texture2D = load(LURKER_TEXTURE_PATH)
		silhouette.texture = tex
		var s := Feel.CREATURE_WIDTH_PX * 2.4 / float(tex.get_width())
		silhouette.scale = Vector2(s, s)


func _setup_bubbles() -> void:
	bubbles.position = Vector2(Feel.VIEW_WIDTH * 0.5, Feel.VIEW_HEIGHT + 20.0)
	bubbles.emitting = true
	bubbles.local_coords = false
	bubbles.amount = int(Feel.TITLE_BUBBLE_RATE * 6.0)
	bubbles.lifetime = 6.0
	bubbles.preprocess = 6.0   # the sea is already alive on frame one
	bubbles.direction = Vector2(0, -1)
	bubbles.spread = 12.0
	bubbles.gravity = Vector2(0, -26)
	bubbles.initial_velocity_min = 30.0
	bubbles.initial_velocity_max = 90.0
	bubbles.scale_amount_min = 1.0
	bubbles.scale_amount_max = 3.4
	bubbles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	bubbles.emission_rect_extents = Vector2(Feel.VIEW_WIDTH * 0.5, 10.0)
	bubbles.color = Color(0.6, 0.85, 1.0, 0.3)


func _setup_ui() -> void:
	_theme_label(Feel.THEME_LINE, Vector2(0, 352), 22, Color(0.55, 0.8, 0.9, 0.9))
	_dive_label = _theme_label("", Vector2(0, 420), 18, Color(0.45, 0.7, 0.82, 0.9))
	_dive_label.text = "DIVE %d" % (Save.get_dives() + 1)
	_hint = _theme_label(Feel.TITLE_HINT, Vector2(0, 620), 28, Color(0.8, 0.96, 1.0))
	_hint.size = Vector2(Feel.VIEW_WIDTH, 40)
	_theme_label(Feel.VERSION_LINE, Vector2(0, Feel.VIEW_HEIGHT - 44), 15,
			Color(0.5, 0.72, 0.82, 0.75))

	_mute_button = Button.new()
	_mute_button.flat = true
	_mute_button.focus_mode = Control.FOCUS_NONE
	_mute_button.position = Vector2(Feel.VIEW_WIDTH * 0.5 - 90.0, Feel.VIEW_HEIGHT - 96.0)
	_mute_button.size = Vector2(180.0, 40.0)
	_mute_button.add_theme_font_size_override("font_size", 16)
	_mute_button.add_theme_color_override("font_color", Color(0.6, 0.85, 0.95))
	_sync_mute_text()
	_mute_button.pressed.connect(_on_mute_pressed)
	ui.add_child(_mute_button)


func _theme_label(text: String, pos: Vector2, font_size: int,
		color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = Vector2(Feel.VIEW_WIDTH, 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	ui.add_child(label)
	return label


func _sync_mute_text() -> void:
	_mute_button.text = "SOUND: OFF" if _sfx.muted else "SOUND: ON"


func _on_mute_pressed() -> void:
	_sfx.toggle_muted()
	_sync_mute_text()


func _process(delta: float) -> void:
	_t += delta
	var rr := water.region_rect
	rr.position.y += Feel.WATER_DRIFT_SPEED * delta
	water.region_rect = rr

	# the silhouette slides across behind the title, wrapping, gently bobbing
	var x := silhouette.position.x + Feel.TITLE_SILHOUETTE_SPEED * delta
	if x > Feel.VIEW_WIDTH + 160.0:
		x = -160.0
	silhouette.position.x = x
	silhouette.position.y = 640.0 + sin(_t * Feel.TITLE_SILHOUETTE_BOB_FREQ * TAU) \
			* Feel.TITLE_SILHOUETTE_BOB

	# "TAP TO DIVE" breathes
	_hint.modulate.a = Feel.TITLE_PULSE_MIN \
			+ (1.0 - Feel.TITLE_PULSE_MIN) * (0.5 + 0.5 * sin(_t * Feel.TITLE_PULSE_FREQ * TAU))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("sonar") \
			or (event is InputEventScreenTouch and event.pressed):
		_start_dive()


func _start_dive() -> void:
	if _starting:
		return
	_starting = true
	_sfx.play("gulp")
	get_tree().change_scene_to_file.call_deferred(GAME_SCENE)
