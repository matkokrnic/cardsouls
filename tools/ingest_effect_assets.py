"""Story 7-1 (AC 30/AC 31): INGEST the staged effect assets into the repo -- processed results only.

Raw sources stay OUTSIDE the repo (the operator stages them; this tool only reads them):
  --assets  C:/dev/_assets-71        rock FBX + 4K textures, hornman skull OBJ, Kenney particle packs
  --sonniss C:/dev/_sonniss/part1    the Sonniss GDC bundle, part 1

What it writes, and nothing else (AC 31: no .obj, no 4K PNG, no AO jpeg, no untrimmed .wav, no unused
Kenney PNG):
  assets/models/rock/rock_{basecolor,roughness}.jpg 4096 -> 1024
  assets/models/rock/rock_normal.png                4096 -> 1024 (PNG: no JPEG blocks in a normal map)
  assets/models/skull/skull.glb                     213,812 tris -> SKULL_TARGET_TRIS, centred, longest
                                                    extent 1.0 m (the scene scales it)
  assets/vfx/<name>.png                             KENNEY_PICKS only, 512 -> 256
  assets/audio/effects/sfx_<slot>.wav               one trimmed clip per non-synth slot (SOUND_PICKS)

The rock MESH is not written here (7-1 review fix P5): the staged FBX references its 4K source PNGs by path,
which made every fresh import of it log "Can't open file" errors. `tools/convert_rock_to_glb.gd` reads the
staged FBX at runtime and writes the material-less `assets/models/rock/rock.glb` instead.

THE TRIM RULE (AC 30), stated before the numbers: the FIRST VARIANT of the file -- from the first sample
above ONSET_DB (relative to the file's own peak) to the first run of at least GAP_SECONDS below it, capped
at the slot's max length -- with the leading silence removed so the sound lands on its impact frame, a
2 ms fade-in and a 30 ms fade-out. Mono, 16-bit, 44.1 kHz. The measured onset (seconds into the source)
is printed per file for the Dev Agent Record.

Packages: Pillow, numpy, scipy (wav I/O + resampling), trimesh + fast-simplification (decimation).
Invoke: python tools/ingest_effect_assets.py --assets C:/dev/_assets-71 --sonniss C:/dev/_sonniss/part1
"""
import argparse
import glob
import os

import numpy as np
from PIL import Image
from scipy.io import wavfile
from scipy.signal import resample_poly

REPO = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
SKULL_TARGET_TRIS = 3000
TEXTURE_MAX = 1024
KENNEY_SIZE = 256
OUT_RATE = 44100
ONSET_DB = -40.0
GAP_SECONDS = 0.25

KENNEY_PICKS = [
    "circle_02", "circle_05", "dirt_02", "flame_04", "magic_02", "scorch_02",
    "smoke_04", "spark_02", "star_06", "trace_04", "twirl_02",
]

# slot -> (filename fragment, reversed, max seconds). The weak first picks ship as picked (`7-1/R5`).
SOUND_PICKS = {
    "summon": ("FGHTImpt_4 x Punch, Body 02", False, 1.2),
    "cull": ("Vampire's Prison", False, 2.0),
    "ward": ("AMBDsgn_Evil Spell Ambience", False, 2.5),
    "raise": ("DSGNBass_Rattling Downer 3", False, 2.5),
    "drain": ("WINDDsgn_Wind, Rush, Whoosh, Long x5 01", True, 1.2),
    "aura": ("DSGNBass_Bass Drop & Downer Slow 10", False, 2.5),
    "rock_throw": ("WINDDsgn_Wind, Rush, Whoosh, Long x5 01", False, 1.0),
    "rock_hit": ("WEAPBlnt_Spear And Stick Impact, Wooden MKH 2", False, 1.0),
    "boom": ("DSGNBass_Bass Drop & Downer Fast 16", False, 1.5),
    "hound": ("ANMLDog_Dog Barks, Multiple, Indoors, Perspective,", False, 1.5),
    "fire_launch": ("AEROJet_Blast Off Clean", False, 1.2),
    "fire_loop": ("FIRECrkl_Fire Crackling, Popping, Witch's Cauldron", False, 3.0),
    "fire_hit": ("DSGNBass_Bass Drop & Downer Fast 12", False, 1.5),
    "bolt_charge": ("AMBSubn_Electricity Hum, Lightbulb,  Coil Pickup 01", False, 2.0),
    "counter": ("DSGNBass_Tone Downer (Reverb)", True, 1.5),
    "frost_arm": ("MAGMisc_Magic Christmas Bells 2", False, 1.5),
    "skull_launch": ("AEROJet_Unidentified Encounter", False, 1.5),
    # skull_hit reuses `summon` at another pitch (AC 30: one file may serve two slots) -- no file of its own.
}


