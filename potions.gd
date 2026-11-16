extends RefCounted

# The potions sold in the shop and used mid-run. To add one: add an entry below, give it an
# effect in level.gd (_use_potion) and, if it acts on the player, in player.gd.
#   id:    saved in GameData, never change it afterwards
#   name / desc: shown in the shop
#   price: coins for one potion
#   color: the flask liquid, the HUD button frame and the effect flash
#   hud:   true = has a button in the run HUD. The revive potion has none: it is offered on the
#          crash screen instead.

const REVIVE := "revive"
const SPEED_UP := "speed_up"
const SPEED_DOWN := "speed_down"
const COOLDOWN := "cooldown"
const BURNING := "burning"

# Speed potions: the run speed is multiplied by `scale` for `time` seconds.
const SPEED_UP_SCALE := 1.5
const SPEED_UP_TIME := 8.0
const SPEED_DOWN_SCALE := 0.6
const SPEED_DOWN_TIME := 10.0
# After a cooldown / burning potion the player ignores fire / ice for this long, so they can
# walk out of the patch they are standing in.
const IMMUNE_TIME := 3.0

const POTIONS := [
	{"id": REVIVE, "name": "Revive Potion", "price": 300, "color": Color("ff4d6d"), "hud": false,
		"desc": "Come back to life at your last checkpoint. Offered on the crash screen."},
	{"id": SPEED_UP, "name": "Faster Speed Potion", "price": 80, "color": Color("ffd23f"), "hud": true,
		"desc": "Run 50% faster for 8 seconds."},
	{"id": SPEED_DOWN, "name": "Lower Speed Potion", "price": 60, "color": Color("b48cff"), "hud": true,
		"desc": "Run 40% slower for 10 seconds, for tricky gaps."},
	{"id": COOLDOWN, "name": "Cooldown Potion", "price": 100, "color": Color("4fc3ff"), "hud": true,
		"desc": "Rescue after walking into lava: puts the fire out and protects you from it for 3 seconds."},
	{"id": BURNING, "name": "Burning Potion", "price": 100, "color": Color("ff8a1f"), "hud": true,
		"desc": "Frozen by ice? Melts it at once so you keep running, and protects you from ice for 3 seconds."},
]


static func get_potion(id: String) -> Dictionary:
	for potion in POTIONS:
		if potion["id"] == id:
			return potion
	return {}


static func ids() -> Array:
	var list: Array = []
	for potion in POTIONS:
		list.append(potion["id"])
	return list


# The potions that get a button during a run, in order.
static func hud_ids() -> Array:
	var list: Array = []
	for potion in POTIONS:
		if potion["hud"]:
			list.append(potion["id"])
	return list


# A drawn flask: glass body filled with the potion's colour, a cork, and a small symbol.
class PotionIcon extends Control:
	var id := ""
	var color := Color.WHITE

	func _init(potion_id: String, size_px := 64.0) -> void:
		id = potion_id
		var info: Dictionary = load("res://potions.gd").get_potion(potion_id)
		color = info.get("color", Color.WHITE)
		custom_minimum_size = Vector2(size_px, size_px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _p(x: float, y: float) -> Vector2:
		var s := minf(size.x, size.y)
		return (size - Vector2(s, s)) / 2.0 + Vector2(x, y) * s

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var glass := Color(0.85, 0.95, 1.0, 0.9)
		var centre := _p(0.5, 0.64)
		# Neck, then the round body.
		draw_rect(Rect2(_p(0.4, 0.14), Vector2(0.2, 0.26) * s), Color(glass, 0.35))
		draw_circle(centre, s * 0.33, Color(glass, 0.35))
		# Liquid: the lower part of the body.
		var liquid := PackedVector2Array()
		for i in 21:
			var a := PI * 0.12 + (PI * 0.76) * i / 20.0
			liquid.append(centre + Vector2(cos(a), sin(a)) * s * 0.3)
		draw_colored_polygon(liquid, color)
		draw_arc(centre, s * 0.33, 0.0, TAU, 32, glass, s * 0.045, true)
		draw_rect(Rect2(_p(0.4, 0.14), Vector2(0.2, 0.26) * s), glass, false, s * 0.04)
		# Cork.
		draw_rect(Rect2(_p(0.36, 0.05), Vector2(0.28, 0.11) * s), Color("b07a45"))
		# Shine.
		draw_arc(centre, s * 0.25, PI * 1.05, PI * 1.35, 8, Color(1, 1, 1, 0.8), s * 0.04, true)
		_draw_symbol(centre, s)

	func _draw_symbol(c: Vector2, s: float) -> void:
		var w := s * 0.05
		var white := Color(1, 1, 1, 0.95)
		var u := s * 0.1
		match id:
			"revive":
				draw_line(c + Vector2(-u, u * 0.5), c + Vector2(u, u * 0.5), white, w * 1.4)
				draw_line(c + Vector2(0, -u * 0.5), c + Vector2(0, u * 1.5), white, w * 1.4)
			"speed_up":
				draw_polyline(PackedVector2Array([c + Vector2(-u, u * 0.9), c + Vector2(0, -u * 0.3), c + Vector2(u, u * 0.9)]), white, w * 1.3, true)
			"speed_down":
				draw_polyline(PackedVector2Array([c + Vector2(-u, 0), c + Vector2(0, u * 1.2), c + Vector2(u, 0)]), white, w * 1.3, true)
			"cooldown":
				for i in 3:
					var a := PI * i / 3.0
					var d := Vector2(cos(a), sin(a)) * u * 1.1
					draw_line(c + Vector2(0, u * 0.5) - d, c + Vector2(0, u * 0.5) + d, white, w)
			"burning":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -u * 0.7), c + Vector2(u * 0.9, u * 0.7),
						c + Vector2(0, u * 1.3), c + Vector2(-u * 0.9, u * 0.7)]), white)
