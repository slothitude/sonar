extends SceneTree
## SONAR milestone-3 replay: THE FULL JOURNEY against the real scenes.
##   title (DIVE 1, hint, silhouette) -> dive -> a sonar ping from a spot the
##   route never revisits -> three wreck beacons (b0 -> b2 -> b1, staying
##   clear of the drifter lanes and the ping origin's lurker) -> surface
##   -> win overlay with the tally revealing line by line -> retry (reset)
##   -> back to the title showing DIVE 2. No errors end to end, no soft-lock.
## Run: godot --headless --path . --script res://tests/m3_replay.gd

const WALL_BUDGET_MS := 120000
const WAYPOINT_RADIUS := 30.0
const SURFACE_TARGET := Vector2(270, 80)   # depth 40 — under SURFACE_DEPTH_PX

const ROUTE: Array[Vector2] = [
	Vector2(250, 770),   # beacon_0
	Vector2(430, 915),   # beacon_2 (deep right — passes under the drifter lane)
	Vector2(105, 880),   # beacon_1
	Vector2(270, 880),   # center the column for the ascent
	Vector2(270, 60),    # surface (depth 20 — the run is won mid-leg here)
]

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
	Save.reset()   # deterministic: this is DIVE 1
	Engine.time_scale = 4.0
	var start_ms := Time.get_ticks_msec()

	# ---- title ----
	var title: Node2D = (load("res://scenes/title.tscn") as PackedScene).instantiate()
	root.add_child(title)
	for i in 3:
		await process_frame
	check("title opens the journey: DIVE 1 + TAP TO DIVE, silhouette adrift",
			title._dive_label.text == "DIVE 1"
			and title._hint.text == Feel.TITLE_HINT
			and title.silhouette != null and title.bubbles.emitting)
	title.free()
	await process_frame

	# ---- dive ----
	var main: Node2D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)   # what the title's start loads; dives=0 -> attempt 0
	await process_frame
	await process_frame
	var player: Sub = main.player
	var sonar: SonarVision = player.sonar
	var survival: Survival = main._survival

	# a lead-in to the right, then THE ping — the origin (upper right) is a
	# spot the whole route below never comes near
	player.set_input_override(Vector2(1, 0))
	var lead_start := sonar.elapsed
	while sonar.elapsed - lead_start < 1.2 and not survival.over:
		if Time.get_ticks_msec() - start_ms > WALL_BUDGET_MS:
			break
		await process_frame
	var pings := 0
	if player.try_ping():
		pings += 1
	check("the dive opens with a sonar ping", pings == 1 and sonar.ping_count == 1)

	# ---- beacons + surface, waypoint by waypoint ----
	var wp := 0
	while wp < ROUTE.size() and not survival.over:
		var target := ROUTE[wp]
		var to_target := target - player.position
		player.set_input_override(Vector2.ZERO
				if (to_target.length() < WAYPOINT_RADIUS
						or (wp == ROUTE.size() - 1 and player.position.y <= target.y + 4.0))
				else to_target.normalized())
		if to_target.length() < WAYPOINT_RADIUS:
			wp += 1
		if Time.get_ticks_msec() - start_ms > WALL_BUDGET_MS:
			print("  FAIL  journey exceeded wall-clock budget (soft-lock)")
			quit(1)
			return
		await process_frame
	Engine.time_scale = 1.0
	print("  [journey] t=%.1fs beacons=%d pings=%d depth=%.0f air=%.1f end=%s" % [
			sonar.elapsed, survival.beacons, pings, survival.depth,
			survival.air, survival.end_reason])
	check("the diver reached the surface alive with all 3 beacons",
			survival.over and survival.won and survival.beacons == 3
			and survival.end_reason == "surfaced")
	check("exactly the opening ping was spent (the deep never got a lure home)",
			sonar.ping_count == 1)
	check("the whole journey stayed finite and in bounds",
			player.position.is_finite() and player.velocity.is_finite()
			and player.position.x >= 0.0 and player.position.x <= Feel.VIEW_WIDTH
			and player.position.y >= 0.0 and player.position.y <= Feel.VIEW_HEIGHT)

	# ---- win overlay: tally lines reveal one by one ----
	check("win overlay is up and controls are frozen",
			(main._hud["overlay"] as ColorRect).visible
			and not player.input_enabled
			and (main._hud["overlay_title"] as Label).text == "YOU SURFACED")
	await create_timer(Feel.TALLY_LINE_STEP * 3.0 + Feel.TALLY_FADE + 0.35).timeout
	var tally_in: bool = main._tally_lines.size() == 4
	for line in main._tally_lines:
		if line.modulate.a < 0.99 or line.text == "":
			tally_in = false
	check("the tally breakdown fully revealed line by line", tally_in)

	# ---- retry (the overlay's TAP/SPACE law): a real SPACE press ----
	var tap := InputEventKey.new()
	tap.physical_keycode = KEY_SPACE
	tap.pressed = true
	Input.parse_input_event(tap)
	for i in 4:
		await process_frame
	await physics_frame
	check("retry from the overlay resets the run (overlay down, world re-armed)",
			not survival.over and survival.beacons == 0 and survival.air > 55.0
			and not (main._hud["overlay"] as ColorRect).visible
			and player.input_enabled and player.sonar.ping_count == 0
			and player.position.distance_to(Feel.SUB_HOME) < 2.0)
	root.remove_child(main)
	main.free()
	await process_frame

	# ---- back to the title: the win was logged as DIVE 1 ----
	var title2: Node2D = (load("res://scenes/title.tscn") as PackedScene).instantiate()
	root.add_child(title2)
	for i in 3:
		await process_frame
	check("back at the title, the log reads DIVE 2", title2._dive_label.text == "DIVE 2")
	title2.free()
	await process_frame

	print("")
	print("RESULT: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
