class_name AudioManager
extends Node

const SaveManager = preload("res://scripts/game/save_manager.gd")

static var instance: AudioManager = null

var sfx_cast: AudioStreamWAV
var sfx_hit: AudioStreamWAV
var sfx_level_up: AudioStreamWAV
var sfx_synergy: AudioStreamWAV
var sfx_boss_alert: AudioStreamWAV
var sfx_chest: AudioStreamWAV
var sfx_evolution: AudioStreamWAV

# Distinct Synergy Sound Signatures (v0.4)
var sfx_resonance: AudioStreamWAV
var sfx_frost_shatter: AudioStreamWAV
var sfx_lightning_chain: AudioStreamWAV
var sfx_steam_rift: AudioStreamWAV
var sfx_thermal_conflagration: AudioStreamWAV
var sfx_soul_harvest: AudioStreamWAV
var sfx_unstable_explosion: AudioStreamWAV
var sfx_spatial_collapse: AudioStreamWAV

var players: Array[AudioStreamPlayer] = []
const MAX_PLAYERS = 10
var current_player_idx: int = 0

var master_volume: float = 1.0
var sfx_volume: float = 0.8
var hit_cooldown: float = 0.05
var hit_cooldown_timer: float = 0.0
var is_temporary_muted: bool = false
var synergy_sfx_cooldowns: Dictionary = {}

func _enter_tree() -> void:
	if instance == null:
		instance = self

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	master_volume = clampf(float(SaveManager.get_setting("master_volume", 1.0)), 0.0, 1.0)
	sfx_volume = clampf(float(SaveManager.get_setting("sfx_volume", 0.8)), 0.0, 1.0)
	_init_players()
	_generate_audio_streams()

func _process(delta: float) -> void:
	if hit_cooldown_timer > 0.0:
		hit_cooldown_timer = max(0.0, hit_cooldown_timer - delta)

	for k in synergy_sfx_cooldowns.keys():
		synergy_sfx_cooldowns[k] -= delta
		if synergy_sfx_cooldowns[k] <= 0.0:
			synergy_sfx_cooldowns.erase(k)

func _init_players() -> void:
	for i in range(MAX_PLAYERS):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		players.append(p)

func set_temporary_mute(muted: bool) -> void:
	is_temporary_muted = muted
	AudioServer.set_bus_mute(0, muted)
	if muted:
		stop_all_sfx()
	update_playing_volumes()

func stop_all_sfx() -> void:
	for p in players:
		if is_instance_valid(p) and p.playing:
			p.stop()

func set_master_volume(val: float) -> void:
	master_volume = clampf(val, 0.0, 1.0)
	update_playing_volumes()

func set_sfx_volume(val: float) -> void:
	sfx_volume = clampf(val, 0.0, 1.0)
	update_playing_volumes()

func update_playing_volumes() -> void:
	var effective_gain = master_volume * sfx_volume
	for p in players:
		if is_instance_valid(p) and p.playing:
			p.volume_db = -6.0 + linear_to_db(effective_gain)

func _play_stream(stream: AudioStreamWAV, base_volume_db: float = -6.0, randomize_pitch: bool = true) -> void:
	if is_temporary_muted or not stream or players.is_empty():
		return
	if master_volume <= 0.001 or sfx_volume <= 0.001:
		return
	var p = players[current_player_idx]
	current_player_idx = (current_player_idx + 1) % MAX_PLAYERS
	p.stop()
	p.stream = stream
	var effective_gain = master_volume * sfx_volume
	p.volume_db = base_volume_db + linear_to_db(effective_gain)
	if randomize_pitch:
		p.pitch_scale = randf_range(0.96, 1.04)
	else:
		p.pitch_scale = 1.0
	p.play()

func play_cast() -> void:
	_play_stream(sfx_cast, -8.0, true)

func play_hit() -> void:
	if hit_cooldown_timer > 0.0:
		return
	hit_cooldown_timer = hit_cooldown
	_play_stream(sfx_hit, -10.0, true)

func play_level_up() -> void:
	_play_stream(sfx_level_up, -4.0, false)

func play_synergy(synergy_name: String = "") -> void:
	if not synergy_name.is_empty():
		if synergy_sfx_cooldowns.has(synergy_name):
			return
		synergy_sfx_cooldowns[synergy_name] = 0.09

	match synergy_name:
		"resonance":
			_play_stream(sfx_resonance, -4.0, true)
		"frost_shatter":
			_play_stream(sfx_frost_shatter, -4.0, true)
		"lightning_chain":
			_play_stream(sfx_lightning_chain, -4.0, true)
		"steam_rift":
			_play_stream(sfx_steam_rift, -4.0, true)
		"thermal_conflagration":
			_play_stream(sfx_thermal_conflagration, -3.0, true)
		"soul_harvest":
			_play_stream(sfx_soul_harvest, -3.5, false)
		"unstable_explosion":
			_play_stream(sfx_unstable_explosion, -3.5, false)
		"spatial_collapse":
			_play_stream(sfx_spatial_collapse, -3.5, false)
		_:
			_play_stream(sfx_synergy, -4.0, false)

