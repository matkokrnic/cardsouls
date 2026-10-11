extends SceneTree

## Story 7-3 (AC 18, `7-3/R6`): synthesizes the PLACEHOLDER Hellhound bark as a native
## AudioStreamWAV resource, on `tools/gen_effect_audio.gd`'s precedent -- code-generated and saved
## as `.tres`, so no import pass and no third-party source. The pack ships no bark or howl take
## and no sound; the final bark is the art phase's.
##
## WHAT IT IS (retuned at the live smoke, which found the first one "terribly annoying": softer,
## lower, shorter): ONE short bark, 0.13 s. A low voice (a sawtooth whose pitch drops from 150 Hz to
## 85 Hz, with a detuned partner for roughness, both rounded off by a one-pole low-pass) under a
## quieter burst of low-passed noise, with a gentler attack and an exponential tail, written at half
## the peak level it had. The first version was two 0.16 s barks from 210 Hz at full level.
##
## DETERMINISTIC: the noise comes from a SEEDED RandomNumberGenerator owned by this tool, so a
## re-run writes a byte-identical file.
##
## Invoke headlessly:
##   godot --headless --path . --script res://tools/gen_hound_bark_audio.gd

const OUT_PATH := "res://assets/audio/effects/sfx_hound_bark.tres"
const MIX_RATE := 44100
const SEED := 73
const BARK_SECONDS := 0.13
## The peak level the file is written at (1.0 is full scale). The row's `volume_db` is on top of it.
const PEAK_LEVEL := 0.45
const PITCH_FROM_HZ := 150.0
const PITCH_TO_HZ := 85.0


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var bark_n := int(MIX_RATE * BARK_SECONDS)
	var samples := PackedFloat32Array()
	samples.resize(bark_n)
	_bark(samples, 0, bark_n, rng, 1.0)

	var peak := 0.0
	for s in samples:
		peak = maxf(peak, absf(s))
	var gain := PEAK_LEVEL / peak if peak > 0.0 else 1.0
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	var err := ResourceSaver.save(stream, OUT_PATH)
	if err != OK:
		push_error("failed to save %s (error %d)" % [OUT_PATH, err])
		quit(1)
		return
	print("saved %s (%.2fs one-shot, onset 0.000s)" % [OUT_PATH, float(samples.size()) / MIX_RATE])
	quit(0)


## One bark written into `out[start, start + n)`. `pitch` scales the whole voice.
func _bark(out: PackedFloat32Array, start: int, n: int, rng: RandomNumberGenerator, pitch: float) -> void:
	var phase := 0.0
	var phase_detuned := 0.0
	var low := 0.0
	var rounded := 0.0
	for i in n:
		var t := float(i) / n
		var freq := lerpf(PITCH_FROM_HZ, PITCH_TO_HZ, t) * pitch
		phase = fmod(phase + freq / MIX_RATE, 1.0)
		phase_detuned = fmod(phase_detuned + freq * 1.31 / MIX_RATE, 1.0)
		var voice := (phase * 2.0 - 1.0) * 0.6 + (phase_detuned * 2.0 - 1.0) * 0.25
		# The sawtooth's edge is what made the first bark harsh: a one-pole low-pass rounds it off.
		rounded += (voice - rounded) * 0.12
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.08
		var env := minf(1.0, t * 10.0) * exp(-t * 5.0)
		out[start + i] = (rounded + low * 0.5) * env
