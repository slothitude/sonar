extends Node2D
## THE DARK SEA — milestone 1 scene wiring.
## Near-black drifting water, the sub at the upper third, inert wreck rocks +
## beacons as test entities, the expanding sonar ring.
## ENTITY RENDERING LAW: every entity's modulate.alpha = its SonarVision
## visibility (invisible in the dark, bright on ping, fading echo).
## The sub itself is always dimly visible (self-lit cockpit).

const SUB_ID := "sub"
const WATER_TEXTURE_PATH := "res://assets/generated/tile_water_dark.png"
const BEACON_TEXTURE_PATH := "res://assets/generated/wreck_beacon.png"

const ROCK_POINTS: Array[Vector2] = [
	Vector2(95, 150), Vector2(430, 120), Vector2(180, 430),
	Vector2(430, 480), Vector2(80, 620), Vector2(300, 560),
]
const BEACON_POINTS: Array[Vector2] = [Vector2(250, 720), Vector2(120, 880)]

@onready var water: Sprite2D = $Water
@onready var ring: Node2D = $Ring
@onready var rocks: Node2D = $Rocks
@onready var player: Sub = $Sub
@onready var sonar_button: Button = $UI/SonarButton

var _sonar: SonarVision
var _law: Array = []   # [ [id, CanvasItem], ... ]


func _ready() -> void:
	_sonar = player.sonar
	_setup_water()
	_setup_entities()
	ring.draw.connect(_draw_ring)
	sonar_button.pressed.connect(_on_sonar_pressed)


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
	_sonar.register(SUB_ID, player.position)
	_law.append([SUB_ID, player])
	for i in ROCK_POINTS.size():
		var rock := _make_rock(ROCK_POINTS[i], 1000 + i)
		rocks.add_child(rock)
		var rid := "rock_%d" % i
		_sonar.register(rid, ROCK_POINTS[i])
		_law.append([rid, rock])
	for i in BEACON_POINTS.size():
		var beacon := _make_beacon(BEACON_POINTS[i])
		rocks.add_child(beacon)
		var bid := "beacon_%d" % i
		_sonar.register(bid, BEACON_POINTS[i])
		_law.append([bid, beacon])
	for entry in _law:
		(entry[1] as CanvasItem).modulate.a = 0.0
	player.modulate.a = Feel.SUB_SELF_ALPHA


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


func _process(delta: float) -> void:
	# slow downward drift = the sub is descending
	var rr := water.region_rect
	rr.position.y += Feel.WATER_DRIFT_SPEED * delta
	water.region_rect = rr

	_sonar.set_player_pos(player.position)
	_sonar.tick(delta)

	# ENTITY RENDERING LAW
	for entry in _law:
		var vis: float = _sonar.get_visibility(entry[0])
		var node := entry[1] as CanvasItem
		if entry[0] == SUB_ID:
			node.modulate.a = maxf(Feel.SUB_SELF_ALPHA, vis)
		else:
			node.modulate.a = vis
	sonar_button.modulate.a = 1.0 if _sonar.can_ping() else 0.45
	ring.queue_redraw()


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
