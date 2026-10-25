extends Node
## Short sound effects synthesized once, on a worker thread, at startup. No
## audio files, no streaming and a fixed pool of players, so playback never
## allocates nodes. Synthesis takes about 0.1 s of CPU even on a fast desktop;
## doing it off the main thread keeps it out of the app's first frames.

const MIX_RATE = 22050
const VOICES = 4
const RECIPES = {
	"tap": [[1320.0], 0.035, 0.5, 0.0],
	"select": [[880.0, 1175.0], 0.07, 0.55, 0.0],
	"place": [[196.0], 0.09, 0.9, 0.35],
	"clear": [[523.25, 659.25, 783.99, 1046.5], 0.32, 0.6, 0.0],
	"big": [[392.0, 523.25, 659.25, 783.99, 1046.5, 1318.5], 0.5, 0.6, 0.0],
	"invalid": [[155.56, 130.81], 0.14, 0.7, 0.15],
	"win": [[523.25, 659.25, 783.99, 1046.5, 1318.5, 1567.98], 0.9, 0.55, 0.0],
	"lose": [[392.0, 329.63, 261.63], 0.75, 0.55, 0.0],
}

var enabled: bool = true
# Headless runs (tests, CI) have no audio output and never retire playbacks.
var _silent_platform: bool = DisplayServer.get_name() == "headless"
var _streams: Dictionary = {}
var _built: Dictionary = {}
var _task_id: int = -1
var _players: Array = []
var _next_voice: int = 0

func _ready() -> void:
	for i in range(VOICES):
		var player = AudioStreamPlayer.new()
		player.volume_db = -9.0
		add_child(player)
		_players.append(player)
	_task_id = WorkerThreadPool.add_task(_synthesize_all, false, "Synthesize sound effects")

## Worker thread: pure computation into a dictionary the main thread adopts
## once the task reports completion.
func _synthesize_all() -> void:
	var built: Dictionary = {}
	for sound_name in RECIPES:
		var recipe: Array = RECIPES[sound_name]
		built[sound_name] = _tone(recipe[0], recipe[1], recipe[2], recipe[3])
	_built = built

## Adopts the synthesized sounds. With `wait`, blocks until they exist.
func _collect(wait: bool) -> bool:
	if _task_id >= 0 and (wait or WorkerThreadPool.is_task_completed(_task_id)):
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
		_streams = _built
	return _task_id < 0

func _exit_tree() -> void:
	_collect(true)
	stop_all()

func stop_all() -> void:
	for player in _players:
		player.stop()
		player.stream = null

func has_sound(sound_name: String) -> bool:
	_collect(true)
	return _streams.has(sound_name)

## Plays a sound if it is ready. The only sounds that could be skipped are
## those requested in the first instants after launch, before synthesis ends.
func play(sound_name: String, pitch: float = 1.0) -> void:
	if not enabled or _silent_platform or _players.is_empty() or not _collect(false):
		return
	if not _streams.has(sound_name):
		return
	var player: AudioStreamPlayer = _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	player.stream = _streams[sound_name]
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	player.play()

## Plays `notes` in sequence across `duration` seconds as soft bell-like tones.
## `noise` mixes in a little deterministic noise for percussive sounds.
func _tone(notes: Array, duration: float, level: float, noise: float) -> AudioStreamWAV:
	var total: int = int(MIX_RATE * duration)
	var per_note: int = maxi(1, total / notes.size())
	var data = PackedByteArray()
	data.resize(total * 2)
	var noise_state: int = 22222
	for i in range(total):
		var note_index: int = mini(notes.size() - 1, i / per_note)
		var local: float = float(i - note_index * per_note) / MIX_RATE
		var note_length: float = float(per_note) / MIX_RATE
		var freq: float = notes[note_index]
		var attack: float = clampf(local / 0.004, 0.0, 1.0)
		var decay: float = exp(-5.0 * local / note_length)
		var sample: float = sin(TAU * freq * local) * 0.8 + sin(TAU * freq * 2.0 * local) * 0.2
		if noise > 0.0:
			noise_state = (noise_state * 1103515245 + 12345) & 0x7fffffff
			sample = sample * (1.0 - noise) + (float(noise_state) / 0x7fffffff * 2.0 - 1.0) * noise
		# Fade the final few milliseconds to avoid an audible click.
		var tail: float = clampf(float(total - i) / (MIX_RATE * 0.006), 0.0, 1.0)
		var value: int = int(clampf(sample * attack * decay * tail * level, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, value)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
