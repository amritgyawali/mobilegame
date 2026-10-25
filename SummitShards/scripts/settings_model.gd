extends RefCounted
## Player preferences. Stored separately from the round so a new trail never
## resets them. Unknown or invalid values fall back to the defaults.

const DEFAULTS = {
	"sound": true,
	"reduced_motion": false,
	"clear_preview": true,
	"battery_saver": false,
}

var values: Dictionary = DEFAULTS.duplicate()

func get_value(key: String) -> bool:
	return bool(values.get(key, DEFAULTS.get(key, false)))

func set_value(key: String, value: bool) -> void:
	if DEFAULTS.has(key):
		values[key] = value

func toggle(key: String) -> void:
	set_value(key, not get_value(key))

func to_dict() -> Dictionary:
	var data: Dictionary = values.duplicate()
	data.version = 1
	return data

func from_dict(data: Dictionary) -> void:
	values = DEFAULTS.duplicate()
	for key in DEFAULTS:
		if data.get(key) is bool:
			values[key] = data[key]
