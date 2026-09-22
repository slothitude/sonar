extends SceneTree
## SONAR milestone-3 battery (spec law "growing_battery").
## Procedural sfx (7 cues, 6-voice pool, persisted mute), the title screen
## (main scene + DIVE N), the user:// run counter, the 3-run difficulty curve,
## and the polish loop (vignette, crush warning, collect flash, tally reveal,
## death report) plus a title -> dive integration boot with no errors.
## Run: godot --headless --path . --script res://tests/m3_tests.gd

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	Save.reset()   # deterministic save state for the whole battery
	_test_sfx()
	_test_run_counter()
	await _test_title()
	_test_difficulty_curve()
	await _test_main_polish()
	await _test_integration_boot()
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


# ------------------------------------------------------------------ sfx --

func _test_sfx() -> void:
	print("[sfx: cues, pool, persisted mute]")
	var sfx: Sfx = Sfx.new()
	root.add_child(sfx)
	await process_frame   # cue synthesis is deferred off the boot path
	var all_built := Sfx.CUE_NAMES.size() == 7
	for cue in Sfx.CUE_NAMES:
		var wav: AudioStreamWAV = sfx.cues.get(cue)
		if wav == null or not wav is AudioStreamWAV:
			all_built = false
		elif wav.data.size() <= 0 or wav.mix_rate != Feel.SFX_SAMPLE_RATE:
			all_built = false
	check("sfx builds all 7 procedural cues (16-bit mono at Feel rate)", all_built)
	check("6-voice pool; ping plays unmuted, silenced while muted",
			sfx._pool.size() == Feel.SFX_POOL_SIZE and sfx.play("ping")
			and not sfx.play("nope"))
	sfx.set_muted(true)
	var fresh: Sfx = Sfx.new()   # enters the tree below: _ready reads the save
	root.add_child(fresh)
	check("mute persists to the user:// save and a fresh Sfx loads it",
			not sfx.play("ping") and Save.is_muted() and fresh.muted)
	root.remove_child(fresh)
	fresh.free()
	sfx.set_muted(false)
	check("unmuting restores playback (and the save agrees)",
			sfx.play("beacon") and not Save.is_muted())
	root.remove_child(sfx)
	sfx.free()


# ------------------------------------------------------------- run counter --

func _test_run_counter() -> void:
	print("[save: run counter]")
	Save.reset()
	var bumped := Save.bump_dives()
	check("dive counter persists across save reloads (0 -> bump -> 1)",
			bumped == 1 and Save.get_dives() == 1)


# ------------------------------------------------------------------ title --

func _test_title() -> void:
	print("[title screen]")
	check("title is the main scene per ProjectSettings",
			String(ProjectSettings.get_setting("application/run/main_scene"))
					== "res://scenes/title.tscn")
	var title: Node2D = (load("res://scenes/title.tscn") as PackedScene).instantiate()
	root.add_child(title)
	await process_frame
	await process_frame
	var labels := ""
	for node in title.get_node("UI").get_children():
		if node is Label:
			labels += (node as Label).text + "|"
	check("title shows DIVE N, the pulsing hint, theme line + jam stamp",
			title._dive_label.text == "DIVE 2"   # save holds 1 dive from the test above
			and labels.contains(Feel.TITLE_HINT)
			and labels.contains(Feel.THEME_LINE) and labels.contains(Feel.VERSION_LINE))
	check("logo, lurker silhouette and rising bubbles are staged (logo on top)",
			title.get_node("Logo") != null
			and title.get_node("Logo").get_index() > title.get_node("Silhouette").get_index()
			and title.get_node("Silhouette") != null
			and title.get_node("Bubbles").emitting)
	title.free()
	await process_frame


# -------------------------------------------------------- difficulty curve --

func _test_difficulty_curve() -> void:
	print("[3-run difficulty curve]")
	check("air drain curve +0/+5/+10% (attempt 0 identical to M2)",
			absf(Feel.air_drain_mult(0) - 1.0) < 0.0001
			and absf(Feel.air_drain_mult(1) - 1.05) < 0.0001
			and absf(Feel.air_drain_mult(2) - 1.1) < 0.0001
			and absf(Feel.air_drain_mult(9) - 1.1) < 0.0001)
	var late := Feel.lurker_steps(2)
	check("lurker wake curve drops per attempt and adds a 4th lurker on dive 3",
			Feel.lurker_steps(0) == Feel.LURKER_DEPTH_STEPS
			and late.size() == 4 and late[0] < Feel.LURKER_DEPTH_STEPS[0]
			and Feel.echo_ring_radius(200.0) < 200.0
			and Feel.echo_ring_radius(40.0) == 0.0)
	var fast := Survival.new()
	var slow := Survival.new()
	fast.drain_scale = Feel.air_drain_mult(2)
	fast.depth = 400.0
	slow.depth = 400.0
	fast.tick(1.0)
	slow.tick(1.0)
	check("drain_scale bites: attempt-2 air burns faster at the same depth",
			fast.air < slow.air
			and absf(slow.air - (Feel.AIR_SECONDS - slow.drain_rate())) < 0.01)


# --------------------------------------------------------- polish in scene --

