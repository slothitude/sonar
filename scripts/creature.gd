class_name Creature
extends Node2D
## THE DEEP'S DENIZENS (spec.systems.creatures). Two kinds:
##   LURKER  — idles below; when a ping fires it AGGRESES toward the ping
##             origin, bursting as it closes. Touch kills the sub.
##   DRIFTER — slow sine wander in a lane; a moving wall. Touch kills.
## Both obey the SonarVision visibility law (main drives alpha) PLUS a faint
## self-glow floor (Feel.CREATURE_GLOW_ALPHA): you JUST see them closing.
## Path math is pure/static so the battery can unit-test it.

enum Kind { LURKER, DRIFTER }

const TEXTURE_PATHS := {
	Kind.LURKER: "res://assets/generated/creature_lurker.png",
	Kind.DRIFTER: "res://assets/generated/creature_drifter.png",
}

var kind: int = Kind.DRIFTER
var sonar_id := ""
var anchor := Vector2.ZERO        # drifter lane anchor / lurker park spot
var aggro := false                # lurker: hunting the last ping origin
var aggro_target := Vector2.ZERO
var vel := Vector2.ZERO
var t := 0.0                      # local wander clock (reset = deterministic)
var active := true                # lurkers spawn parked until depth wakes them

var _dir := 1.0                   # drifter patrol direction
var _visual: Node2D


func _ready() -> void:
	_setup_visual()
	apply_visibility(0.0)


func _setup_visual() -> void:
	var path: String = TEXTURE_PATHS[kind]
	if ResourceLoader.exists(path):
		var spr := Sprite2D.new()
		var tex: Texture2D = load(path)
		spr.texture = tex
		var s := Feel.CREATURE_WIDTH_PX / float(tex.get_width())
		spr.scale = Vector2(s, s)
		_visual = spr
	else:
		# code-drawn fallback: never block on art
		var poly := Polygon2D.new()
		if kind == Kind.LURKER:
			poly.polygon = PackedVector2Array([Vector2(0, -26), Vector2(20, 6),
					Vector2(4, 14), Vector2(-18, 4)])
			poly.color = Color(0.75, 0.3, 0.42)
		else:
			poly.polygon = PackedVector2Array([Vector2(-22, 0), Vector2(-8, -14),
					Vector2(14, -4), Vector2(22, 8), Vector2(2, 14)])
			poly.color = Color(0.45, 0.72, 0.6)
		_visual = poly
	add_child(_visual)


## SonarVision law + self-glow floor. Main calls this every frame.
func apply_visibility(vis: float) -> void:
	modulate.a = clampf(maxf(vis, Feel.CREATURE_GLOW_ALPHA), 0.0, 1.0)


# ------------------------------------------------------------------ ping --

## A ping fired: lurkers home in on where it came from.
func on_ping(origin: Vector2) -> void:
	if kind != Kind.LURKER or not active:
		return
	if not aggro:
		anchor = position          # bob resumes around wherever it stopped
	aggro = true
	aggro_target = origin


## Depth woke it: surfaces at the bottom of the dark, beside the sub's column,
## and starts its idle drift (it rises when a ping calls it).
func wake(at: Vector2) -> void:
	active = true
	position = at
	anchor = at
	aggro = false
	vel = Vector2.ZERO


func park(at: Vector2) -> void:
	active = false
	position = at
	anchor = at
	aggro = false
	vel = Vector2.ZERO


# ------------------------------------------------------------------ tick --

func _physics_process(delta: float) -> void:
	if not active:
		return
	t += delta
	match kind:
		Kind.LURKER:
			_step_lurker(delta)
		Kind.DRIFTER:
			_step_drifter(delta)


func _step_lurker(delta: float) -> void:
	var to_target := aggro_target - position
	vel = step_lurker_velocity(vel, to_target, aggro, to_target.length(), delta)
	position += vel * delta
	if not aggro:
		position.y = anchor.y + bob_offset(t, Feel.LURKER_BOB_AMP, Feel.LURKER_BOB_FREQ)


func _step_drifter(delta: float) -> void:
	var res := step_drifter_x(position.x, _dir, delta,
			anchor.x - Feel.DRIFTER_LANE_HALF_W, anchor.x + Feel.DRIFTER_LANE_HALF_W)
	position.x = res[0]
	_dir = res[1]
	position.y = anchor.y + drifter_wave_y(t)


func touches_point(p: Vector2) -> bool:
	return position.distance_to(p) <= Feel.TOUCH_RADIUS


# ------------------------------------------------------- pure path math --

## Lurker steering: idle = bleed speed to a stop; aggro = accel toward the
## target, bursting (multiplied accel + higher cap) once inside close range.
static func step_lurker_velocity(vel: Vector2, to_target: Vector2,
		aggro: bool, dist: float, delta: float) -> Vector2:
	if not aggro:
		return vel.move_toward(Vector2.ZERO, Feel.LURKER_IDLE_DRAG * delta)
	var accel := Feel.LURKER_ACCEL
	var max_speed := Feel.LURKER_SPEED
	if dist < Feel.LURKER_CLOSE_RANGE:
		accel *= Feel.LURKER_CLOSE_BURST
		max_speed = Feel.LURKER_MAX_SPEED
	if to_target.length() > 0.01:
		vel += to_target.normalized() * accel * delta
	if vel.length() > max_speed:
		vel = vel.normalized() * max_speed
	return vel


static func bob_offset(t: float, amp: float, freq: float) -> float:
	return sin(t * freq) * amp


## Drifter sine bob — always inside its lane (|value| <= amp).
static func drifter_wave_y(t: float) -> float:
	return sin(t * Feel.DRIFTER_WAVE_FREQ) * Feel.DRIFTER_WAVE_AMP


## Drifter patrol: advances at DRIFTER_SPEED, bouncing off the lane walls.
## Returns [new_x, new_dir].
static func step_drifter_x(x: float, dir: float, delta: float,
		lane_min: float, lane_max: float) -> Array:
	x += dir * Feel.DRIFTER_SPEED * delta
	if x >= lane_max:
		x = lane_max
		dir = -1.0
	elif x <= lane_min:
		x = lane_min
		dir = 1.0
	return [x, dir]
