extends Node2D
## THE DARK SEA — milestone 2 scene wiring.
## Near-black drifting water, the sub at the upper third, wreck rocks, 3
## collectible wreck beacons deep, creatures (drifters in lanes, lurkers that
## wake with depth), the expanding sonar ring, and the survival loop.
## ENTITY RENDERING LAW: every entity's modulate.alpha = its SonarVision
## visibility (invisible in the dark, bright on ping, fading echo), EXCEPT:
##   sub       — always dimly visible (self-lit cockpit)
##   creatures — visibility with a faint self-glow floor (they close in the dark)
##   taken beacon — dims to Feel.BEACON_COLLECTED_ALPHA
##   beacon flash — everything bright for BEACON_FLASH_TIME on collection

const SUB_ID := "sub"
const WATER_TEXTURE_PATH := "res://assets/generated/tile_water_dark.png"
const BEACON_TEXTURE_PATH := "res://assets/generated/wreck_beacon.png"

const ROCK_POINTS: Array[Vector2] = [
	Vector2(95, 150), Vector2(430, 120), Vector2(180, 430),
	Vector2(430, 480), Vector2(80, 620), Vector2(300, 560),
]
const BEACON_SPOTS: Array[Vector2] = [
	Vector2(250, 770), Vector2(105, 880), Vector2(430, 915),
]

@onready var water: Sprite2D = $Water
@onready var ring: Node2D = $Ring
@onready var rocks: Node2D = $Rocks
@onready var player: Sub = $Sub
@onready var sonar_button: Button = $UI/SonarButton
@onready var ui: CanvasLayer = $UI

var _sonar: SonarVision
var _survival := Survival.new()
var _law: Array = []              # [ [id, CanvasItem, kind], ... ]
var _creatures: Array = []        # Creature nodes
var _beacon_nodes: Array = []     # Node2D per BEACON_SPOTS index
var _beacon_taken: Dictionary = {}  # id -> bool
var _flash_left := 0.0
var _awake_lurkers := 0
var _last_seen_ping := 0
var _hud := {}                    # name -> Control


func _ready() -> void:
	_sonar = player.sonar
	_setup_water()
	_setup_entities()
	_setup_creatures()
	_setup_hud()
	ring.draw.connect(_draw_ring)
	sonar_button.pressed.connect(_on_sonar_pressed)
	_survival.run_over.connect(_on_run_over)
	reset_run()


func _setup_water() -> void:
	water.centered = true
	water.position = Vector2(Feel.VIEW_WIDTH, Feel.VIEW_HEIGHT) * 0.5
	water.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	water.region_enabled = true
	water.region_rect = Rect2(0.0, 0.0, Feel.VIEW_WIDTH + 360.0, Feel.VIEW_HEIGHT + 540.0)
	if ResourceLoader.exists(WATER_TEXTURE_PATH):
		water.texture = load(WATER_TEXTURE_PATH)
	else:
		water.texture = _make_water_texture()
	water.modulate = Color(0.3, 0.34, 0.42)   # near-black regardless of art brightness


## Code-drawn fallback water tile (never block on art).
func _make_water_texture() -> Texture2D:
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var n := 0.5 + 0.5 * sin(float(x) * 0.35 + float(y) * 0.21) * cos(float(y) * 0.17)
			var v := 0.03 + 0.05 * n
			img.set_pixel(x, y, Color(v * 0.7, v, v * 1.15))
	return ImageTexture.create_from_image(img)


func _setup_entities() -> void:
	for i in ROCK_POINTS.size():
		var rock := _make_rock(ROCK_POINTS[i], 1000 + i)
		rocks.add_child(rock)
	for i in BEACON_SPOTS.size():
		var beacon := _make_beacon(BEACON_SPOTS[i])
		rocks.add_child(beacon)
		_beacon_nodes.append(beacon)


func _make_rock(center: Vector2, rng_seed: int) -> Polygon2D:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var points := PackedVector2Array()
	var n := rng.randi_range(7, 9)
	for i in n:
		var ang := TAU * float(i) / float(n) + rng.randf_range(-0.15, 0.15)
		var rad := rng.randf_range(18.0, 46.0)
		points.append(Vector2(cos(ang), sin(ang)) * rad)
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = Color(0.42, 0.58, 0.72)   # bright echo palette; alpha does the hiding
	poly.position = center
	return poly


