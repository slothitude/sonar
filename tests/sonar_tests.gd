extends SceneTree
## SONAR milestone-1 battery (spec law "growing_battery").
## Run: godot --headless --path . --script res://tests/sonar_tests.gd
## Prints PASS/FAIL per check; exit code 0 = all green, 1 = failures.

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_test_sonar_cooldown()
	_test_sonar_ring()
	_test_sonar_decay()
	_test_glide_math()
	await _test_sub_in_tree()
	_test_touch_steering()
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


# ------------------------------------------------------------- sonar --

func _test_sonar_cooldown() -> void:
	print("[sonar cooldown]")
	var s := fresh_sonar()
	var first := s.ping()
	var second := s.ping()
	check("second immediate ping is a no-op (cooldown gate)", first and not second)
	advance(s, Feel.PING_COOLDOWN + 0.05)
	var third := s.ping()
	check("ping works after cooldown, count tracked", third and s.ping_count == 2)


func _test_sonar_ring() -> void:
	print("[sonar ring reveal]")
	var s := fresh_sonar()
	s.set_player_pos(Vector2(100, 100))   # exercise a moved ping origin
	s.register("near", Vector2(100, 250))
	s.register("mid", Vector2(100, 450))
	s.register("far", Vector2(100, 600))
	s.register("edge", Vector2(100, 519))
	s.ping()
	advance(s, 0.1)
	var r1 := s.ring_radius()
	var near_dark := s.get_visibility("near") == 0.0
	advance(s, 0.1)
	var r2 := s.ring_radius()
	var near_lit := s.get_visibility("near") >= 0.99
	var mid_dark_now := s.get_visibility("mid") < 0.5
	advance(s, 0.25)
	var r3 := s.ring_radius()
	var mid_lit := s.get_visibility("mid") >= 0.99
	check("entities reveal as the ring reaches them, in distance order",
			near_dark and near_lit and mid_dark_now and mid_lit)
	check("ring radius grows over its lifetime", r1 < r2 and r2 < r3)
	advance(s, 0.1)   # ring crosses full SONAR_RADIUS then deactivates
	check("ring reaches max radius then deactivates",
			s.get_visibility("edge") >= 0.99 and not s.ring_active())
	check("entity outside radius, unknown id, unregistered id all read 0.0",
			s.get_visibility("far") == 0.0 and s.get_visibility("ghost") == 0.0
			and _unregister_probe(s))


func _unregister_probe(s: SonarVision) -> bool:
	s.register("temp", Vector2(50, 50))
	var known := s.has_entity("temp")
	s.unregister("temp")
	return known and not s.has_entity("temp") and s.get_visibility("temp") == 0.0


func _test_sonar_decay() -> void:
	print("[sonar echo decay + re-ping]")
	var s := fresh_sonar()
	s.register("near", Vector2(0, 150))
	s.ping()
	advance(s, 0.2)                       # ring reaches the near entity
	advance(s, Feel.ECHO_TOTAL_TIME + 0.3)
	check("echo decays to ~0 after REVEAL_TIME+ECHO_FADE",
			s.get_visibility("near") <= 0.02)
	var repinged := s.ping()              # cooldown long since elapsed
	advance(s, 0.6)
	check("re-ping after cooldown re-brightens a faded echo",
			repinged and s.get_visibility("near") >= 0.99)


# ------------------------------------------------------------- movement --

func _test_glide_math() -> void:
	print("[glide math]")
	var dt := 1.0 / 60.0
	var dragged := Sub.step_velocity(Vector2(100, 0), Vector2.ZERO, dt)
	check("drag bleeds velocity when input released",
			absf(dragged.x - 100.0 * Feel.DRAG) < 0.01 and absf(dragged.y) < 0.001)
	var accelerated := Sub.step_velocity(Vector2.ZERO, Vector2.RIGHT, dt)
	var expect := Feel.GLIDE_ACCEL * dt * Feel.DRAG
	check("accel pushes velocity toward input", absf(accelerated.x - expect) < 0.01)
	var vel := Vector2.ZERO
	for i in 600:
		vel = Sub.step_velocity(vel, Vector2(1, 1), dt)
	check("sustained input never exceeds MAX_SPEED", vel.length() <= Feel.MAX_SPEED + 0.01)
	var clamped := Sub.clamp_to_bounds(Vector2(-50, 2000),
			Rect2(0, 0, Feel.VIEW_WIDTH, Feel.VIEW_HEIGHT), Feel.BOUNDS_MARGIN)
	check("bounds clamp honors margin",
			absf(clamped.x - Feel.BOUNDS_MARGIN) < 0.001
			and absf(clamped.y - (Feel.VIEW_HEIGHT - Feel.BOUNDS_MARGIN)) < 0.001)


func _test_sub_in_tree() -> void:
	print("[sub in tree]")
	var sub: Sub = (load("res://scenes/sub.tscn") as PackedScene).instantiate()
	root.add_child(sub)
	sub.position = Vector2(Feel.VIEW_WIDTH, Feel.VIEW_HEIGHT) * 0.5
	sub.set_input_override(Vector2(1, 1))
	var escaped := false
	var overspeed := false
	for i in 120:
		await physics_frame
		var m := Feel.BOUNDS_MARGIN
		if sub.position.x < m - 0.5 or sub.position.y < m - 0.5 \
				or sub.position.x > Feel.VIEW_WIDTH - m + 0.5 \
				or sub.position.y > Feel.VIEW_HEIGHT - m + 0.5:
			escaped = true
		if sub.velocity.length() > Feel.MAX_SPEED + 0.5:
			overspeed = true
	check("sub stays in bounds, speed clamped, under held input",
			not escaped and not overspeed)
	check("default input mode is touch (web law)", sub.tilt.mode == TiltSource.MODE_TOUCH)
	sub.clear_input_override()
	root.remove_child(sub)
	sub.free()   # immediate, so no RID/ObjectDB leaks at exit
	await process_frame


# ------------------------------------------------------------- input --

func _test_touch_steering() -> void:
	print("[touch steering]")
	var t := TiltSource.new()
	t.set_mode(TiltSource.MODE_TOUCH)
	t.touch_begin(100.0)
	var anchored := absf(t.read_output()) < 0.001
	t.touch_move(180.0)   # half drag
	var half := absf(t.read_output() - 0.4) < 0.02
	check("touch drag delta steers (0 at anchor, 0.4 shaped at half drag)", anchored and half)
	t.touch_move(260.0)   # full drag
	check("full drag saturates at OUTPUT_MAX",
			absf(t.read_output() - Feel.OUTPUT_MAX) < 0.001)
	t.touch_end()
	var sub := Sub.new()
	sub.touch_begin(Vector2(100, 0))
	sub.touch_move(Vector2(100, 160))
	check("touch_end resets to zero; drag steers the sub's y axis",
			absf(t.read_output()) < 0.001 and absf(sub.gather_input().y - 1.0) < 0.02)
	sub.free()   # never entered the tree; free so no RID/ObjectDB leaks at exit
