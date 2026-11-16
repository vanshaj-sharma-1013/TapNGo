extends RefCounted

# The trail skins behind the player. To add one, add an entry:
#   id:     saved in GameData, never change it afterwards
#   price:  coins to buy it. 0 = free from the start. -1 = cannot be bought, only given as a
#           reward (the Day-3 daily reward is "rainbow")
#   colors: tail-to-head colours of the line; one colour = a plain fade
#   rare:   shown with a RARE tag in the shop

const DEFAULT_ID := "neon"

const TRAILS := [
	{"id": "neon", "name": "Neon", "price": 0, "colors": [Color("00e5ff")]},
	{"id": "pink", "name": "Hot Pink", "price": 200, "colors": [Color("ff2e93")]},
	{"id": "lime", "name": "Electric Lime", "price": 200, "colors": [Color("b6ff2e")]},
	{"id": "gold", "name": "Gold Rush", "price": 400, "colors": [Color("ff8a1f"), Color("ffd23f")]},
	{"id": "rainbow", "name": "Rainbow", "price": -1, "rare": true,
		"colors": [Color("ff2e93"), Color("ffd23f"), Color("39d65c"), Color("00e5ff"), Color("8a3ffc")]},
]


static func get_trail(id: String) -> Dictionary:
	for trail in TRAILS:
		if trail["id"] == id:
			return trail
	return TRAILS[0]


# Colour ramp for a Line2D: transparent at the oldest point, brightest at the player.
static func make_gradient(id: String) -> Gradient:
	var colors: Array = get_trail(id)["colors"]
	var ramp_colors := PackedColorArray([Color(colors[0], 0.0)])
	var offsets := PackedFloat32Array([0.0])
	for i in colors.size():
		var t := float(i + 1) / colors.size()
		ramp_colors.append(Color(colors[i], lerpf(0.35, 0.95, t)))
		offsets.append(t)
	var gradient := Gradient.new()
	gradient.colors = ramp_colors
	gradient.offsets = offsets
	return gradient