func _make_beacon(center: Vector2) -> Node2D:
	var node: Node2D = null
	if ResourceLoader.exists(BEACON_TEXTURE_PATH):
		var spr := Sprite2D.new()
		var tex: Texture2D = load(BEACON_TEXTURE_PATH)
		spr.texture = tex
		var s := Feel.BEACON_HEIGHT_PX / float(tex.get_height())
		spr.scale = Vector2(s, s)
		node = spr
	else:
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([Vector2(0, -22), Vector2(14, 0), Vector2(0, 22), Vector2(-14, 0)])
		poly.color = Color(0.95, 0.82, 0.35)
		node = poly
	node.position = center
	return node


## 2 drifters from the start; lurkers park below and wake as the sub descends.
func _setup_creatures() -> void:
	for i in Feel.DRIFTER_LANES.size():
		var c := Creature.new()
		c.kind = Creature.Kind.DRIFTER
		c.sonar_id = "drifter_%d" % i
		c.anchor = Feel.DRIFTER_LANES[i]
		c.position = c.anchor
		add_child(c)
		_creatures.append(c)
	for i in Feel.LURKER_DEPTH_STEPS.size():
		var c := Creature.new()
		c.kind = Creature.Kind.LURKER
		c.sonar_id = "lurker_%d" % i
		c.park(Vector2(player.position.x, Feel.VIEW_HEIGHT + 200.0 + 60.0 * float(i)))
		add_child(c)
		_creatures.append(c)


# ---------------------------------------------------------------- reset --

## FULL run reset: fresh sonar + survival, creatures and beacons back to mint,
## sub home, overlay down. Also serves as the _ready entry point.
func reset_run() -> void:
	_sonar = SonarVision.new()
	player.sonar = _sonar
	player.input_enabled = true
	player.position = Feel.SUB_HOME
	player.velocity = Vector2.ZERO
	player.clear_input_override()
	_survival.reset()
	_flash_left = 0.0
	_awake_lurkers = 0
	_last_seen_ping = 0
	_beacon_taken.clear()
	for node in _beacon_nodes:
		node.modulate.a = 0.0
	for c in _creatures:
		c.set_physics_process(true)
		c.t = 0.0
		if c.kind == Creature.Kind.DRIFTER:
			c.anchor = Feel.DRIFTER_LANES[int(c.sonar_id.right(1))]
			c.position = c.anchor
			c.vel = Vector2.ZERO
			c.aggro = false
		else:
			c.park(Vector2(Feel.SUB_HOME.x + Feel.LURKER_WAKE_SIDE
					* (1.0 if int(c.sonar_id.right(1)) % 2 == 0 else -1.0),
					Feel.VIEW_HEIGHT + 200.0 + 60.0 * float(int(c.sonar_id.right(1)))))
	_rebuild_law()
	_hide_overlay()


## (Re)register every entity with the fresh SonarVision and rebuild the law.
func _rebuild_law() -> void:
	_law = []
	_sonar.register(SUB_ID, player.position)
	_law.append([SUB_ID, player, "sub"])
	for i in ROCK_POINTS.size():
		var rid := "rock_%d" % i
		_sonar.register(rid, ROCK_POINTS[i])
		_law.append([rid, rocks.get_child(i), "rock"])
	for i in _beacon_nodes.size():
		var bid := "beacon_%d" % i
		_beacon_taken[bid] = false
		_sonar.register(bid, BEACON_SPOTS[i])
		_law.append([bid, _beacon_nodes[i], "beacon"])
	for c in _creatures:
		_sonar.register(c.sonar_id, c.position)
		_law.append([c.sonar_id, c, "creature"])
	for entry in _law:
		(entry[1] as CanvasItem).modulate.a = 0.0
	player.modulate.a = Feel.SUB_SELF_ALPHA


# --------------------------------------------------------------- process --

func _process(delta: float) -> void:
	# slow downward drift = the sub is descending
	var rr := water.region_rect
	rr.position.y += Feel.WATER_DRIFT_SPEED * delta
	water.region_rect = rr

	_sonar.set_player_pos(player.position)
	_sonar.tick(delta)
	if _sonar.ping_count != _last_seen_ping:
		_last_seen_ping = _sonar.ping_count
		_alert_creatures_to_ping()

	_survival.depth = maxf(0.0, player.position.y - Feel.SURFACE_LINE_Y)
	_survival.tick(delta)
	_wake_lurkers_with_depth()
	_collect_beacons()
	_check_touches()
	_sync_creatures()
	_render_law(delta)
	_update_hud()

	if _flash_left > 0.0:
		_flash_left = maxf(0.0, _flash_left - delta)
	ring.queue_redraw()


