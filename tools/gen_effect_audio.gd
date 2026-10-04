extends SceneTree

## Story 7-1 (AC 30, `7-1/R5`): synthesizes the FOUR effect sound slots that ship without a Sonniss file --
## `soul` and `heal` (synth by the Scope table) and `bolt_strike` and `frost_hit` (no plausible part-1 file,
## ruled synth by `7-1/R5`) -- as native AudioStreamWAV resources, on the precedent of `6-5f`'s Counterspell stub
## generator (since retired with its stub sound, 7-1 review D5): code-generated, saved as `.tres` so no editor
## import pass is needed.
##
## DETERMINISTIC: the noise comes from a SEEDED RandomNumberGenerator owned by this tool, so a re-run writes
## byte-identical files. This is a tool, not `src/state/`; the seed only keeps the output reproducible.
##
## ALL FOUR ARE ONE-SHOTS that START ON THEIR IMPACT (AC 30's "leading silence trimmed so the sound lands on
## its impact frame" applied to a synthesized clip: there is no leading silence to trim, onset = 0.000 s).
##
## Invoke headlessly:
##   godot --headless --path . --script res://tools/gen_effect_audio.gd

const OUT_DIR := "res://assets/audio/effects/"
const MIX_RATE := 44100
const SEED := 71


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var ok := true
	ok = _save("sfx_soul", _soul()) and ok
	ok = _save("sfx_heal", _heal()) and ok
	ok = _save("sfx_bolt_strike", _bolt_strike(rng)) and ok
	ok = _save("sfx_frost_hit", _frost_hit(rng)) and ok
	quit(0 if ok else 1)


## A soul leaving a body: an airy sine GLIDING UP an octave and a half over 0.45 s, fading out -- the only
## rising glide in the set, so it reads as "something flew away".
func _soul() -> PackedFloat32Array:
	var n := int(MIX_RATE * 0.45)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var freq := lerpf(320.0, 900.0, t * t)
		phase += TAU * freq / MIX_RATE
		var env := minf(1.0, t * 20.0) * (1.0 - t)
		out[i] = (sin(phase) * 0.6 + sin(phase * 2.0) * 0.15) * env
	return out


## One lifesteal droplet arriving: a short two-partial chime (a fifth) with an exponential decay, 0.3 s.
func _heal() -> PackedFloat32Array:
	var n := int(MIX_RATE * 0.3)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var env := exp(-t * 14.0) * minf(1.0, float(i) / 60.0)
		out[i] = (sin(TAU * 1046.5 * t) * 0.5 + sin(TAU * 1568.0 * t) * 0.3) * env
	return out


## A thunder crack: a white-noise SNAP on sample 0 (sharp attack, the impact frame) under a one-pole
## low-passed rumble that decays over 1.1 s.
func _bolt_strike(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(MIX_RATE * 1.1)
	var out := PackedFloat32Array()
	out.resize(n)
	var low := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.035
		var snap := noise * exp(-t * 40.0)
		var rumble := low * 4.0 * exp(-t * 3.2)
		out[i] = clampf(snap * 0.8 + rumble, -1.0, 1.0)
	return out


## Ice shattering: a cluster of short high-passed noise ticks over the first 0.25 s, each with a
## glassy 3-5 kHz ring, total 0.5 s.
func _frost_hit(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(MIX_RATE * 0.5)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	var shards: Array = []
	for s in 9:
		shards.append([rng.randf_range(0.0, 0.25), rng.randf_range(3000.0, 5200.0)])
	for i in n:
		var t := float(i) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		var high := noise - prev
		prev = noise
		var v := high * 0.5 * exp(-t * 22.0)
		for shard: Array in shards:
			var dt: float = t - float(shard[0])
			if dt >= 0.0:
				v += sin(TAU * float(shard[1]) * dt) * 0.18 * exp(-dt * 45.0)
		out[i] = clampf(v, -1.0, 1.0)
	return out


func _save(name: String, samples: PackedFloat32Array) -> bool:
	var peak := 0.0
	for s in samples:
		peak = maxf(peak, absf(s))
	var gain := 0.9 / peak if peak > 0.0 else 1.0
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
	var path := OUT_DIR + name + ".tres"
	var err := ResourceSaver.save(stream, path)
	if err != OK:
		push_error("failed to save %s (error %d)" % [path, err])
		return false
	print("saved %s (%.2fs one-shot, onset 0.000s)" % [path, float(samples.size()) / MIX_RATE])
	return true
