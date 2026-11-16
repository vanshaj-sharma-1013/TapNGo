extends RefCounted

# The playable characters. To add one: drop its .glb in assets/characters/<name>/ and add an
# entry below. Index 0 is the default. The choice is global (GameData.selected_character).
#   model:   the .glb (needs an AnimationPlayer with clips containing "run" and "die"/"dead")
#   z_up:    true if the model is Z-up (stood up by turning it -90 degrees around X); false for Y-up
#   height:  model height in its own units, feet at the origin (used to frame the camera)
#   price:   coins to unlock. 0 = free from the start. -1 = cannot be bought; it is only given as
#            the Day-7 daily reward (daily_rewards.gd). Omitted = 0.
#   auto_fit: optional. Hides any "Plane" ground mesh, scales the model to `height` and stands it on
#            the origin. For models exported at an arbitrary scale/offset.
# Clips are found by name, case-insensitively: "run", "dead"/"death"/"die", and (optional) "idle".

const CHARACTERS := [
	{
		"id": "cyberpunk-agent", "name": "Cyber Agent", "auto_fit": true, "rig": "agent",
		"model": "res://assets/characters/cyberpunk-agent/Cyberpunk Agent with Cyan Shades_3d_baked.glb",
		"z_up": false, "height": 2.3, "accent": Color("19e0e8"), "price": 0, "gameplay_yaw": 0.0,
	},
	{
		"id": "ice-queen", "name": "Ice Queen", "auto_fit": true, "rig": "agent",
		"model": "res://assets/characters/ice-queen/Ice Queen Cyber Warrior_3d_baked.glb",
		"z_up": false, "height": 2.3, "accent": Color("8fdcff"), "price": 0, "gameplay_yaw": 0.0,
	},
	{
		"id": "tropical-leaf", "name": "Leaf Warrior", "auto_fit": true, "rig": "agent",
		"model": "res://assets/characters/tropical-leaf/Tropical Leaf Warrior in Studio Light_3d_baked.glb",
		"z_up": false, "height": 2.3, "accent": Color("5fd35f"), "price": 0, "gameplay_yaw": 0.0,
	},
]


static func count() -> int:
	return CHARACTERS.size()


static func get_character(index: int) -> Dictionary:
	return CHARACTERS[clampi(index, 0, CHARACTERS.size() - 1)]


static func price(index: int) -> int:
	return int(get_character(index).get("price", 0))


static func character_name(index: int) -> String:
	return get_character(index)["name"]
