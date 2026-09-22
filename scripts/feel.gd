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
const LURKER_MAX_SPEED := 235.0       # close-range burst cap (sub is 260 — escapable)
const LURKER_ACCEL := 110.0           # px/s^2 toward the ping origin
const LURKER_CLOSE_RANGE := 150.0     # inside this, the burst kicks in
const LURKER_CLOSE_BURST := 2.1       # accel + cap multiplier in close range
const LURKER_IDLE_DRAG := 80.0        # px/s^2 vel decay while unaggroed
const LURKER_BOB_AMP := 9.0           # idle drift bob
const LURKER_BOB_FREQ := 0.7
const LURKER_WAKE_SIDE := 170.0       # wakes beside the sub's column, below view
const LURKER_WAKE_Y := 1010.0         # just under the view bottom (960)
const LURKER_DEPTH_STEPS: Array[float] = [200.0, 420.0, 640.0]
const DRIFTER_SPEED := 34.0           # lane patrol px/s
const DRIFTER_WAVE_AMP := 46.0        # sine bob px
const DRIFTER_WAVE_FREQ := 1.1        # rad/s
const DRIFTER_LANE_HALF_W := 90.0     # patrol half-width around the lane anchor
const DRIFTER_LANES: Array[Vector2] = [Vector2(120, 460), Vector2(430, 620)]

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
const BEACON_SCORE := 1000
const BEACON_DEPTH_EXTENSION := 80.0  # max-depth gain per beacon collected
const BEACON_AIR_TOPUP := 12.0
const BEACON_COLLECT_RADIUS := 44.0
const BEACON_FLASH_TIME := 0.5        # bright reveal on collection
const BEACON_COLLECTED_ALPHA := 0.22  # the wreck beacon dims once taken
const DEPTH_BONUS_PER_PX := 1.0
const AIR_BONUS_PER_S := 10.0
