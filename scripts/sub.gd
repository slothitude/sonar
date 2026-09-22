class_name Sub
extends CharacterBody2D
## The player submarine (spec.systems.movement): glide movement + the sonar
## trigger. ALL steering flows through the tilt_source pipeline (spec law
## "injectable_input"); tests inject via set_input_override().

var sonar: SonarVision = SonarVision.new()
var tilt: TiltSource = TiltSource.new()
var bounds := Rect2(0.0, 0.0, Feel.VIEW_WIDTH, Feel.VIEW_HEIGHT)

var _input_override := Vector2.ZERO
var _use_override := false
var _touch_active := false
var _touch_anchor_y := 0.0
var _touch_y := 0.0
var _has_texture := false

@onready var _sprite: Sprite2D = $Sprite
@onready var _bubbles: CPUParticles2D = $Bubbles


func _ready() -> void:
	# Default mode is touch (drag anywhere steers) — that is the web default
	# per spec; device tilt is for mobile builds. Desktop keeps touch so a
	# mouse drag steers too, with keyboard as the primary desktop input.
	var default_mode := TiltSource.MODE_TOUCH
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		default_mode = TiltSource.MODE_DEVICE
	tilt.set_mode(default_mode)
	_setup_sprite()
	_setup_bubbles()


func _setup_sprite() -> void:
	# Use generated art if present, else code-drawn placeholder. Never block.
	if ResourceLoader.exists("res://assets/generated/sub_player.png"):
		var tex: Texture2D = load("res://assets/generated/sub_player.png")
		_sprite.texture = tex
		var s := Feel.SUB_WIDTH_PX / float(tex.get_width())
		_sprite.scale = Vector2(s, s)
		_has_texture = true
	else:
		_sprite.visible = false


func _setup_bubbles() -> void:
	_bubbles.emitting = false
	_bubbles.local_coords = false
	_bubbles.direction = Vector2(0, -1)   # bubbles rise
	_bubbles.spread = 35.0
	_bubbles.gravity = Vector2(0, -140)
	_bubbles.initial_velocity_min = 20.0
	_bubbles.initial_velocity_max = 55.0
	_bubbles.scale_amount_min = 1.0
	_bubbles.scale_amount_max = 3.0
	_bubbles.color = Color(0.65, 0.9, 1.0, 0.55)


func _physics_process(delta: float) -> void:
	var input_vec := gather_input()
	velocity = step_velocity(velocity, input_vec, delta)
	move_and_slide()
	position = clamp_to_bounds(position, bounds, Feel.BOUNDS_MARGIN)
	_bubbles.emitting = velocity.length() > 20.0


func _draw() -> void:
	if _has_texture:
		return
	# Code-drawn placeholder sub (art may not exist yet; never block on art).
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.62))
	draw_circle(Vector2.ZERO, 26.0, Color(0.35, 0.5, 0.62))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(-6, -34, 12, 16), Color(0.3, 0.44, 0.55))
	draw_circle(Vector2(12, -2), 4.5, Color(0.75, 0.95, 1.0))


## Input resolution: test override > keyboard > tilt/drag pipeline.
func gather_input() -> Vector2:
	if _use_override:
		return _input_override
	var kx := Input.get_axis("move_left", "move_right")
	var ky := Input.get_axis("move_up", "move_down")
	if absf(kx) > 0.01 or absf(ky) > 0.01:
		return Vector2(kx, ky)
	var v := Vector2(tilt.read_output(), 0.0)
	if _touch_active:
		v.y = clampf((_touch_y - _touch_anchor_y) / Feel.TOUCH_DRAG_RANGE_PX, -1.0, 1.0)
	return v


## Glide math — pure so the battery can unit-test it (spec.systems.movement):
## accel toward input, then drag, then clamp.
static func step_velocity(vel: Vector2, input_vec: Vector2, delta: float) -> Vector2:
	vel += input_vec * Feel.GLIDE_ACCEL * delta
	vel *= Feel.DRAG
	if vel.length() > Feel.MAX_SPEED:
		vel = vel.normalized() * Feel.MAX_SPEED
	return vel


static func clamp_to_bounds(pos: Vector2, rect: Rect2, margin: float) -> Vector2:
	return Vector2(
		clampf(pos.x, rect.position.x + margin, rect.end.x - margin),
		clampf(pos.y, rect.position.y + margin, rect.end.y - margin)
	)


## Player-triggered, cooldown-gated — the gating lives in SonarVision.
func try_ping() -> bool:
	return sonar.ping()


func set_input_override(v: Vector2) -> void:
	_input_override = v
	_use_override = true


func clear_input_override() -> void:
	_use_override = false


## Touch feeders — x flows through the tilt pipeline, y is raw drag delta.
func touch_begin(pos: Vector2) -> void:
	_touch_active = true
	_touch_anchor_y = pos.y
	_touch_y = pos.y
	tilt.touch_begin(pos.x)


func touch_move(pos: Vector2) -> void:
	_touch_y = pos.y
	tilt.touch_move(pos.x)


func touch_end() -> void:
	_touch_active = false
	_touch_anchor_y = 0.0
	_touch_y = 0.0
	tilt.touch_end()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_begin(event.position)
		else:
			touch_end()
	elif event is InputEventScreenDrag:
		touch_move(event.position)
	elif event.is_action_pressed("sonar"):
		try_ping()
