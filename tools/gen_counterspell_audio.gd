extends SceneTree

## Story 6-5f (AC 26, `6-5f/R35`): synthesizes the COUNTERSPELL placeholder sting as a native
## AudioStreamWAV resource, on `tools/gen_cast_warning_audio.gd`'s and `tools/gen_charge_audio.gd`'s
## precedent verbatim (code-generated placeholder tone, saved as a native `.tres` so no editor import
## pass is needed -- `3-0a/R3` keeps the editor for FBX import only).
##
## A ONE-SHOT, UNLIKE THE CAST WARNING. A reversal is an EVENT that happens on one tick, not a span to
## cover, so this is the `cue_cast_success` / charge-sting family rather than the looping alarm.
##
## DISTINCT BY EAR (AC 26/smoke 8 ask for exactly this, against every other 6-5 placeholder). Every
## existing one-shot is a SINGLE short tone at a fixed pitch: the charge stings at 320/480/640 Hz, the
## cast-success cue at 880 Hz, each 0.18 s and each RISING or flat. This is a RISING TWO-NOTE PAIR with
## no gap -- 440 Hz into 660 Hz, a clean fifth, 0.22 s total -- so it is separated from all of them by
## being the only cue that CHANGES PITCH within one hit, and from the cast-warning alarm by rising where
## that one falls and by not repeating. "Something was taken back" reads as an upward resolve; the alarm
## it must not be confused with reads as a downward threat.
##
## Invoke headlessly:
##   godot --headless --path . --script res://tools/gen_counterspell_audio.gd

const OUT_PATH := "res://assets/audio/cue_counterspell.tres"
const MIX_RATE := 44100
const NOTE_SEC := 0.11
const LOW_HZ := 440.0
const HIGH_HZ := 660.0
const FADE_SEC := 0.012


## One note, with a short linear fade at both edges so the two notes and the tail have no click.
static func _write_note(bytes: PackedByteArray, at_sample: int, count: int, freq: float) -> void:
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
	var note := int(MIX_RATE * NOTE_SEC)
	var total := note * 2
	var bytes := PackedByteArray()
	bytes.resize(total * 2)
	_write_note(bytes, 0, note, LOW_HZ)
	_write_note(bytes, note, note, HIGH_HZ)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	# NO LOOP, unlike the cast warning: the cue is fired at the reversal, not held through anything.
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	var err := ResourceSaver.save(stream, OUT_PATH)
	if err != OK:
		push_error("failed to save %s (error %d)" % [OUT_PATH, err])
		quit(1)
		return
	print("saved %s (%.2fs one-shot, %.0f -> %.0f Hz)" % [OUT_PATH, float(total) / MIX_RATE,
			LOW_HZ, HIGH_HZ])
	quit(0)
