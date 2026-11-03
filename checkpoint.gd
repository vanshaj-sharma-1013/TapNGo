extends Area2D

# Emitted the first time the player crosses this line.
signal reached(checkpoint: Node2D)

const WorldData = preload("res://world_data.gd")
const WorldArt = preload("res://world_art.gd")

const HEIGHT := 64.0

# Which world's art to use; set before the checkpoint is added to the scene.
var world := WorldData.JUNGLE
var activated := false

var _off_texture: Texture2D
var _on_texture: Texture2D


func _ready() -> void:
	_off_texture = WorldArt.texture(world, "level_objects/checkpoint_off")
	_on_texture = WorldArt.texture(world, "level_objects/checkpoint_on")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body_entered.connect(_on_body_entered)


func _draw() -> void:
	# Lane-wide marker centred on the line; the node sits at x = 0.
	draw_texture_rect(_on_texture if activated else _off_texture, Rect2(0.0, -HEIGHT / 2.0, 720.0, HEIGHT), false)


func _on_body_entered(body: Node2D) -> void:
	if not activated and body.is_in_group("player"):
		activated = true
		queue_redraw()
		# Bright flash across the lane that settles back to normal.
		modulate = Color(2.5, 2.5, 2.5, 1.0)
		create_tween().tween_property(self, "modulate", Color.WHITE, 0.6)
		reached.emit(self)
