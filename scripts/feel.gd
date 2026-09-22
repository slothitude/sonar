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

# ---- placeholders: milestone 2 (spec.systems.survival / goal) ----
const AIR_SECONDS := 60.0
const SURFACE_REFILL_RATE := 30.0     # air/s while surfaced
const PRESSURE_MAX_DEPTH := 800.0     # crush depth without upgrades
const BEACONS_REQUIRED := 3
const BEACON_SCORE := 1000