func _test_main_polish() -> void:
	print("[main scene: polish loop]")
	var main: Node2D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.dive_attempt = 0   # attempt 0: the M2 world, untouched
	root.add_child(main)
	await process_frame
	await process_frame
	var survival: Survival = main._survival
	check("attempt 0 keeps the M2 world (drain 1.0, 3 lurkers); "
			+ "attempt 2 scales it (drain 1.1, 4 lurkers)",
			absf(survival.drain_scale - 1.0) < 0.0001
			and main._creatures.size() == 5)
	main.dive_attempt = 2
	main.reset_run()
	await process_frame
	check("attempt 2 applied on reset (drain 1.1, 4 lurker nodes)",
			absf(main._survival.drain_scale - 1.1) < 0.0001
			and main._creatures.size() == 6 and main._lurker_nodes == 4)
	main.dive_attempt = 0
	main.reset_run()
	await process_frame

	# vignette tracks the air
	main._survival.air = 15.0
	await process_frame
	var closeness: float = (main._hud["vignette"] as ColorRect).material \
			.get_shader_parameter("closeness")
	check("vignette closes in as the air drops (closeness = 1 - air_ratio)",
			absf(closeness - 0.75) < 0.02)

	# beacon collect radial flash
	for c in main._creatures:
		c.active = false
	var player: Sub = main.player
	player.position = main.BEACON_SPOTS[0]
	for i in 4:
		await process_frame
	check("collect fires the big radial flash at the beacon",
			main._flash_left > 0.0
			and main._flash_pos.distance_to(main.BEACON_SPOTS[0]) < 0.5)
	await create_timer(Feel.BEACON_FLASH_TIME + 0.25).timeout

	# crush warning: shake + red veil, cleared by reset (fresh run: no beacons
	# collected, so the no-beacon crush depth applies)
	main.reset_run()
	await process_frame
	player.position = Vector2(270.0, Feel.SURFACE_LINE_Y
			+ Feel.PRESSURE_MAX_DEPTH + 60.0)
	for i in 4:
		await process_frame
	var veil: ColorRect = main._hud["crush_veil"]
	check("past crush depth the hull shakes and the red veil pulses",
			main._survival.in_crush() and main.position.length() > 0.5
			and veil.visible and veil.color.a > 0.0)
	main.reset_run()
	await process_frame
	check("reset clears the crush warning (still, veil hidden)",
			main.position.length() < 0.001 and not veil.visible
			and not (main._hud["crush_veil"] as ColorRect).visible)

	# win overlay: tally lines reveal one by one
	for i in main.BEACON_SPOTS.size():
		player.position = main.BEACON_SPOTS[i]
		for f in 4:
			await process_frame
	main._survival.depth = Feel.SURFACE_DEPTH_PX * 0.5
	main._survival.tick(0.1)
	await process_frame
	check("win overlay runs the tally reveal (4 lines, all in by the end)",
			main._survival.won and (main._hud["overlay"] as ColorRect).visible
			and main._tally_lines.size() == 4
			and main._tally_lines[0].text.begins_with("3 BEACONS")
			and main._tally_lines[3].text.begins_with("SCORE"))
	await create_timer(Feel.TALLY_LINE_STEP * 3.0 + Feel.TALLY_FADE + 0.3).timeout
	var all_in := true
	for line in main._tally_lines:
		if line.modulate.a < 0.99:
			all_in = false
	check("tally lines all fully revealed after the step timing", all_in)

	# death overlay reports depth reached + beacons
	main.reset_run()
	await process_frame
	await process_frame
	for c in main._creatures:
		c.active = false
	var killer: Creature = main._creatures[0]
	killer.active = true
	killer.position = main.player.position
	await physics_frame
	await physics_frame
	await process_frame
	var body := (main._hud["overlay_body"] as Label).text
	check("death overlay adds the depth reached + beacons to the report",
			main._survival.over and not main._survival.won
			and body.contains("DEPTH REACHED") and body.contains("BEACONS"))
	root.remove_child(main)
	main.free()
	await process_frame


# ----------------------------------------------------------- integration --

func _test_integration_boot() -> void:
	print("[integration: title -> dive, 3s clean]")
	var title: Node2D = (load("res://scenes/title.tscn") as PackedScene).instantiate()
	root.add_child(title)
	for i in 3:
		await process_frame
	title.free()
	var main: Node2D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)   # what the title's start loads; attempt from the save
	await process_frame
	await process_frame
	Engine.time_scale = 4.0
	var player: Sub = main.player
	var sonar: SonarVision = player.sonar
	var start_ms := Time.get_ticks_msec()
	while sonar.elapsed < 3.0:
		player.set_input_override(Vector2(sin(sonar.elapsed * 1.3) * 0.4,
				cos(sonar.elapsed * 0.9) * 0.4))
		if sonar.can_ping():
			player.try_ping()
		if Time.get_ticks_msec() - start_ms > 60000:
			break
		await process_frame
	Engine.time_scale = 1.0
	check("title -> dive boots clean: 3s simulated, run alive, state finite",
			sonar.elapsed >= 3.0 and not main._survival.over
			and player.position.is_finite() and player.velocity.is_finite()
			and sonar.ping_count >= 1
			and not (main._hud["overlay"] as ColorRect).visible)
	root.remove_child(main)
	main.free()
	await process_frame
	# let the audio server retire any playbacks still pending release
	await create_timer(0.25).timeout
	await process_frame
	await process_frame
