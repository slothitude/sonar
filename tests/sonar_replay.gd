extends SceneTree
## SONAR milestone-1 replay: 12 scripted seconds against the real main scene.
## Pings on every available cooldown, weaves via synthetic input override.
## Gates: >= 3 pings fired, no errors, sub never leaves bounds, no soft-lock.
## Run: godot --headless --path . --script res://tests/sonar_replay.gd

const DURATION := 12.0
const WALL_BUDGET_MS := 60000

var _pings := 0
var _escaped := false
var _saw_echo := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	Engine.time_scale = 4.0   # 12 game-seconds, ~3s wall
	var scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var player: Sub = scene.get_node("Sub")
	var sonar: SonarVision = player.sonar
	var home: Vector2 = player.position
	var start_ms := Time.get_ticks_msec()

	while sonar.elapsed < DURATION:
		# weave: continuous synthetic steering
		player.set_input_override(Vector2(sin(sonar.elapsed * 1.1), cos(sonar.elapsed * 0.8)))
		# ping on every available cooldown
		if sonar.can_ping() and player.try_ping():
			_pings += 1
		var m := Feel.BOUNDS_MARGIN
		if player.position.x < m - 1.0 or player.position.y < m - 1.0 \
				or player.position.x > Feel.VIEW_WIDTH - m + 1.0 \
				or player.position.y > Feel.VIEW_HEIGHT - m + 1.0:
			_escaped = true
		if sonar.max_visibility() > 0.5:
			_saw_echo = true
		if Time.get_ticks_msec() - start_ms > WALL_BUDGET_MS:
			print("  FAIL  replay exceeded wall-clock budget (soft-lock suspected)")
			quit(1)
			return
		await process_frame

	Engine.time_scale = 1.0

	print("[sonar replay 12s]")
	check("at least 3 pings fired", _pings >= 3)
	check("ping cadence honored cooldown", sonar.ping_count >= _pings and _pings <= 6)
	check("sub never left bounds (weave held under clamp)", not _escaped)
	check("weave actually moved the sub", player.position.distance_to(home) > 40.0)
	check("position and velocity stay finite", player.position.is_finite() and player.velocity.is_finite())
	check("ping revealed world entities", _saw_echo)
	check("no soft-lock: sonar and movement still alive at end",
			sonar.elapsed >= DURATION and sonar.cooldown_remaining() < Feel.PING_COOLDOWN)
	print("")
	print("replay: pings=%d end_pos=%s end_speed=%.1f" % [
			_pings, player.position, player.velocity.length()])
	print("RESULT: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


var _passed := 0
var _failed := 0


func check(name: String, cond: bool) -> void:
	if cond:
		_passed += 1
		print("  PASS  %s" % name)
	else:
		_failed += 1
		print("  FAIL  %s" % name)
