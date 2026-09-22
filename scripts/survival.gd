class_name Survival
extends RefCounted
## THE SURVIVAL LOOP (spec.systems.survival + goal). Air drains with time and
## drains FASTER DEEP; pressure crushes the hull past the effective max depth
## (extended by each beacon); the surface refills air. Beacons score and push
## the crush depth back. All 3 beacons + surfaced = RUN WON with a tally.
## Pure logic + signals; main.gd feeds depth and touch deaths.

signal run_over(won: bool, reason: String)
signal beacon_collected(count: int)

var elapsed := 0.0
var air := Feel.AIR_SECONDS
var hull := Feel.HULL_HP
var beacons := 0
var score := 0                # running score (beacons); bonuses land in tally()
var depth := 0.0              # px below Feel.SURFACE_LINE_Y, fed by main
var max_depth_reached := 0.0
var over := false
var won := false
var end_reason := ""


func reset() -> void:
	elapsed = 0.0
	air = Feel.AIR_SECONDS
	hull = Feel.HULL_HP
	beacons = 0
	score = 0
	depth = 0.0
	max_depth_reached = 0.0
	over = false
	won = false
	end_reason = ""


# ----------------------------------------------------------------- laws --

## Crush depth grows by BEACON_DEPTH_EXTENSION per beacon collected.
func effective_max_depth() -> float:
	return Feel.PRESSURE_MAX_DEPTH + float(beacons) * Feel.BEACON_DEPTH_EXTENSION


func in_crush() -> bool:
	return depth > effective_max_depth()


func surfaced() -> bool:
	return depth <= Feel.SURFACE_DEPTH_PX


func air_ratio() -> float:
	return clampf(air / Feel.AIR_SECONDS, 0.0, 1.0)


## Air drain per second at the current depth (surface refill excluded).
func drain_rate() -> float:
	return Feel.AIR_DRAIN_RATE * (1.0 + depth / Feel.AIR_DEPTH_PENALTY_PX)


# ------------------------------------------------------------------ tick --

func tick(delta: float) -> void:
	if over:
		return
	elapsed += delta
	max_depth_reached = maxf(max_depth_reached, depth)

	if surfaced():
		air = minf(air + Feel.SURFACE_REFILL_RATE * delta, Feel.AIR_SECONDS)
	else:
		air -= drain_rate() * delta
	if air <= 0.0:
		air = 0.0
		_end(false, "air")
		return

	if beacons >= Feel.BEACONS_REQUIRED and surfaced():
		_end(true, "surfaced")
		return

	if in_crush():
		hull = maxf(0.0, hull - Feel.CRUSH_DAMAGE_PER_S * delta)
		if hull <= 0.0:
			_end(false, "crush")


# --------------------------------------------------------------- beacons --

func collect_beacon() -> void:
	if over:
		return
	beacons += 1
	score += Feel.BEACON_SCORE
	air = minf(air + Feel.BEACON_AIR_TOPUP, Feel.AIR_SECONDS)
	beacon_collected.emit(beacons)


## A creature found the hull.
func kill(reason: String) -> void:
	_end(false, reason)


## Final tally (spec goal): beacons*1000 + depth record + air bonus.
func tally() -> Dictionary:
	var depth_bonus := int(max_depth_reached * Feel.DEPTH_BONUS_PER_PX)
	var air_bonus := int(maxf(air, 0.0) * Feel.AIR_BONUS_PER_S)
	var beacon_score := beacons * Feel.BEACON_SCORE
	return {
		"beacons": beacons,
		"beacon_score": beacon_score,
		"depth_record": int(max_depth_reached),
		"depth_bonus": depth_bonus,
		"air_bonus": air_bonus,
		"score": beacon_score + depth_bonus + air_bonus,
	}


# ------------------------------------------------------------------ end --

func _end(w: bool, reason: String) -> void:
	if over:
		return
	over = true
	won = w
	end_reason = reason
	if w:
		score = tally()["score"]
	run_over.emit(w, reason)