## Lurkers rise with depth (feel consts): each threshold wakes one at the
## bottom of the dark, beside the sub's column — it rises when a ping calls.
func _wake_lurkers_with_depth() -> void:
	while _awake_lurkers < Feel.LURKER_DEPTH_STEPS.size() \
			and _survival.depth >= Feel.LURKER_DEPTH_STEPS[_awake_lurkers]:
		var side := 1.0 if _awake_lurkers % 2 == 0 else -1.0
		var lurker: Creature = _creatures[Feel.DRIFTER_LANES.size() + _awake_lurkers]
		lurker.wake(Vector2(
				clampf(player.position.x + side * Feel.LURKER_WAKE_SIDE,
						Feel.BOUNDS_MARGIN, Feel.VIEW_WIDTH - Feel.BOUNDS_MARGIN),
				Feel.LURKER_WAKE_Y))
		_awake_lurkers += 1


func _collect_beacons() -> void:
	if _survival.over:
		return
	for i in _beacon_nodes.size():
		var bid := "beacon_%d" % i
		if _beacon_taken[bid]:
			continue
		if player.position.distance_to(_beacon_nodes[i].position) <= Feel.BEACON_COLLECT_RADIUS:
			_beacon_taken[bid] = true
			_survival.collect_beacon()
			_flash_left = Feel.BEACON_FLASH_TIME   # bright ping-flash


func _check_touches() -> void:
	if _survival.over:
		return
	for c in _creatures:
		if c.active and c.touches_point(player.position):
			_survival.kill(c.sonar_id)
			return


func _sync_creatures() -> void:
	for c in _creatures:
		_sonar.set_entity_position(c.sonar_id, c.position)


## ENTITY RENDERING LAW (see header for the per-kind exceptions).
func _render_law(delta: float) -> void:
	var flash := 0.0
	if _flash_left > 0.0:
		flash = clampf(_flash_left / Feel.BEACON_FLASH_TIME, 0.0, 1.0)
	for entry in _law:
		var id: String = entry[0]
		var node: CanvasItem = entry[1]
		var kind: String = entry[2]
		var vis: float = _sonar.get_visibility(id)
		var a := vis
		match kind:
			"sub":
				a = maxf(Feel.SUB_SELF_ALPHA, vis)
			"creature":
				a = maxf(vis, Feel.CREATURE_GLOW_ALPHA)
			"beacon":
				if _beacon_taken[id]:
					a = Feel.BEACON_COLLECTED_ALPHA
		node.modulate.a = maxf(a, flash)
	sonar_button.modulate.a = 1.0 if _sonar.can_ping() else 0.45


# ------------------------------------------------------------------ HUD --

func _setup_hud() -> void:
	var air_bg := ColorRect.new()
	air_bg.position = Vector2(18, 18)
	air_bg.size = Vector2(200, 13)
	air_bg.color = Color(0.05, 0.12, 0.18, 0.85)
	ui.add_child(air_bg)
	var air_fill := ColorRect.new()
	air_fill.position = Vector2(20, 20)
	air_fill.size = Vector2(196, 9)
	air_fill.color = Color(0.55, 0.9, 1.0)
	ui.add_child(air_fill)
	_hud["air_fill"] = air_fill
	_hud["air_bg"] = air_bg

	_hud["depth"] = _make_label(Vector2(238, 14), 20, HORIZONTAL_ALIGNMENT_LEFT)
	_hud["beacons"] = _make_label(Vector2(238, 40), 16, HORIZONTAL_ALIGNMENT_LEFT)
	_hud["score"] = _make_label(Vector2(360, 14), 20, HORIZONTAL_ALIGNMENT_RIGHT)
	(_hud["score"] as Label).size = Vector2(160, 24)

	# death / victory overlay
	var overlay := ColorRect.new()
	overlay.name = "Overlay"
	overlay.size = Vector2(Feel.VIEW_WIDTH, Feel.VIEW_HEIGHT)
	overlay.color = Color(0.01, 0.03, 0.05, 0.82)
	overlay.visible = false
	ui.add_child(overlay)
	_hud["overlay"] = overlay
	_hud["overlay_title"] = _make_label(Vector2(0, 330), 34, HORIZONTAL_ALIGNMENT_CENTER, overlay)
	(_hud["overlay_title"] as Label).size = Vector2(Feel.VIEW_WIDTH, 44)
	_hud["overlay_body"] = _make_label(Vector2(0, 392), 20, HORIZONTAL_ALIGNMENT_CENTER, overlay)
	(_hud["overlay_body"] as Label).size = Vector2(Feel.VIEW_WIDTH, 140)
	_hud["overlay_hint"] = _make_label(Vector2(0, 560), 17, HORIZONTAL_ALIGNMENT_CENTER, overlay)
	(_hud["overlay_hint"] as Label).size = Vector2(Feel.VIEW_WIDTH, 26)
	(_hud["overlay_hint"] as Label).modulate = Color(0.75, 0.95, 1.0, 0.85)


