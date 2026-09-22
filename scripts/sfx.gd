class_name Sfx
extends Node
## PROCEDURAL AUDIO (jam law "original_assets" — every sound generated in
## code, no shipped WAVs). Each cue is synthesized once into an AudioStreamWAV
## (mono 16-bit at Feel.SFX_SAMPLE_RATE) and replayed through a small fixed
## pool of AudioStreamPlayers, so rapid pings never allocate or free nodes.
## Web-export safe: plain AudioStreamWAV + AudioStreamPlayer, no threads.
## Cues: ping (descending sweep + faint echo), growl (low saw wobble),
## beacon (rising arpeggio), gulp (bubbly burst), crush (urgent low pulse),
## death (thud + fading tone), win (soft major chord).
## Mute is a user preference persisted through Save (user:// config).

const CUE_NAMES: Array[String] = ["ping", "growl", "beacon", "gulp", "crush", "death", "win"]

var muted := false
var cues := {}                     # name -> AudioStreamWAV

var _pool: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _blip_rng := RandomNumberGenerator.new()


func _ready() -> void:
	muted = Save.is_muted()
	_build_pool()
	# Synthesizing ~6s of audio is real work — do it just off the boot path so
	# scene _ready stays instant (web boot + the replays' frame phasing).
	_build_cues.call_deferred()


## Release every voice on teardown so a quit mid-sound leaves nothing behind:
## stop under the audio server lock so the playbacks retire synchronously.
func _exit_tree() -> void:
	AudioServer.lock()
	for player in _pool:
		player.stop()
		player.stream = null
	AudioServer.unlock()


# ------------------------------------------------------------------ play --

## Fire and forget: hand the named cue to the next pool voice and move on.
## Returns false while muted or for unknown names (battery checks this).
func play(cue: String) -> bool:
	if muted:
		return false
	if not cues.has(cue):
		if not CUE_NAMES.has(cue):
			return false
		_build_cues()   # a play beat the deferred build — synthesize now
	if not cues.has(cue):
		return false
	if _pool.is_empty():
		_build_pool()
	var player := _pool[_next_voice]
	_next_voice = (_next_voice + 1) % _pool.size()
	player.stop()
	player.stream = cues[cue]
	# Outside the scene tree (headless runs) playback is a silent no-op.
	if is_inside_tree():
		player.play()
	return true


## Persisted mute toggle — returns the new state.
func toggle_muted() -> bool:
	set_muted(not muted)
	return muted


func set_muted(on: bool) -> void:
	muted = on
	Save.set_muted(on)
	if on:
		for player in _pool:
			player.stop()


# ------------------------------------------------------------------ synth --

func _build_cues() -> void:
	if not cues.is_empty():
		return
	_blip_rng.seed = 0x5EED   # deterministic bubbles — the battery re-hears them
	cues["ping"] = _bake(_synth_ping())
	cues["growl"] = _bake(_synth_growl())
	cues["beacon"] = _bake(_synth_beacon())
	cues["gulp"] = _bake(_synth_gulp())
	cues["crush"] = _bake(_synth_crush())
	cues["death"] = _bake(_synth_death())
	cues["win"] = _bake(_synth_win())


## Linear attack, then a fast power decay to silence at the cue end.
static func _env(t: float, attack: float, seconds: float) -> float:
	if t < attack:
		return t / maxf(attack, 0.001)
	var u := (t - attack) / maxf(seconds - attack, 0.001)
	return pow(1.0 - clampf(u, 0.0, 1.0), 1.6)


static func _samples(seconds: float) -> int:
	return int(seconds * float(Feel.SFX_SAMPLE_RATE))


## THE ping: a descending sine sweep (880 -> 220 Hz) with a faint echo repeat
## of the whole sweep one PING_ECHO_DELAY later.
func _synth_ping() -> PackedFloat32Array:
	var sweep_n := _samples(Feel.PING_SECONDS)
	var n := sweep_n + _samples(Feel.PING_ECHO_DELAY)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var dry := PackedFloat32Array()
	dry.resize(sweep_n)
	var phase := 0.0
	for i in sweep_n:
		var t := float(i) / float(Feel.SFX_SAMPLE_RATE)
		var f := Feel.PING_HZ_START * pow(Feel.PING_HZ_END / Feel.PING_HZ_START,
				t / Feel.PING_SECONDS)
		phase += TAU * f / float(Feel.SFX_SAMPLE_RATE)
		dry[i] = sin(phase) * _env(t, 0.004, Feel.PING_SECONDS)
		buf[i] = dry[i]
	var delay := _samples(Feel.PING_ECHO_DELAY)
	for i in sweep_n:
		var j := i + delay
		if j < n:
			buf[j] += dry[i] * Feel.PING_ECHO_GAIN
	return buf


## THE lurker: a low sawtooth whose pitch wobbles, lowpassed so it reads as a
## throat and not a buzzer.
func _synth_growl() -> PackedFloat32Array:
	var n := _samples(Feel.GROWL_SECONDS)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / float(Feel.SFX_SAMPLE_RATE)
		var f := Feel.GROWL_HZ * (1.0 + Feel.GROWL_WOBBLE_DEPTH
				* sin(TAU * Feel.GROWL_WOBBLE_HZ * t))
		phase += TAU * f / float(Feel.SFX_SAMPLE_RATE)
		var saw := fposmod(phase / TAU, 1.0) * 2.0 - 1.0
		lp += (saw - lp) * 0.18
		buf[i] = lp * _env(t, 0.05, Feel.GROWL_SECONDS) * 1.6
	return buf


