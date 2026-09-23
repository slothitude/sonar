class_name Feel
extends RefCounted
## EVERY feel number lives here (spec law "constants_not_magic").
## Values sourced from spec/jam_spec.json. No magic numbers anywhere else.

# ---- sonar (spec.systems.sonar) ----
const PING_COOLDOWN := 3.0      # s between pings
const REVEAL_TIME := 1.2        # s an echo holds full brightness
const ECHO_FADE := 2.5          # s an echo takes to fade from full to gone
const ECHO_TOTAL_TIME := REVEAL_TIME + ECHO_FADE  # full echo lifetime
const SONAR_RADIUS := 420.0     # px the ping reaches
const RING_EXPAND_TIME := 0.5   # s for the ring to sweep out to SONAR_RADIUS

# ---- movement (spec.systems.movement) ----
const GLIDE_ACCEL := 300.0      # px/s^2 toward input
const DRAG := 0.92              # velocity multiplier per physics tick
const MAX_SPEED := 260.0        # px/s hard clamp

# ---- input pipeline (ported from gyro-squadron-45/scripts/feel.gd so the
# verbatim tilt_source.gd copy stays verbatim) ----
const DEAD_ZONE := 0.06               # normalized tilt dead zone
const CURVE_EXPONENT := 2.0           # quadratic response, precise center
const SENSITIVITY := 1.6              # output gain
const TILT_BLEND_GYRO := 0.15         # touch of gyroscope for responsiveness
const GRAVITY_NORM := 9.81            # m/s^2; gravity.x / this -> -1..1 tilt
const GYRO_NORM_SCALE := 2.0          # rad/s of gyro.x that counts as "full"
const OUTPUT_MAX := 1.0               # shaped output saturates here
const TOUCH_DRAG_RANGE_PX := 160.0    # finger travel equal to full deflection
const PLANE_MAX_SPEED := 480.0        # referenced by tilt_source doc comment (unused here)

# ---- view / arena ----
const VIEW_WIDTH := 540.0       # portrait design size
const VIEW_HEIGHT := 960.0
const BOUNDS_MARGIN := 24.0     # px the sub is kept inside the play rect
const WATER_DRIFT_SPEED := 18.0 # px/s downward texture scroll (descending illusion)
const SUB_HOME := Vector2(270.0, 320.0)  # upper third
const SUB_SELF_ALPHA := 0.45   # self-lit cockpit floor (always dimly visible)

# ---- art scaling (generated art is arbitrary size; normalized at load) ----
const SUB_WIDTH_PX := 90.0
const BEACON_HEIGHT_PX := 46.0

# ---- milestone 2: creatures (spec.systems.creatures) ----
const CREATURE_WIDTH_PX := 64.0
const CREATURE_GLOW_ALPHA := 0.18     # just visible in the dark — fear
const TOUCH_RADIUS := 30.0            # hull + fin overlap that kills
const LURKER_SPEED := 120.0           # aggro cruise px/s
const LURKER_MAX_SPEED := 220.0       # close-range burst cap (sub is 260 — escapable)
const LURKER_ACCEL := 110.0           # px/s^2 toward the ping origin
const LURKER_CLOSE_RANGE := 150.0     # inside this, the burst kicks in
const LURKER_CLOSE_BURST := 2.1       # accel + cap multiplier in close range
const LURKER_IDLE_DRAG := 80.0        # px/s^2 vel decay while unaggroed
const LURKER_BOB_AMP := 9.0           # idle drift bob
const LURKER_BOB_FREQ := 0.7
const LURKER_WAKE_SIDE := 170.0       # wakes beside the sub's column, below view
const LURKER_WAKE_Y := 1030.0         # just under the view bottom (960)
const LURKER_DEPTH_STEPS: Array[float] = [200.0, 420.0, 640.0]
const DRIFTER_SPEED := 34.0           # lane patrol px/s
const DRIFTER_WAVE_AMP := 46.0        # sine bob px
const DRIFTER_WAVE_FREQ := 1.1        # rad/s
const DRIFTER_LANE_HALF_W := 70.0     # patrol half-width around the lane anchor
const DRIFTER_LANES: Array[Vector2] = [Vector2(100, 460), Vector2(430, 620)]
## lanes sit clear of the natural dive/hover corridors (sub crosses at ~x 220
## on the descent and ~x 270 on the ascent — both well outside touch range)

