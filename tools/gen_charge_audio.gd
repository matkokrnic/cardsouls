extends SceneTree

## Story 5-3 (AC 10, AC 13): synthesizes FOUR short placeholder tones as native AudioStreamWAV
## resources -- one per CHARGING colour's sting (S8's discrimination discipline needs them
## AUDIBLY DISTINCT, so each gets its own frequency) and one for the new cast-success cue
## (S5's audio obligation). PLACEHOLDER AESTHETIC, same doctrine `FacingMarker` already states
## in hero.tscn ("Pure sub-resource authoring, no assets") -- these are code-generated sine
## tones, not authored sound design, so a future audio pass can swap the .tres content without
## touching any dispatch code (mirrors the 5-0a/R1 strafe-clip-swap precedent: content swap,
## no code change).
##
## Saved as NATIVE .tres resources (ResourceSaver.save on an AudioStreamWAV built in memory),
## not raw .wav files -- this avoids a second editor import pass for binary audio assets the
## editor would otherwise need to scan (3-0a/R3 keeps the editor for import only, and native
## resources need no import step at all).
##
## Invoke headlessly:
##   godot --headless --path . --script res://tools/gen_charge_audio.gd

const OUT_DIR := "res://assets/audio/"
const MIX_RATE := 44100
const DURATION_SEC := 0.18

## clip name -> (frequency Hz, harmonic ratio for a thin two-tone chime)
const TONES := {
	"sting_charge_red": 320.0,
	"sting_charge_blue": 480.0,
	"sting_charge_green": 640.0,
	"cue_cast_success": 880.0,
}


static func _make_tone(freq: float) -> AudioStreamWAV:
	var sample_count := int(MIX_RATE * DURATION_SEC)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for i in sample_count:
		var t := float(i) / MIX_RATE
		# Short linear fade in/out so the clip has no click at either edge.
		var fade_len := int(MIX_RATE * 0.02)
		var env := 1.0
		if i < fade_len:
			env = float(i) / fade_len
		elif i > sample_count - fade_len:
			env = float(sample_count - i) / fade_len
		var sample := sin(TAU * freq * t) * env
		var v := int(clampf(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream


func _initialize() -> void:
	for clip: String in TONES:
		var stream := _make_tone(TONES[clip])
		var path := OUT_DIR + clip + ".tres"
		var err := ResourceSaver.save(stream, path)
		if err != OK:
			push_error("failed to save %s (error %d)" % [path, err])
			quit(1)
			return
		print("saved %s (%.0f Hz, %.2fs)" % [path, TONES[clip], DURATION_SEC])
	quit(0)