## THE beacon: a rising arpeggio, each note ringing into the next.
func _synth_beacon() -> PackedFloat32Array:
	var n := _samples(Feel.BEACON_SECONDS)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for k in Feel.BEACON_NOTES.size():
		var start_i := _samples(float(k) * Feel.BEACON_NOTE_SECONDS)
		var len_i := _samples(Feel.BEACON_NOTE_SECONDS * 1.9)
		var phase := 0.0
		for j in len_i:
			var i := start_i + j
			if i >= n:
				break
			var t := float(j) / float(Feel.SFX_SAMPLE_RATE)
			phase += TAU * Feel.BEACON_NOTES[k] / float(Feel.SFX_SAMPLE_RATE)
			var env := minf(t / 0.008, 1.0) * exp(-t * 9.0)
			buf[i] += (sin(phase) + 0.22 * sin(phase * 2.0)) * env * 0.6
	return buf


## THE surface: a bubbly noise burst — filtered noise plus rising bubble
## chirps (deterministic via the seeded blip rng).
func _synth_gulp() -> PackedFloat32Array:
	var n := _samples(Feel.GULP_SECONDS)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / float(Feel.SFX_SAMPLE_RATE)
		buf[i] = _blip_rng.randf_range(-1.0, 1.0) * Feel.GULP_NOISE_GAIN * exp(-t * 7.0)
	for k in Feel.GULP_BLIP_COUNT:
		var frac := float(k) / float(maxi(Feel.GULP_BLIP_COUNT - 1, 1))
		var start_i := _samples(frac * Feel.GULP_SECONDS * 0.8)
		var f := lerpf(Feel.GULP_BLIP_HZ_LO, Feel.GULP_BLIP_HZ_HI, frac)
		var len_i := _samples(0.09)
		var phase := 0.0
		for j in len_i:
			var i := start_i + j
			if i >= n:
				break
			var t := float(j) / float(Feel.SFX_SAMPLE_RATE)
			phase += TAU * (f * (1.0 + 1.5 * t)) / float(Feel.SFX_SAMPLE_RATE)
			buf[i] += sin(phase) * exp(-t * 40.0) * 0.7
	return buf


## THE crush warning: an urgent low pulse — a falling low tone gated hard.
func _synth_crush() -> PackedFloat32Array:
	var n := _samples(Feel.CRUSH_SECONDS)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(Feel.SFX_SAMPLE_RATE)
		phase += TAU * Feel.CRUSH_HZ * (1.0 - 0.25 * t / Feel.CRUSH_SECONDS) \
				/ float(Feel.SFX_SAMPLE_RATE)
		var gate := 1.0 if sin(TAU * Feel.CRUSH_GATE_HZ * t) > 0.0 else 0.15
		buf[i] = (sin(phase) + 0.3 * sin(phase * 3.0)) * gate \
				* _env(t, 0.01, Feel.CRUSH_SECONDS)
	return buf


## THE end: a deep thud (dropping pitch, fast decay) under a long fading tone.
func _synth_death() -> PackedFloat32Array:
	var n := _samples(Feel.DEATH_SECONDS)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var thud_phase := 0.0
	var tone_phase := 0.0
	for i in n:
		var t := float(i) / float(Feel.SFX_SAMPLE_RATE)
		var f := Feel.DEATH_THUD_HZ * (1.0 - 0.6 * minf(t / 0.25, 1.0))
		thud_phase += TAU * f / float(Feel.SFX_SAMPLE_RATE)
		tone_phase += TAU * Feel.DEATH_TONE_HZ / float(Feel.SFX_SAMPLE_RATE)
		buf[i] = sin(thud_phase) * exp(-t * 14.0) * 1.1 \
				+ sin(tone_phase) * exp(-t * 2.2) * 0.4
	return buf


## THE win: a soft major chord — staggered phase, slow attack, gentle release.
func _synth_win() -> PackedFloat32Array:
	var n := _samples(Feel.WIN_SECONDS)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phases := PackedFloat32Array()
	phases.resize(Feel.WIN_NOTES.size())
	for k in Feel.WIN_NOTES.size():
		phases[k] = float(k) * 0.7
	for i in n:
		var t := float(i) / float(Feel.SFX_SAMPLE_RATE)
		var env := minf(t / 0.18, 1.0) * clampf((Feel.WIN_SECONDS - t) / 0.5, 0.0, 1.0)
		var s := 0.0
		for k in Feel.WIN_NOTES.size():
			phases[k] += TAU * Feel.WIN_NOTES[k] / float(Feel.SFX_SAMPLE_RATE)
			s += sin(phases[k]) + 0.18 * sin(phases[k] * 2.0)
		buf[i] = s * env * 0.22
	return buf


## Float buffer -> mono 16-bit AudioStreamWAV with master headroom.
static func _bake(buf: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		var v := int(clampf(buf[i] * Feel.SFX_MASTER_GAIN, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = Feel.SFX_SAMPLE_RATE
	wav.stereo = false
	wav.data = bytes
	return wav


# ------------------------------------------------------------------ pool --

func _build_pool() -> void:
	if not _pool.is_empty():
		return
	for i in Feel.SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % i
		add_child(player)
		_pool.append(player)
