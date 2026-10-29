extends Node

# Autoload "Sfx": Sfx.play("start") plays res://sfx/start.wav.
# Missing files are skipped, so the game still runs without audio.

const SOUNDS := ["start", "stop", "crash", "checkpoint", "finish", "revive"]

var players := {}


func _ready() -> void:
	for sound_name in SOUNDS:
		var path := "res://sfx/%s.wav" % sound_name
		if not ResourceLoader.exists(path):
			continue
		var player := AudioStreamPlayer.new()
		player.stream = load(path)
		add_child(player)
		players[sound_name] = player


func play(sound_name: String) -> void:
	if players.has(sound_name):
		players[sound_name].play()
