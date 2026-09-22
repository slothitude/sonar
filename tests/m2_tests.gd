extends SceneTree
## SONAR milestone-2 battery (spec law "growing_battery").
## Creatures (lurker aggro + burst, drifter lane), sonar law + self-glow,
## touch kills, survival (air/pressure/surface), beacons, run won, retry.
## Run: godot --headless --path . --script res://tests/m2_tests.gd

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_test_lurker_path()
	_test_drifter_lane()
	await _test_creature_reveal_and_chase()
	_test_air_and_pressure()
	_test_beacons_and_run_over()
	await _test_scene_loop()
	print("")
	print("RESULT: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func check(name: String, cond: bool) -> void:
	if cond:
		_passed += 1
		print("  PASS  %s" % name)
	else:
		_failed += 1
		print("  FAIL  %s" % name)


func advance(s: SonarVision, seconds: float, step := 0.05) -> void:
	var t := 0.0
	while t < seconds - 1e-9:
		var d := minf(step, seconds - t)
		s.tick(d)
		t += d


func fresh_sonar() -> SonarVision:
	var s := SonarVision.new()
	s.register("sub", Vector2.ZERO)
	return s


# -------------------------------------------------------- creature paths --

func _test_lurker_path() -> void:
	print("[lurker aggro path]")
	var to_far := Vector2(300, 400)          # 500px away — cruise
	var to_close := Vector2(60, 80)          # 100px away — inside burst range
	var far_vel := Creature.step_lurker_velocity(Vector2.ZERO, to_far, true, to_far.length(), 1.0 / 60.0)
	var close_vel := Creature.step_lurker_velocity(Vector2.ZERO, to_close, true, to_close.length(), 1.0 / 60.0)
	check("aggro lurker steers toward the ping origin",
			far_vel.normalized().dot(to_far.normalized()) > 0.99)
	check("lurker accelerates in close range (burst)",
			close_vel.length() > far_vel.length() * 1.5)
	var stopped := Vector2(120, 40)
	for i in 120:
		stopped = Creature.step_lurker_velocity(stopped, Vector2.ZERO, false, 0.0, 1.0 / 60.0)
	check("idle lurker (no ping) drifts to a stop", stopped.length() < 0.5)
	var chased := Vector2(600, 0)
	var vel := Vector2.ZERO
	for i in 240:   # 4s homing on a fixed origin
		vel = Creature.step_lurker_velocity(vel, -chased, true, chased.length(), 1.0 / 60.0)
		chased += vel * (1.0 / 60.0)
	check("lurker closes on the ping origin over time", chased.length() < 200.0)


func _test_drifter_lane() -> void:
	print("[drifter sine lane]")
	var peak := 0.0
	var moved := false
	var last := Creature.drifter_wave_y(0.0)
	for i in 600:
		var y := Creature.drifter_wave_y(float(i) * 0.1)
		peak = maxf(peak, absf(y))
		if absf(y - last) > 0.001:
			moved = true
		last = y
	check("drifter sine path stays inside its lane (|y| <= amp, actually moves)",
			peak <= Feel.DRIFTER_WAVE_AMP + 0.01 and moved)
	var x := -Feel.DRIFTER_LANE_HALF_W
	var dir := 1.0
	var lo := -Feel.DRIFTER_LANE_HALF_W
	var hi := Feel.DRIFTER_LANE_HALF_W
	var in_bounds := true
	var flipped := false
	for i in 1200:
		var res := Creature.step_drifter_x(x, dir, 1.0 / 60.0, lo, hi)
		x = res[0]
		if res[1] != dir:
			flipped = true
		dir = res[1]
		if x < lo - 0.01 or x > hi + 0.01:
			in_bounds = false
	check("drifter patrol bounces off the lane walls, never leaves", in_bounds and flipped)
	var advanced := Creature.step_drifter_x(100.0, 1.0, 1.0 / 60.0, 0.0, 1000.0)
	check("drifter advances along its lane at DRIFTER_SPEED",
			absf(advanced[0] - (100.0 + Feel.DRIFTER_SPEED / 60.0)) < 0.01)


# ------------------------------------------------- creature reveal + chase --

func _test_creature_reveal_and_chase() -> void:
	print("[creature sonar law + self-glow]")
	var s := fresh_sonar()
	var lurker: Creature = _spawn(Creature.Kind.LURKER)
	var drifter: Creature = _spawn(Creature.Kind.DRIFTER)
	s.register(lurker.sonar_id, lurker.position)
	s.register(drifter.sonar_id, drifter.position)
	lurker.apply_visibility(s.get_visibility(lurker.sonar_id))
	check("creature sits at the self-glow floor in the dark",
			absf(lurker.modulate.a - Feel.CREATURE_GLOW_ALPHA) < 0.001)
	s.ping()
	advance(s, 0.4)   # ring crosses both (150px and 300px out)
	var both_lit := s.get_visibility(lurker.sonar_id) >= 0.99 \
			and s.get_visibility(drifter.sonar_id) >= 0.99
	lurker.apply_visibility(s.get_visibility(lurker.sonar_id))
	check("both creatures reveal as bright echoes on the ping", both_lit
			and lurker.modulate.a >= 0.99)
	advance(s, Feel.ECHO_TOTAL_TIME + 0.3)
	lurker.apply_visibility(s.get_visibility(lurker.sonar_id))
	drifter.apply_visibility(s.get_visibility(drifter.sonar_id))
	check("echo fades but the glow floor keeps them JUST visible in the dark",
			s.get_visibility(lurker.sonar_id) <= 0.02
			and absf(lurker.modulate.a - Feel.CREATURE_GLOW_ALPHA) < 0.001
			and absf(drifter.modulate.a - Feel.CREATURE_GLOW_ALPHA) < 0.001)
	# in-tree chase: a ping wakes the lurker and it homes on the origin
	s.set_player_pos(Vector2(400, 400))
	s.ping()
	lurker.on_ping(s.last_ping_origin)
	var start := lurker.position
	for i in 60:
		await physics_frame
	check("lurker aggros and physically closes on the last ping origin",
			lurker.aggro and lurker.position.distance_to(s.last_ping_origin)
					< start.distance_to(s.last_ping_origin) - 20.0)
	lurker.free()
	drifter.free()
	await process_frame


func _spawn(kind: int) -> Creature:
	var c := Creature.new()
	c.kind = kind
	c.sonar_id = "test_%d" % kind
	c.position = Vector2(0, 150.0 * float(kind + 1))
	root.add_child(c)
	return c


# ------------------------------------------------------ air / pressure --

func _test_air_and_pressure() -> void:
	print("[survival: air + pressure]")
	var a := Survival.new()
	a.depth = 300.0
	a.tick(1.0)
	check("air drains with time", a.air < Feel.AIR_SECONDS)
	var shallow := Survival.new()
	shallow.depth = 200.0
	shallow.tick(1.0)
	var deep := Survival.new()
	deep.depth = 600.0
	deep.tick(1.0)
	check("air drains faster deeper",
			deep.air < shallow.air and absf(shallow.air - (Feel.AIR_SECONDS - shallow.drain_rate())) < 0.01)
	var surfaced := Survival.new()
	surfaced.air = 10.0
	surfaced.depth = Feel.SURFACE_DEPTH_PX * 0.5
	surfaced.tick(1.0)
	check("sub above the surface threshold refills air (gulp law)",
			surfaced.air > 10.0 and surfaced.air <= Feel.AIR_SECONDS)
	var crushed := Survival.new()
	crushed.depth = Feel.PRESSURE_MAX_DEPTH + 50.0
	crushed.tick(1.0)
	check("pressure crushes the hull past max depth without beacons",
			crushed.in_crush() and crushed.hull < Feel.HULL_HP)
	crushed.collect_beacon()
	var extended := Survival.new()
	extended.collect_beacon()
	extended.depth = Feel.PRESSURE_MAX_DEPTH + 40.0
	extended.tick(1.0)
	check("a beacon extends the crush depth (840m safe after 1 collect)",
			absf(extended.effective_max_depth()
					- (Feel.PRESSURE_MAX_DEPTH + Feel.BEACON_DEPTH_EXTENSION)) < 0.01
			and not extended.in_crush() and absf(extended.hull - Feel.HULL_HP) < 0.01)
	var drowned := Survival.new()
	drowned.air = 0.4
	drowned.depth = 300.0
	drowned.tick(1.0)
	check("air exhaustion ends the run", drowned.over and not drowned.won
			and drowned.end_reason == "air")


# ----------------------------------------------------- beacons + run over --

func _test_beacons_and_run_over() -> void:
	print("[beacons + run over]")
	var s := Survival.new()
	var kills := []
	s.run_over.connect(func(won: bool, reason: String) -> void: kills.append([won, reason]))
	s.air = 20.0
	s.collect_beacon()
	check("beacon collect: +1 count, +score, air top-up",
			s.beacons == 1 and s.score == Feel.BEACON_SCORE
			and absf(s.air - (20.0 + Feel.BEACON_AIR_TOPUP)) < 0.001)
	var touched := Survival.new()
	touched.kill("lurker_0")
	check("creature touch kills the sub (run_over, not won)",
			touched.over and not touched.won and touched.end_reason == "lurker_0")
	s.depth = Feel.PRESSURE_MAX_DEPTH + 200.0   # safe now: 3 beacons extend to 1040
	s.tick(0.5)
	s.collect_beacon()
	s.collect_beacon()
	s.depth = Feel.SURFACE_DEPTH_PX * 0.5
	s.tick(0.1)
	check("all 3 beacons + reaching the surface = RUN WON",
			s.over and s.won and s.end_reason == "surfaced" and kills.size() == 1
			and kills[0][0] == true)
	var t := s.tally()
	check("won tally = beacons*1000 + depth record + air bonus",
			t["beacons"] == 3 and t["beacon_score"] == 3000
			and t["score"] == t["beacon_score"] + t["depth_bonus"] + t["air_bonus"]
			and t["depth_record"] == int(Feel.PRESSURE_MAX_DEPTH + 200.0)
			and s.score == t["score"])


# ----------------------------------------------------------- scene loop --

func _test_scene_loop() -> void:
	print("[main scene: collect, touch death, retry]")
	var main: Node2D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var player: Sub = main.player
	var survival: Survival = main._survival
	for c in main._creatures:
		c.active = false          # isolate the loop under test
	var fill: ColorRect = main._hud["air_fill"]
	var full_air_px := fill.size.x

	player.position = main.BEACON_SPOTS[0]
	for i in 5:
		await process_frame
	check("sub overlap collects a beacon (count + score + flash)",
			survival.beacons == 1 and survival.score == Feel.BEACON_SCORE
			and main._flash_left > 0.0)
	await create_timer(Feel.BEACON_FLASH_TIME + 0.25).timeout
	var beacon_node: Node2D = main._beacon_nodes[0]
	check("collected beacon dims (flash spent)", main._flash_left <= 0.0
			and absf(beacon_node.modulate.a - Feel.BEACON_COLLECTED_ALPHA) < 0.01)
	var air_before: float = survival.air
	survival.depth = 500.0
	survival.tick(0.25)
	await process_frame
	check("HUD air bar shrinks as air drains", fill.size.x < full_air_px
			and survival.air < air_before + 0.001)

	# touch death -> overlay
	var killer: Creature = main._creatures[0]
	killer.active = true
	killer.position = player.position
	await physics_frame
	await physics_frame
	await process_frame
	check("creature touch kills the sub, overlay up, controls frozen",
			survival.over and survival.end_reason == "drifter_0"
			and not survival.won and (main._hud["overlay"] as ColorRect).visible
			and not player.input_enabled)
	check("death overlay names the deep (THE DEEP TOOK YOU)",
			(main._hud["overlay_title"] as Label).text == "THE DEEP TOOK YOU")

	main.reset_run()
	await process_frame
	await process_frame
	check("retry resets everything (full reset)",
			not survival.over and survival.beacons == 0 and survival.score == 0
			and survival.air > Feel.AIR_SECONDS - 0.5   # a live tick or two may drain
			and not (main._hud["overlay"] as ColorRect).visible
			and player.position.distance_to(Feel.SUB_HOME) < 0.5
			and player.input_enabled and player.sonar.ping_count == 0)
	for c in main._creatures:
		c.active = c.kind == Creature.Kind.DRIFTER   # drifters roam again
	check("reset re-arms the world (beacons dark again, ping ready)",
			main._beacon_taken["beacon_0"] == false
			and main.player.sonar.can_ping())
	root.remove_child(main)
	main.free()
	await process_frame