def _out(*parts):
    path = os.path.join(REPO, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path


def ingest_rock(assets):
    src = os.path.join(assets, "models", "rock")
    for name, dest, fmt in [("Rock_MAT_BaseColor", "rock_basecolor.jpg", "JPEG"),
                            ("Rock_MAT_Roughness", "rock_roughness.jpg", "JPEG"),
                            ("Rock_MAT_Normal", "rock_normal.png", "PNG")]:
        im = Image.open(os.path.join(src, "textures", name + ".png")).convert("RGB")
        im = im.resize((TEXTURE_MAX, TEXTURE_MAX), Image.LANCZOS)
        kwargs = {"quality": 90} if fmt == "JPEG" else {"optimize": True}
        im.save(_out("assets", "models", "rock", dest), fmt, **kwargs)
        print("rock texture %s -> %s %dx%d" % (name, dest, im.size[0], im.size[1]))


def ingest_skull(assets):
    import fast_simplification
    import trimesh
    mesh = trimesh.load(os.path.join(assets, "models", "skull", "source", "hornman_skull.obj"),
                        force="mesh", process=True)
    before = len(mesh.faces)
    ratio = 1.0 - SKULL_TARGET_TRIS / before
    v, f = fast_simplification.simplify(mesh.vertices.astype(np.float32), mesh.faces.astype(np.int32),
                                        target_reduction=ratio)
    out = trimesh.Trimesh(v, f, process=True)
    out.apply_translation(-(out.bounds[0] + out.bounds[1]) / 2.0)
    out.apply_scale(1.0 / max(out.extents))
    out.export(_out("assets", "models", "skull", "skull.glb"))
    print("skull triangles %d -> %d (extents %s)" % (before, len(out.faces), np.round(out.extents, 3).tolist()))


def ingest_kenney(assets):
    src = os.path.join(assets, "vfx", "kenney_particle-pack", "PNG (Transparent)")
    for name in KENNEY_PICKS:
        im = Image.open(os.path.join(src, name + ".png")).convert("RGBA")
        im = im.resize((KENNEY_SIZE, KENNEY_SIZE), Image.LANCZOS)
        im.save(_out("assets", "vfx", name + ".png"), "PNG", optimize=True)
    print("kenney kept %d: %s" % (len(KENNEY_PICKS), ", ".join(KENNEY_PICKS)))


def _mono_float(path):
    rate, data = wavfile.read(path)
    if data.dtype == np.int16:
        x = data.astype(np.float64) / 32768.0
    elif data.dtype == np.int32:
        x = data.astype(np.float64) / 2147483648.0
    elif data.dtype == np.uint8:
        x = (data.astype(np.float64) - 128.0) / 128.0
    else:
        x = data.astype(np.float64)
    if x.ndim == 2:
        x = x.mean(axis=1)
    return rate, x


def _trim(x, rate, max_seconds):
    peak = np.max(np.abs(x)) or 1.0
    threshold = peak * (10.0 ** (ONSET_DB / 20.0))
    loud = np.abs(x) > threshold
    idx = np.flatnonzero(loud)
    if idx.size == 0:
        return x[:0], 0.0
    onset = int(idx[0])
    gap = int(GAP_SECONDS * rate)
    end = len(x)
    quiet_run = 0
    for i in range(onset, len(x)):
        if loud[i]:
            quiet_run = 0
        else:
            quiet_run += 1
            if quiet_run >= gap:
                end = i - quiet_run + 1
                break
    end = min(end, onset + int(max_seconds * rate))
    clip = x[onset:end].copy()
    fade_in = min(int(0.002 * rate), len(clip))
    fade_out = min(int(0.030 * rate), len(clip))
    if fade_in:
        clip[:fade_in] *= np.linspace(0.0, 1.0, fade_in)
    if fade_out:
        clip[-fade_out:] *= np.linspace(1.0, 0.0, fade_out)
    return clip / peak * 0.9, onset / rate


def ingest_sounds(sonniss):
    for slot, (fragment, reverse, max_seconds) in SOUND_PICKS.items():
        hits = [p for p in glob.glob(os.path.join(sonniss, "**", "*.wav"), recursive=True)
                if fragment in os.path.basename(p)]
        if len(hits) != 1:
            raise SystemExit("slot %s: expected exactly one file matching %r, found %d" % (slot, fragment, len(hits)))
        rate, x = _mono_float(hits[0])
        if reverse:
            x = x[::-1]
        clip, onset = _trim(x, rate, max_seconds)
        if rate != OUT_RATE:
            g = np.gcd(rate, OUT_RATE)
            clip = resample_poly(clip, OUT_RATE // g, rate // g)
        pcm = (np.clip(clip, -1.0, 1.0) * 32767.0).astype(np.int16)
        wavfile.write(_out("assets", "audio", "effects", "sfx_%s.wav" % slot), OUT_RATE, pcm)
        print("sound %-12s onset=%.3fs len=%.3fs rev=%s src=%s" % (
            slot, onset, len(pcm) / OUT_RATE, reverse, os.path.basename(hits[0])))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--assets", required=True)
    parser.add_argument("--sonniss", required=True)
    args = parser.parse_args()
    ingest_rock(args.assets)
    ingest_skull(args.assets)
    ingest_kenney(args.assets)
    ingest_sounds(args.sonniss)


if __name__ == "__main__":
    main()
