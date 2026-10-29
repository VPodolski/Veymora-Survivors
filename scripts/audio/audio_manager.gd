class_name AudioManager
extends Node

static var instance: AudioManager = null

var sfx_cast: AudioStreamWAV
var sfx_hit: AudioStreamWAV
var sfx_level_up: AudioStreamWAV
var sfx_synergy: AudioStreamWAV
var sfx_boss_alert: AudioStreamWAV
var sfx_chest: AudioStreamWAV

var players: Array[AudioStreamPlayer] = []
const MAX_PLAYERS = 8
var current_player_idx: int = 0

func _enter_tree() -> void:
	if instance == null:
		instance = self

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_players()
	_generate_audio_streams()

func _init_players() -> void:
	for i in range(MAX_PLAYERS):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		players.append(p)

func _play_stream(stream: AudioStreamWAV, volume_db: float = -6.0) -> void:
	if not stream or players.is_empty():
		return
	var p = players[current_player_idx]
	current_player_idx = (current_player_idx + 1) % MAX_PLAYERS
	p.stop()
	p.stream = stream
	p.volume_db = volume_db
	p.play()

func play_cast() -> void:
	_play_stream(sfx_cast, -8.0)

func play_hit() -> void:
	_play_stream(sfx_hit, -10.0)

func play_level_up() -> void:
	_play_stream(sfx_level_up, -4.0)

func play_synergy() -> void:
	_play_stream(sfx_synergy, -4.0)

func play_boss_alert() -> void:
	_play_stream(sfx_boss_alert, -2.0)

func play_chest() -> void:
	_play_stream(sfx_chest, -4.0)

# Procedural Sound Waveform Generation (Web-friendly, 0 external files)
func _generate_audio_streams() -> void:
	sfx_cast = _create_wav(0.09, 22050, func(t, dur):
		var freq = lerp(480.0, 880.0, t / dur)
		var env = 1.0 - (t / dur)
		return sin(t * TAU * freq) * env * 0.7
	)

	sfx_hit = _create_wav(0.06, 22050, func(t, dur):
		var env = exp(-t * 60.0)
		var noise = randf_range(-1.0, 1.0) * 0.4
		var tone = sin(t * TAU * 160.0) * 0.6
		return (noise + tone) * env
	)

	sfx_level_up = _create_wav(0.38, 22050, func(t, dur):
		var note_idx = int(floor((t / dur) * 4.0))
		var freqs = [523.25, 659.25, 783.99, 1046.50] # C5, E5, G5, C6
		var freq = freqs[clamp(note_idx, 0, 3)]
		var note_t = fmod(t, dur / 4.0)
		var env = 1.0 - (note_t / (dur / 4.0))
		return (sin(t * TAU * freq) + 0.3 * sin(t * TAU * freq * 2.0)) * env * 0.6
	)

	sfx_synergy = _create_wav(0.28, 22050, func(t, dur):
		var sweep = lerp(440.0, 1320.0, sqrt(t / dur))
		var env = sin((t / dur) * PI)
		var s1 = sin(t * TAU * sweep)
		var s2 = sin(t * TAU * sweep * 1.5) * 0.4
		return (s1 + s2) * env * 0.65
	)

	sfx_boss_alert = _create_wav(0.55, 22050, func(t, dur):
		var env = 1.0 - (t / dur)
		var saw = (fmod(t * 110.0, 1.0) * 2.0 - 1.0) * 0.5
		var sub = sin(t * TAU * 55.0) * 0.5
		return (saw + sub) * env * 0.8
	)

	sfx_chest = _create_wav(0.24, 22050, func(t, dur):
		var f1 = 880.0
		var f2 = 1320.0
		var env = exp(-t * 12.0)
		return (sin(t * TAU * f1) + sin(t * TAU * f2)) * 0.5 * env
	)

func _create_wav(duration: float, sample_rate: int, synth_func: Callable) -> AudioStreamWAV:
	var total_samples = int(duration * sample_rate)
	var bytes = PackedByteArray()
	bytes.resize(total_samples)

	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		var sample: float = synth_func.call(t, duration)
		sample = clamp(sample, -1.0, 1.0)
		# 8-bit unsigned PCM: 0..255 with 128 as silence
		var byte_val = int(floor((sample * 0.5 + 0.5) * 255.0))
		bytes[i] = clamp(byte_val, 0, 255)

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = bytes
	return wav