func play_boss_alert() -> void:
	_play_stream(sfx_boss_alert, -2.0, false)

func play_chest() -> void:
	_play_stream(sfx_chest, -4.0, false)

func play_evolution() -> void:
	_play_stream(sfx_evolution, -2.0, false)

# Procedural Sound Waveform Generation (Web-friendly, 0 external files, 16-bit smooth PCM)
func _generate_audio_streams() -> void:
	# Majestic resonant chord for spell evolution (C5 + G5 + E6)
	sfx_evolution = _create_wav(0.55, 22050, func(t, _dur):
		var attack = min(1.0, t / 0.02)
		var decay = exp(-t * 5.0)
		var env = attack * decay
		var c5 = sin(t * TAU * 523.25)
		var g5 = sin(t * TAU * 783.99) * 0.7
		var e6 = sin(t * TAU * 1318.51) * 0.4
		return (c5 + g5 + e6) * 0.45 * env
	)

	# Soft celestial chime for spell casts
	sfx_cast = _create_wav(0.12, 22050, func(t, _dur):
		var attack = min(1.0, t / 0.012)
		var decay = exp(-t * 18.0)
		var env = attack * decay
		var tone1 = sin(t * TAU * 520.0)
		var tone2 = sin(t * TAU * 1040.0) * 0.22
		return (tone1 + tone2) * env * 0.65
	)

	# Warm wooden/teardrop pop for enemy impacts
	sfx_hit = _create_wav(0.06, 22050, func(t, dur):
		var attack = min(1.0, t / 0.003)
		var decay = exp(-t * 52.0)
		var freq = lerp(190.0, 65.0, t / dur)
		return sin(t * TAU * freq) * attack * decay * 0.7
	)

	# Warm ascending major arpeggio for level up
	sfx_level_up = _create_wav(0.44, 22050, func(t, dur):
		var note_dur = dur / 4.0
		var freqs = [523.25, 659.25, 783.99, 1046.50]
		var note_idx = clamp(int(floor(t / note_dur)), 0, 3)
		var note_t = fmod(t, note_dur)
		var freq = freqs[note_idx]
		var attack = min(1.0, note_t / 0.008)
		var decay = exp(-note_t * 12.0)
		var tone1 = sin(note_t * TAU * freq)
		var tone2 = sin(note_t * TAU * freq * 2.0) * 0.15
		return (tone1 + tone2) * attack * decay * 0.6
	)

	# Default Harmonious ethereal two-tone chord
	sfx_synergy = _create_wav(0.36, 22050, func(t, _dur):
		var attack = min(1.0, t / 0.02)
		var decay = exp(-t * 8.5)
		var env = attack * decay
		var s1 = sin(t * TAU * 659.25)
		var s2 = sin(t * TAU * 987.77) * 0.7
		return (s1 + s2) * 0.5 * env * 0.7
	)

	# 1. Arcane Resonance: Pure crystal-smooth chord (E5 + B5 + G#5)
	sfx_resonance = _create_wav(0.34, 22050, func(t, _dur):
		var attack = min(1.0, t / 0.015)
		var decay = exp(-t * 7.5)
		var env = attack * decay
		var e5 = sin(t * TAU * 659.25)
		var b5 = sin(t * TAU * 987.77) * 0.6
		var gs5 = sin(t * TAU * 830.61) * 0.35
		return (e5 + b5 + gs5) * 0.45 * env
	)

	# 2. Frost Shatter: Sharp crystalline fracture chime (C6 + G6 down-glide)
	sfx_frost_shatter = _create_wav(0.24, 22050, func(t, dur):
		var attack = min(1.0, t / 0.004)
		var decay = exp(-t * 16.0)
		var freq1 = lerp(1200.0, 950.0, t / dur)
		var freq2 = lerp(1800.0, 1400.0, t / dur)
		var tone1 = sin(t * TAU * freq1)
		var tone2 = sin(t * TAU * freq2) * 0.4
		return (tone1 + tone2) * attack * decay * 0.65
	)

	# 3. Lightning Chain: Snappy electric arc zap (snappy 440 -> 180 Hz)
	sfx_lightning_chain = _create_wav(0.18, 22050, func(t, dur):
		var attack = min(1.0, t / 0.003)
		var decay = exp(-t * 22.0)
		var freq = lerp(480.0, 140.0, t / dur)
		var arc = sin(t * TAU * freq) + sin(t * TAU * freq * 2.3) * 0.25
		return arc * attack * decay * 0.7
	)

	# 4. Steam Rift: Soft vapor hiss / expansion (smooth air glide)
	sfx_steam_rift = _create_wav(0.32, 22050, func(t, dur):
		var attack = min(1.0, t / 0.03)
		var decay = exp(-t * 8.0)
		var freq = lerp(260.0, 130.0, t / dur)
		var puff = sin(t * TAU * freq) + sin(t * TAU * (freq * 1.5)) * 0.4
		return puff * attack * decay * 0.55
	)

	# 5. Thermal Conflagration: Deep warm plasma blast (punchy 95 Hz + rising overtones)
	sfx_thermal_conflagration = _create_wav(0.38, 22050, func(t, dur):
		var attack = min(1.0, t / 0.01)
		var decay = exp(-t * 9.0)
		var base_freq = lerp(110.0, 60.0, t / dur)
		var sub = sin(t * TAU * base_freq) * 0.8
		var overtone = sin(t * TAU * base_freq * 2.0) * 0.4
		return (sub + overtone) * attack * decay * 0.75
	)

	# 6. Soul Harvest: Dark ethereal soul hum (resonant 120 Hz with minor undertone)
	sfx_soul_harvest = _create_wav(0.42, 22050, func(t, _dur):
		var attack = min(1.0, t / 0.025)
		var decay = exp(-t * 6.5)
		var tone = sin(t * TAU * 130.81) * 0.7 + sin(t * TAU * 155.56) * 0.4
		return tone * attack * decay * 0.7
	)

	# 7. Unstable Explosion: Void rift fracture pop (sub-harmonic sweep)
	sfx_unstable_explosion = _create_wav(0.35, 22050, func(t, dur):
		var attack = min(1.0, t / 0.008)
		var decay = exp(-t * 11.0)
		var freq = lerp(180.0, 50.0, t / dur)
		var warp = sin(t * TAU * freq) * 0.7 + sin(t * TAU * freq * 3.0) * 0.2
		return warp * attack * decay * 0.7
	)

	# 8. Spatial Collapse: Singularity inward vortex swell
	sfx_spatial_collapse = _create_wav(0.38, 22050, func(t, dur):
		var progress = t / dur
		var attack = min(1.0, t / 0.02)
		var decay = exp(-max(0.0, t - 0.22) * 14.0)
		var freq = lerp(75.0, 240.0, progress)
		var pulse = sin(t * TAU * freq) * attack * decay * 0.7
		return pulse
	)

	# Cinematic deep brass / sub swell for boss encounter
	sfx_boss_alert = _create_wav(0.65, 22050, func(t, _dur):
		var attack = min(1.0, t / 0.14)
		var decay = exp(-max(0.0, t - 0.14) * 4.5)
		var env = attack * decay
		var sub = sin(t * TAU * 55.0)
		var low = sin(t * TAU * 110.0) * 0.5
		var mid = sin(t * TAU * 165.0) * 0.25
		return (sub + low + mid) * 0.6 * env * 0.7
	)

	# Ascending 4-note celebration arpeggio for chest reward (F5, A5, C6, F6)
	sfx_chest = _create_wav(0.36, 22050, func(t, dur):
		var note_dur = dur / 4.0
		var freqs = [698.46, 880.00, 1046.50, 1396.91]
		var note_idx = clamp(int(floor(t / note_dur)), 0, 3)
		var note_t = fmod(t, note_dur)
		var freq = freqs[note_idx]
		var attack = min(1.0, note_t / 0.006)
		var decay = exp(-note_t * 14.0)
		var tone1 = sin(note_t * TAU * freq)
		var tone2 = sin(note_t * TAU * freq * 2.0) * 0.2
		return (tone1 + tone2) * attack * decay * 0.65
	)

func _create_wav(duration: float, sample_rate: int, synth_func: Callable) -> AudioStreamWAV:
	var total_samples = int(duration * sample_rate)
	var bytes = PackedByteArray()
	bytes.resize(total_samples * 2)

	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		var sample: float = synth_func.call(t, duration)
		sample = clampf(sample, -1.0, 1.0)
		var sample_i16 = int(round(sample * 32767.0))
		bytes.encode_s16(i * 2, sample_i16)

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = bytes
	return wav
