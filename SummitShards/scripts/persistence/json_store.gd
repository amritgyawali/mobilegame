extends RefCounted
## Small checksummed JSON documents (settings, profile) with a previous-write
## backup. Each document is independent of the round save, so resetting one
## never touches the others.

## Writes `data` atomically: temp file first, then the old primary becomes the
## backup, then the temp file becomes the primary.
static func write(path: String, data: Dictionary) -> bool:
	var payload: String = JSON.stringify(data)
	var envelope: String = JSON.stringify({"payload": payload, "sha256": payload.sha256_text()})
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(envelope)
	file.flush()
	file.close()
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(path + ".bak")
		if DirAccess.rename_absolute(path, path + ".bak") != OK:
			return false
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

## Returns the newest intact document, falling back to the backup, or an empty
## Dictionary when neither exists or both are damaged.
static func read(path: String) -> Dictionary:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		# JSON.new().parse reports failure through its result instead of
		# logging an engine error for an expected damaged file.
		var parser = JSON.new()
		if parser.parse(FileAccess.get_file_as_string(candidate)) != OK:
			continue
		var envelope = parser.data
		if not envelope is Dictionary or not envelope.get("payload") is String or not envelope.get("sha256") is String:
			continue
		if envelope.payload.sha256_text() != envelope.sha256 or parser.parse(envelope.payload) != OK:
			continue
		if parser.data is Dictionary:
			return parser.data
	return {}

static func remove(path: String) -> void:
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