func _make_label(pos: Vector2, font_size: int, align: int,
		parent: Node = null) -> Label:
	var label := Label.new()
	label.position = pos
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	(parent if parent != null else ui).add_child(label)
	return label


func _update_hud() -> void:
	var fill: ColorRect = _hud["air_fill"]
	fill.size.x = 196.0 * _survival.air_ratio()
	fill.color = Color(0.55, 0.9, 1.0) if _survival.air_ratio() > 0.25 \
			else Color(0.95, 0.4, 0.3)
	var depth_label: Label = _hud["depth"]
	depth_label.text = "%dm" % int(_survival.depth)
	depth_label.add_theme_color_override("font_color",
			Color(0.95, 0.4, 0.3) if _survival.in_crush() else Color(0.75, 0.95, 1.0))
	(_hud["beacons"] as Label).text = "BEACONS %d/%d" % [_survival.beacons, Feel.BEACONS_REQUIRED]
	(_hud["score"] as Label).text = "SCORE %d" % _survival.score


func _on_run_over(won: bool, reason: String) -> void:
	player.input_enabled = false
	for c in _creatures:
		c.set_physics_process(false)
	var overlay: ColorRect = _hud["overlay"]
	var title: Label = _hud["overlay_title"]
	var body: Label = _hud["overlay_body"]
	if won:
		var t := _survival.tally()
		title.text = "YOU SURFACED"
		title.add_theme_color_override("font_color", Color(0.6, 1.0, 0.8))
		body.text = "%d BEACONS  +%d\nDEPTH RECORD %dm  +%d\nAIR BONUS  +%d\n\nSCORE %d" % [
				t["beacons"], t["beacon_score"], t["depth_record"],
				t["depth_bonus"], t["air_bonus"], t["score"]]
	else:
		title.text = "THE DEEP TOOK YOU"
		title.add_theme_color_override("font_color", Color(0.95, 0.4, 0.3))
		var cause := "the air ran out"
		if reason == "crush":
			cause = "the pressure crushed the hull"
		elif reason.begins_with("lurker") or reason.begins_with("drifter"):
			cause = "something found you"
		body.text = "%s\n\nSCORE %d" % [cause, _survival.score]
	overlay.visible = true


func _hide_overlay() -> void:
	(_hud["overlay"] as ColorRect).visible = false


# ----------------------------------------------------------------- input --

func _unhandled_input(event: InputEvent) -> void:
	if _survival.over and _retry_requested(event):
		reset_run()


## Tap or SPACE (the sonar action) restarts the run from the overlay.
func _retry_requested(event: InputEvent) -> bool:
	if event.is_action_pressed("sonar"):
		return true
	return event is InputEventScreenTouch and event.pressed


func _draw_ring() -> void:
	if not _sonar.ring_active():
		return
	var fade := clampf(1.0 - _sonar.ring_progress(), 0.0, 1.0)
	ring.draw_arc(player.position, _sonar.ring_radius(), 0.0, TAU, 96,
			Color(0.55, 0.9, 1.0, 0.9 * fade), 3.0, true)
	ring.draw_arc(player.position, maxf(1.0, _sonar.ring_radius() - 10.0), 0.0, TAU, 96,
			Color(0.55, 0.9, 1.0, 0.28 * fade), 9.0, true)


func _on_sonar_pressed() -> void:
	player.try_ping()


## Every lurker hears a fired ping and homes on its origin (any ping source:
## button, SPACE, or a scripted try_ping — polled via the sonar ping count).
func _alert_creatures_to_ping() -> void:
	for c in _creatures:
		c.on_ping(_sonar.last_ping_origin)
