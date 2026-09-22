class_name Save
extends RefCounted
## THE tiny save (spec law "constants_not_magic" — path/keys live in Feel).
## user:// config through a ConfigFile: completed dives (drives the 3-run
## difficulty curve + the title's "DIVE N") and the audio mute flag.
## Static and dependency-free so the battery can round-trip it headless.


static func _load() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(Feel.SAVE_PATH)   # missing file is fine — defaults below
	return cfg


static func store(cfg: ConfigFile) -> void:
	cfg.save(Feel.SAVE_PATH)


## Completed dives (0 on a fresh install). The next dive is dives + 1.
static func get_dives() -> int:
	return int(_load().get_value("run", Feel.SAVE_KEY_DIVES, 0))


static func set_dives(count: int) -> void:
	var cfg := _load()
	cfg.set_value("run", Feel.SAVE_KEY_DIVES, maxi(count, 0))
	store(cfg)


## A run just ended: count it.
static func bump_dives() -> int:
	var dives := get_dives() + 1
	set_dives(dives)
	return dives


static func is_muted() -> bool:
	return bool(_load().get_value("audio", Feel.SAVE_KEY_MUTED, false))


static func set_muted(on: bool) -> void:
	var cfg := _load()
	cfg.set_value("audio", Feel.SAVE_KEY_MUTED, on)
	store(cfg)


## Fresh install state — tests use this to stay deterministic.
static func reset() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("run", Feel.SAVE_KEY_DIVES, 0)
	cfg.set_value("audio", Feel.SAVE_KEY_MUTED, false)
	store(cfg)
