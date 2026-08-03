extends SceneTree

## Story 3-2 (AC 6, second half): the CardDatabase AUTOLOAD actually populates itself at boot.
##
## WHY THIS CANNOT BE A STATE-HARNESS TEST. The state harness runs every test in
## _initialize() with no autoload and no frame — needing either is a design leak, not a
## harness limitation (the E0 test-harness constraint). So nothing in it ever exercises
## CardDatabase._ready(). test_card_authoring.gd proves the .tres CONTENT is right by loading
## the files itself; that would still pass with a loader whose body were deleted. A silently
## empty card dictionary is today noticed by NOTHING else — this file is the only thing that
## would bite, which is exactly why the story requires it.
##
## This is also the whole of this story's live-run proof: CardDatabase is an autoload, not a
## story-gated seam, so its _ready() runs in every live run and in every integration run. The
## story ships no HUD, no input, and no state consumer, so there is nothing a human could look
## at — the observable claim is "no failure in the boot path", and run_all.sh's grep for
## SCRIPT ERROR / Parse Error / INVARIANT VIOLATED is what checks it.
##
## Reached through /root/CardDatabase — the REAL autoload the project boots, never a private
## instance the test constructs. A test that instantiated the script itself would pass even if
## the autoload registration were removed from project.godot.
##
## Run: godot --headless --path . --script res://test/integration/test_card_database.gd
## (read ${PIPESTATUS[0]} / set -o pipefail so grep can't mask the exit code.)

## The nine authored ids (data/cards/), listed as LITERALS on purpose: re-deriving them by
## scanning the same directory the loader scans would make the test agree with the loader
## about a set both got wrong.
const EXPECTED_IDS: Array[StringName] = [
	&"ember_lash", &"imp_summoner", &"hellforge_totem",
	&"frost_dart", &"storm_kite", &"tidal_wardstone",
	&"bramble_snare", &"thornback_guardian", &"verdant_wardstone",
]

func _physics_process(_delta: float) -> bool:
	# One frame in: autoloads are in the tree and every _ready() has run.
	var db := root.get_node_or_null("/root/CardDatabase")
	var autoload_present := db != null
	var count := -1
	var missing: Array[String] = []
	var wrong_type: Array[String] = []
	if autoload_present:
		count = db.card_count()
		for id in EXPECTED_IDS:
			if not db.has_card(id):
				missing.append(String(id))
				continue
			var card: Resource = db.get_card(id)
			if not (card is CardData) or card.id != id:
				wrong_type.append(String(id))

	var count_ok := count == EXPECTED_IDS.size()
	var ok := autoload_present and count_ok and missing.is_empty() and wrong_type.is_empty()
	print("card_database: autoload=%s count=%d (expected %d) missing=[%s] wrong=[%s]" % [
		autoload_present, count, EXPECTED_IDS.size(), ", ".join(missing), ", ".join(wrong_type)])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true