# ---- milestone 2: survival + goal (spec.systems.survival / goal) ----
const AIR_SECONDS := 60.0
const AIR_DRAIN_RATE := 1.0           # air/s at the surface line
const AIR_DEPTH_PENALTY_PX := 400.0   # each this many px of depth adds 1x drain
const SURFACE_LINE_Y := 40.0          # waterline; depth measures down from here
const SURFACE_DEPTH_PX := 60.0        # within this of the surface = surfaced
const SURFACE_REFILL_RATE := 30.0     # air/s while surfaced
const HULL_HP := 100.0
const CRUSH_DAMAGE_PER_S := 25.0
const PRESSURE_MAX_DEPTH := 800.0     # crush depth without beacons
const BEACONS_REQUIRED := 3
const BEACON_SCORE := 45
const BEACON_DEPTH_EXTENSION := 80.0  # max-depth gain per beacon collected
const BEACON_AIR_TOPUP := 12.0
const BEACON_COLLECT_RADIUS := 44.0
const BEACON_FLASH_TIME := 0.5        # bright reveal on collection
const BEACON_COLLECTED_ALPHA := 0.22  # the wreck beacon dims once taken
const DEPTH_BONUS_PER_PX := 1.0
const AIR_BONUS_PER_S := 10.0

# ---- milestone 3: engine bubble trail ----
const ENGINE_TRICKLE_SCALE := 0.35   # idle bubble speed_scale (faint trail)
const ENGINE_BUBBLE_ALPHA := 0.28    # idle bubble faintness

# ---- milestone 3: run pacing (gentle 3-run curve; dives counted in the save) --
const MAX_ATTEMPT_INDEX := 2                    # attempt index clamps here
const AIR_DRAIN_ATTEMPTS: Array[float] = [0.0, 0.05, 0.10]   # drain add per attempt
const WAKE_EARLY_ATTEMPTS: Array[float] = [0.0, 40.0, 80.0]  # px wake thresholds drop
const LURKERS_ATTEMPTS: Array[int] = [3, 3, 4]  # the 3rd dive adds a lurker
const LURKER_EXTRA_STEP := 760.0                # wake depth of the added lurker

# ---- milestone 3: polish feel ----
const VIGNETTE_START := 0.85          # vignette inner radius at full air
const VIGNETTE_END := 0.16            # vignette inner radius at empty air
const VIGNETTE_SOFTNESS := 0.34       # smoothstep falloff width
const VIGNETTE_ALPHA_MIN := 0.5
const VIGNETTE_ALPHA_MAX := 0.95
const CRUSH_SHAKE_AMP := 5.0          # px shake while past crush depth
const CRUSH_SHAKE_MIN := 0.55         # shake scale floor (never a dead frame)
const CRUSH_PULSE_FREQ := 7.0         # rad/s of the red warning pulse
const CRUSH_PULSE_ALPHA := 0.15       # peak red veil alpha
const CRUSH_SFX_INTERVAL := 1.1       # s between urgent pulse sfx while crushing
const FLASH_RADIUS := 320.0           # px the beacon radial flash sweeps
const FLASH_CORE_RADIUS := 46.0       # px hot core at the beacon
const FLASH_RING_GAP := 70.0          # px the second ping ring trails the first
const TALLY_LINE_STEP := 0.45         # s between win tally lines revealing
const TALLY_FADE := 0.25              # s each tally line fades in
const GULP_MIN_AIR := 1.0             # gulp sfx only when the refill matters

