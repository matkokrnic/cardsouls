extends SceneTree

## Story 6-5c (AC 26): synthesizes the TARGET-SIDE CAST WARNING cue as a native AudioStreamWAV
## resource, on `tools/gen_charge_audio.gd`'s precedent verbatim (code-generated placeholder tone,
## saved as a native `.tres` so no editor import pass is needed -- `3-0a/R3` keeps the editor for
## FBX import only).
##
## WHY IT IS NOT ANOTHER ONE-SHOT STING. AC 26 needs a cue that lasts THE WHOLE CAST and ends at the
## strike or the interrupt, at any authored `cast_seconds`. A fixed-length one-shot would either
## outlast a short cast or fall silent inside a long one, and the length is authored data this tool
## must not learn. So this is a LOOPING clip: `TelegraphController.on_cast_warning_started` plays it
## and `on_cast_warning_ended` stops it, and the loop covers whatever span lies between.
##
## DISTINCT BY EAR (AC 26's own requirement). Every existing cue is a SINGLE short tone: the charge
## stings at 320/480/640 Hz and the cast-success cue at 880 Hz, each 0.18 s. This is a TWO-PULSE
## ALARM -- a falling pair (260 -> 190 Hz) with a silent gap, repeating -- so it is separated from
## them by pitch, by rhythm and by being the only cue that repeats while it is held.
##
## Invoke headlessly:
##   godot --headless --path . --script res://tools/gen_cast_warning_audio.gd

const OUT_PATH := "res://assets/audio/cue_cast_warning.tres"
const MIX_RATE := 44100
## One cycle of the alarm: pulse, gap, pulse, gap. Short enough that a cast at any plausible
## `cast_seconds` hears at least one full pair (0.8 s authored = ~2.7 cycles).
const PULSE_SEC := 0.09
const GAP_SEC := 0.06
const HIGH_HZ := 260.0
const LOW_HZ := 190.0
const FADE_SEC := 0.012


## One pulse, with a short linear fade at both edges so the loop has no click at the seam.
static func _write_pulse(bytes: PackedByteArray, at_sample: int, count: int, freq: float) -> void:
	var fade_len := int(MIX_RATE * FADE_SEC)
	for i in count:
		var env := 1.0
		if i < fade_len:
			env = float(i) / fade_len
		elif i > count - fade_len:
			env = float(count - i) / fade_len
		var sample := sin(TAU * freq * (float(i) / MIX_RATE)) * env
		bytes.encode_s16((at_sample + i) * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))


func _initialize() -> void:
	var pulse := int(MIX_RATE * PULSE_SEC)
	var gap := int(MIX_RATE * GAP_SEC)
	var total := (pulse + gap) * 2
	var bytes := PackedByteArray()
	bytes.resize(total * 2)
	_write_pulse(bytes, 0, pulse, HIGH_HZ)
	_write_pulse(bytes, pulse + gap, pulse, LOW_HZ)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	# THE LOOP IS THE POINT (see header): the cue is held for the cast, not fired at it.
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = total
	var err := ResourceSaver.save(stream, OUT_PATH)
	if err != OK:
		push_error("failed to save %s (error %d)" % [OUT_PATH, err])
		quit(1)
		return
	print("saved %s (%.2fs loop, %.0f/%.0f Hz)" % [OUT_PATH, float(total) / MIX_RATE, HIGH_HZ, LOW_HZ])
	quit(0)
