extends Area2D

# Emitted when the player crosses the finish line.
signal reached

const WorldData = preload("res://world_data.gd")
const WorldArt = preload("res://world_art.gd")

const GATE_HEIGHT := 120.0

# Which world's art to use; set before the gate is added to the scene.
var world := WorldData.JUNGLE

var _gate: Texture2D


func _ready() -> void:
	_gate = WorldArt.texture(world, "level_objects/finish_gate")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body_entered.connect(_on_body_entered)


func _draw() -> void:
	# Lane-wide gate standing on the finish line; the node sits at x = 0.
	draw_texture_rect(_gate,Rect2(0.0, -GATE_HEIGHT, 720.0, GATE_HEIGHT), false)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		reached.emit()