# ---- milestone 3: title screen ----
const TITLE_PULSE_FREQ := 2.4         # rad/s of "TAP TO DIVE" pulsing
const TITLE_PULSE_MIN := 0.35         # pulse alpha floor
const TITLE_SILHOUETTE_SPEED := 42.0  # px/s lurker silhouette drift
const TITLE_SILHOUETTE_ALPHA := 0.16  # barely-there silhouette (fear, not show)
const TITLE_SILHOUETTE_BOB := 14.0    # px sine bob of the silhouette
const TITLE_SILHOUETTE_BOB_FREQ := 0.5
const TITLE_BUBBLE_RATE := 6.0        # bubbles/s rising past the logo
const TITLE_LOGO_WIDTH_PX := 380.0
const VERSION_LINE := "TFS Jam '26"
const THEME_LINE := "It Came From Below"
const TITLE_HINT := "TAP TO DIVE"

# ---- milestone 3: procedural audio (scripts/sfx.gd reads these) ----
const SFX_SAMPLE_RATE := 22050        # Hz, mono 16-bit
const SFX_POOL_SIZE := 6              # one-shot voices
const SFX_MASTER_GAIN := 0.55         # headroom so layered cues never clip
const SAVE_PATH := "user://sonar_save.cfg"
const SAVE_KEY_DIVES := "dives"
const SAVE_KEY_MUTED := "muted"
# ping — descending sine sweep with a faint echo repeat
const PING_HZ_START := 880.0
const PING_HZ_END := 220.0
const PING_SECONDS := 0.5
const PING_ECHO_DELAY := 0.28
const PING_ECHO_GAIN := 0.32
# lurker growl — low sawtooth wobble
const GROWL_HZ := 52.0
const GROWL_WOBBLE_HZ := 5.0
const GROWL_WOBBLE_DEPTH := 0.3
const GROWL_SECONDS := 0.9
# beacon collect — rising arpeggio (C5 E5 G5 C6)
const BEACON_NOTES: Array[float] = [523.25, 659.25, 783.99, 1046.5]
const BEACON_NOTE_SECONDS := 0.14
const BEACON_SECONDS := 0.62
# gulp/surface — bubbly noise burst
const GULP_SECONDS := 0.45
const GULP_BLIP_HZ_LO := 300.0
const GULP_BLIP_HZ_HI := 1200.0
const GULP_BLIP_COUNT := 7
const GULP_NOISE_GAIN := 0.35
# crush warning — urgent low pulse
const CRUSH_HZ := 92.0
const CRUSH_GATE_HZ := 8.0
const CRUSH_SECONDS := 0.6
# death — deep thud + fading tone
const DEATH_THUD_HZ := 58.0
const DEATH_TONE_HZ := 110.0
const DEATH_SECONDS := 1.2
# win — soft major chord (C E G C)
const WIN_NOTES: Array[float] = [261.63, 329.63, 392.0, 523.25]
const WIN_SECONDS := 1.4


## Attempt index clamped into the 3-run curve.
static func curve_index(attempt: int) -> int:
	return clampi(attempt, 0, MAX_ATTEMPT_INDEX)


## Air drain multiplier for the dive attempt (1.0 / 1.05 / 1.1).
static func air_drain_mult(attempt: int) -> float:
	return 1.0 + AIR_DRAIN_ATTEMPTS[curve_index(attempt)]


## Lurker wake depth thresholds for the attempt (drop per attempt; an extra
## lurker joins the third dive). Pure so the battery can assert the curve.
static func lurker_steps(attempt: int) -> Array[float]:
	var idx := curve_index(attempt)
	var early := WAKE_EARLY_ATTEMPTS[idx]
	var steps: Array[float] = []
	for s in LURKER_DEPTH_STEPS:
		steps.append(maxf(s - early, 1.0))
	if LURKERS_ATTEMPTS[idx] > LURKER_DEPTH_STEPS.size():
		steps.append(LURKER_EXTRA_STEP - early)
	return steps


## Trailing echo ring radius for the ping ring (subtle second ring).
static func echo_ring_radius(radius: float) -> float:
	return maxf(0.0, radius - FLASH_RING_GAP)
