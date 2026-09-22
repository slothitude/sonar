class_name SonarVision
extends RefCounted
## THE mechanic (spec.systems.sonar): a player-triggered, cooldown-gated ping.
## A ring expands from the player over Feel.RING_EXPAND_TIME; each entity is
## revealed (visibility 1.0) the moment the ring reaches it — cinematic, not
## instant. The echo then holds Feel.REVEAL_TIME and fades to 0 over
## Feel.ECHO_FADE (total lifetime Feel.ECHO_TOTAL_TIME).
## Pure logic: dictionaries of entity id -> visibility. UI/scene code reads it.

var player_pos := Vector2.ZERO
var ping_count := 0
var elapsed := 0.0                 # total simulated time (sum of tick deltas)
var last_ping_origin := Vector2.ZERO   # creatures home in on this (milestone 2)

var _cooldown_left := 0.0
var _ring_time := -1.0             # < 0 = no active ping
var _positions := {}               # id -> Vector2
var _vis := {}                     # id -> float 0..1
var _echo_age := {}                # id -> s since the ring reached it
var _revealed_this_ping := {}      # id -> bool


# ------------------------------------------------------------- entities --

func register(id: String, pos: Vector2) -> void:
	_positions[id] = pos
	_vis[id] = 0.0
	_echo_age[id] = 0.0
	_revealed_this_ping[id] = false


func unregister(id: String) -> void:
	_positions.erase(id)
	_vis.erase(id)
	_echo_age.erase(id)
	_revealed_this_ping.erase(id)


func has_entity(id: String) -> bool:
	return _positions.has(id)


func set_entity_position(id: String, pos: Vector2) -> void:
	if _positions.has(id):
		_positions[id] = pos


func set_player_pos(pos: Vector2) -> void:
	player_pos = pos


func get_visibility(id: String) -> float:
	return float(_vis.get(id, 0.0))


## Brightest current echo across all entities (HUD/tests convenience).
func max_visibility() -> float:
	var best := 0.0
	for v in _vis.values():
		best = maxf(best, float(v))
	return best


# ------------------------------------------------------------------ ping --

func can_ping() -> bool:
	return _cooldown_left <= 0.0


func cooldown_remaining() -> float:
	return _cooldown_left


func ring_active() -> bool:
	return _ring_time >= 0.0


## 0..1 sweep progress of the active ring (0 when idle).
func ring_progress() -> float:
	if _ring_time < 0.0:
		return 0.0
	return clampf(_ring_time / Feel.RING_EXPAND_TIME, 0.0, 1.0)


## Current ring radius in px (0 when idle).
func ring_radius() -> float:
	if _ring_time < 0.0:
		return 0.0
	return Feel.SONAR_RADIUS * clampf(_ring_time / Feel.RING_EXPAND_TIME, 0.0, 1.0)


## Fire a ping. Returns false (no-op) while on cooldown.
func ping() -> bool:
	if not can_ping():
		return false
	_cooldown_left = Feel.PING_COOLDOWN
	_ring_time = 0.0
	ping_count += 1
	last_ping_origin = player_pos
	for id in _revealed_this_ping:
		_revealed_this_ping[id] = false
	return true


# ------------------------------------------------------------------ tick --

func tick(delta: float) -> void:
	elapsed += delta
	_cooldown_left = maxf(0.0, _cooldown_left - delta)

	if _ring_time >= 0.0:
		_ring_time += delta
		var r := ring_radius()
		# Reveal whatever the ring has just swept over.
		for id in _positions:
			if _revealed_this_ping.get(id, false):
				continue
			if player_pos.distance_to(_positions[id]) <= r:
				_revealed_this_ping[id] = true
				_echo_age[id] = 0.0
				_vis[id] = 1.0
		if _ring_time >= Feel.RING_EXPAND_TIME:
			_ring_time = -1.0

	# Echo decay runs on every revealed entity regardless of ring state:
	# full brightness for REVEAL_TIME, then linear fade over ECHO_FADE.
	for id in _positions:
		if not _revealed_this_ping.get(id, false):
			continue
		var age: float = float(_echo_age.get(id, 0.0)) + delta
		_echo_age[id] = age
		if age <= Feel.REVEAL_TIME:
			_vis[id] = 1.0
		else:
			_vis[id] = clampf(1.0 - (age - Feel.REVEAL_TIME) / Feel.ECHO_FADE, 0.0, 1.0)
