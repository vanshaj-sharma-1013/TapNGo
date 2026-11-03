extends RefCounted

# The playable characters. To add one: drop its .glb in assets/characters/<name>/ and add an
# entry below. Index 0 is the default. The choice is global (GameData.selected_character).
#   model:   the .glb (needs an AnimationPlayer with clips containing "run" and "die"/"dead")
#   z_up:    true if the model is Z-up (stood up by turning it -90 degrees around X); false for Y-up
#   height:  model height in its own units, feet at the origin (used to frame the camera)
# Clips are found by name, case-insensitively: "run", "dead"/"death"/"die", and (optional) "idle".

const CHARACTERS := [
	{
		"id": "adventure-boy", "name": "Adventure Boy",
		"model": "res://assets/player/TAP_N_GO_Adventure_Boy_Animated.glb",
		"z_up": true, "height": 2.2, "accent": Color("ff8a1f"),
	},
	{
		"id": "aethel", "name": "Aethel",
		"model": "res://assets/characters/Aethel/TAP_N_GO_Style_Runner_Animated.glb",
		"z_up": false, "height": 2.84, "accent": Color("00e5ff"),
	},
]


static func count() -> int:
	return CHARACTERS.size()


static func get_character(index: int) -> Dictionary:
	return CHARACTERS[clampi(index, 0, CHARACTERS.size() - 1)]


static func character_name(index: int) -> String:
	return get_character(index)["name"]
