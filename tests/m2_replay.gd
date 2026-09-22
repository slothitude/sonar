extends SceneTree
## SONAR milestone-2 replay: two scripted 20s runs against the real scene.
##   CAREFUL  — pings early (luring lurkers to stale origins), dives a diagonal
##              to grab one wreck beacon, surfaces, refills air, hovers: survives.
##   RECKLESS — nose-down, no pings, straight past crush depth: the deep takes it.
## Gates: careful survives with its beacon, reckless dies to crush/creature,
## overlay behavior correct, positions finite, no errors, no soft-lock.
## Run: godot --headless --path . --script res://tests/m2_replay.gd

const DURATION := 20.0
const WALL_BUDGET_MS := 120000
const HOVER := Vector2(420, 80)   # far from every ping origin the diver leaves

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func check(name: String, cond: bool) -> void:
	if cond:
		_passed += 1
		print("  PASS  %s" % name)
	else:
		_failed += 1
		print("  FAIL  %s" % name)


func _run() -> void:
	await process_frame
	Engine.time_scale = 4.0
	await _careful_diver()
	await _reckless_diver()
	Engine.time_scale = 1.0
	print("")
	print("RESULT: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _spawn_main() -> Node2D:
	var main: Node2D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	return main


# ------------------------------------------------------------ careful --

func _careful_diver() -> void:
	print("[replay 20s: careful diver]")
	var main: Node2D = await _spawn_main()
	var player: Sub = main.player
	var sonar: SonarVision = player.sonar
	var survival: Survival = main._survival
	var pings := 0
	var pinged_mid := false
	var start_ms := Time.get_ticks_msec()

	while sonar.elapsed < DURATION and not survival.over:
		var target: Vector2 = main.BEACON_SPOTS[1] if survival.beacons == 0 else HOVER
		var to_target := target - player.position
		player.set_input_override(Vector2.ZERO if to_target.length() < 8.0
				else to_target.normalized())
		# ping early + once mid-run while still deep: every ping lures lurkers
		# to a STALE origin, never to the surface hover spot
		if sonar.can_ping() and (sonar.elapsed < 0.6
					or (sonar.elapsed > 3.0 and not pinged_mid
						and survival.depth > Feel.SURFACE_DEPTH_PX + 60.0)):
			if player.try_ping():
				pings += 1
				pinged_mid = sonar.elapsed > 3.0
		if Time.get_ticks_msec() - start_ms > WALL_BUDGET_MS:
			print("  FAIL  careful diver exceeded wall-clock budget (soft-lock)")
			quit(1)
			return
		await process_frame

	Engine.time_scale = 1.0
	print("  [careful] t=%.1fs beacons=%d air=%.1f pings=%d depth=%.0f end=%s" % [
			sonar.elapsed, survival.beacons, survival.air, pings,
			survival.depth, survival.end_reason])
	check("careful diver SURVIVES the 20s", not survival.over
			and sonar.elapsed >= DURATION)
	check("careful diver grabbed a wreck beacon", survival.beacons >= 1
			and survival.score >= Feel.BEACON_SCORE)
	check("careful diver still has air (refilled at the surface)",
			survival.air > 0.0 and survival.air_ratio() > 0.5)
	check("careful diver pinged on cadence (2+ pings, cooldown-honored)",
			pings >= 2 and sonar.ping_count >= pings and pings <= 5)
	check("careful diver stayed in bounds",
			player.position.x >= 0.0 and player.position.x <= Feel.VIEW_WIDTH
			and player.position.y >= 0.0 and player.position.y <= Feel.VIEW_HEIGHT)
	check("careful diver state stays finite",
			player.position.is_finite() and player.velocity.is_finite()
			and survival.depth >= 0.0)
	check("no death overlay on a living run",
			not (main._hud["overlay"] as ColorRect).visible
			and player.input_enabled)
	main.free()
	await process_frame
	Engine.time_scale = 4.0


# ------------------------------------------------------------ reckless --

func _reckless_diver() -> void:
	print("[replay: reckless diver]")
	var main: Node2D = await _spawn_main()
	var player: Sub = main.player
	var sonar: SonarVision = player.sonar
	var survival: Survival = main._survival
	var start_ms := Time.get_ticks_msec()

	player.set_input_override(Vector2(0, 1))   # nose down, never pings
	while not survival.over:
		if Time.get_ticks_msec() - start_ms > WALL_BUDGET_MS:
			print("  FAIL  reckless diver never died (soft-lock)")
			quit(1)
			return
		await process_frame

	Engine.time_scale = 1.0
	print("  [reckless] t=%.1fs depth=%.0f max=%.0f end=%s hull=%.1f" % [
			sonar.elapsed, survival.depth, survival.max_depth_reached,
			survival.end_reason, survival.hull])
	check("reckless diver DIES past crush depth with no pings",
			survival.over and not survival.won)
	check("reckless death is the deep's doing (crush, creature, or air)",
			survival.end_reason == "crush" or survival.end_reason == "creature"
			or survival.end_reason == "air")
	check("reckless dive blew past the no-beacon crush depth",
			survival.max_depth_reached > Feel.PRESSURE_MAX_DEPTH
			or survival.end_reason == "creature")
	check("death overlay is up and controls are frozen",
			(main._hud["overlay"] as ColorRect).visible
			and not player.input_enabled
			and (main._hud["overlay_title"] as Label).text == "THE DEEP TOOK YOU")
	check("reckless diver state stays finite", player.position.is_finite()
			and player.velocity.is_finite())
	main.free()
	await process_frame
