extends Node2D

# A character from character_roster.gd (a .glb with Run and Dead clips) rendered into a transparent
# SubViewport and drawn as a 2D sprite, so the rest of the game stays 2D. Run and Dead come
# from the file; the other game animations replay Run at other speeds, plus a little leaning.
# Mirrors the bits of AnimatedSprite2D that player.gd uses: play(), animation, death_duration().

const CharacterRoster := preload("res://character_roster.gd")
const AgentRig := preload("res://agent_rig.gd")

# The camera's view is this much taller than the model, so a little room is left around it.
const VIEW_MARGIN := 1.18
const DEATH_TIME := 1.5   # fallback if the Dead clip isn't found
# Turned this far (radians) from straight behind, so the swinging limbs can be seen. A roster
# entry can override it with "gameplay_yaw" (0 = straight behind).
const GAMEPLAY_YAW := 0.3

# Playback speed of the Run clip for each game animation (0 holds the first frame).
const RUN_SPEEDS := {
	&"idle": 0.0,
	&"walk": 0.6,
	&"run": 1.0,
	&"walk_left": 0.8,
	&"walk_right": 0.8,
	&"hurt": 1.6,
}

# Side of the square render target in pixels. Set before adding to the tree.
var view_size := 256
# True shows the face (menu); false shows the runner from behind, as it heads up the screen.
var face_camera := false
# Menu preview: dragging spins the model all the way round, and it turns slowly on its own.
var free_rotate := false
# How many times wider than the model's own frame the render covers. A big value lets the model be
# zoomed or tilted without the edge of the picture cutting it off. 1 = just the model.
var view_extent := 1.0

# Roster index to show. -1 (the default) is the player's selected character. Set before adding to the tree.
var character := -1
# True renders a single still picture instead of updating every frame (for small thumbnails).
var still := false

var animation := &"idle"

var _time := 0.0
var _anim: AnimationPlayer
var _rig   # an AgentRig, for models with no animation clips: pieces swung by code
var _run_clip: StringName
var _idle_clip: StringName
var _dead_clip: StringName
var _lean: Node3D   # sideways lean and turn
var _pitch: Node3D  # tilts the model forward/back about its middle (menu drag)
var _camera: Camera3D
var _base_size := 1.0
var _zoom := 1.0
var _pan := 0.0     # camera height offset in world units
var _pan_x := 0.0
var _yaw: Node3D    # which side of the model the camera sees (fixed, or free in the menu)
var _spin_idle := 0.0   # seconds since the last drag, for the auto-spin


func _ready() -> void:
	var info := CharacterRoster.get_character(GameData.selected_character if character < 0 else character)
	var model_height: float = info["height"]
	var viewport := SubViewport.new()
	viewport.size = Vector2i(view_size, view_size)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if still else SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	_lean = Node3D.new()
	viewport.add_child(_lean)
	_pitch = Node3D.new()
	_pitch.position.y = model_height / 2.0
	_lean.add_child(_pitch)
	_yaw = Node3D.new()
	_yaw.position.y = -model_height / 2.0
	_yaw.rotation.y = 0.0 if face_camera else PI + float(info.get("gameplay_yaw", GAMEPLAY_YAW))
	_pitch.add_child(_yaw)

	var model := (load(info["model"]) as PackedScene).instantiate() as Node3D
	# Feet are at the origin. A Z-up model is stood upright; a Y-up one already is.
	if info["z_up"]:
		model.rotation.x = -PI / 2.0
	_yaw.add_child(model)
	var rig_kind: String = info.get("rig", "")
	if rig_kind != "":
		_setup_rig(model, rig_kind)
	if info.get("auto_fit", false):
		_auto_fit(model, model_height)
	_apply_vertex_colors(model)
	if _rig == null:
		_setup_animations(model)
	_apply_animation()

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = model_height * VIEW_MARGIN * view_extent
	_camera = camera
	_base_size = camera.size
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.85, 1.0)
	env.ambient_light_energy = 0.7
	camera.environment = env
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, model_height / 2.0 + 3.5, 10.0), Vector3(0.0, model_height / 2.0, 0.0))

	var light := DirectionalLight3D.new()
	light.light_energy = 1.1
	viewport.add_child(light)
	light.look_at_from_position(Vector3(2.0, 6.0, 8.0), Vector3(0.0, model_height / 2.0, 0.0))

	var image := Sprite2D.new()
	image.texture = viewport.get_texture()
	add_child(image)


func play(animation_name: StringName) -> void:
	if animation_name == animation:
		return
	animation = animation_name
	_apply_animation()


# Spins the model by `radians` around the vertical axis (menu drag).
func rotate_by(radians: float) -> void:
	_yaw.rotation.y += radians
	_spin_idle = 0.0


# Tilts the model forward/back about its middle (menu drag), so top and underside can be seen.
func pitch_by(radians: float) -> void:
	_pitch.rotation.x = wrapf(_pitch.rotation.x + radians, -PI, PI)
	_spin_idle = 0.0


# Zooms the menu camera by `factor` (>1 closer), 1x to 4x.
func zoom_by(factor: float) -> void:
	_zoom = clampf(_zoom * factor, 1.0, 4.0)
	_apply_camera()
	_spin_idle = 0.0


# Slides the camera by a fraction of the view (x, y), to bring the head or feet to the middle.
func pan_by(fraction: Vector2) -> void:
	var frame := _base_size / view_extent
	_pan_x -= fraction.x * frame / _zoom
	_pan += fraction.y * frame / _zoom
	_apply_camera()
	_spin_idle = 0.0


func reset_view() -> void:
	_zoom = 1.0
	_pan = 0.0
	_pan_x = 0.0
	_pitch.rotation.x = 0.0
	_apply_camera()


func _apply_camera() -> void:
	if _camera == null:
		return
	_camera.size = _base_size / _zoom
	# Keep the model in view: it may be panned only as far as it extends beyond the zoomed frame.
	var frame := _base_size / view_extent
	var limit := frame * 0.5 * (1.0 - 1.0 / _zoom) + frame * 0.1
	_pan = clampf(_pan, -limit, limit)
	_pan_x = clampf(_pan_x, -limit, limit)
	_camera.h_offset = _pan_x
	_camera.v_offset = _pan


func death_duration() -> float:
	if _rig != null:
		return _rig.death_duration()
	if _anim != null and _dead_clip != &"":
		return _anim.get_animation(_dead_clip).length
	return DEATH_TIME


# Cuts the model's mesh into animated pieces (see agent_rig.gd).
func _setup_rig(model: Node3D, kind: String) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null or String(mesh_node.name).to_lower().contains("plane"):
			continue
		var rig = AgentRig.new()
		if rig.build(mesh_node):
			_rig = rig
		return
	push_warning("character_view: no mesh to rig in the character glb")


# Hides ground planes, then scales the model to `height` and stands it centred on the origin.
func _auto_fit(model: Node3D, height: float) -> void:
	var to_model := model.get_parent_node_3d().global_transform.affine_inverse()
	var bounds := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		if String(mesh_node.name).to_lower().contains("plane"):
			mesh_node.visible = false
			continue
		var box: AABB = (to_model * mesh_node.global_transform) * mesh_node.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if first or bounds.size.y <= 0.0001:
		return
	var factor := height / bounds.size.y
	var centre := bounds.get_center()
	model.basis = model.basis.scaled(Vector3.ONE * factor)
	model.position = Vector3(-centre.x * factor, -bounds.position.y * factor, -centre.z * factor)


# Some models have no materials, only colours painted on the vertices. Godot draws those plain
# white unless the surface has a material that reads the vertex colour, so give them one.
func _apply_vertex_colors(model: Node) -> void:
	var material: StandardMaterial3D
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		for surface in mesh_node.mesh.get_surface_count():
			if mesh_node.mesh.surface_get_material(surface) != null or mesh_node.get_surface_override_material(surface) != null:
				continue
			if material == null:
				material = StandardMaterial3D.new()
				material.vertex_color_use_as_albedo = true
				material.roughness = 0.75
			mesh_node.set_surface_override_material(surface, material)


# Finds the Run and Dead clips (the glb's AnimationPlayer may prefix them with a library name).
func _setup_animations(model: Node) -> void:
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim == null:
		push_warning("character_view: no AnimationPlayer in the character glb")
		return
	for clip in _anim.get_animation_list():
		var lowered := String(clip).to_lower()
		if lowered.contains("idle"):
			_idle_clip = clip
			_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		elif lowered.contains("run"):
			_run_clip = clip
			_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		elif lowered.contains("dead") or lowered.contains("death") or lowered.contains("die"):
			_dead_clip = clip
			_anim.get_animation(clip).loop_mode = Animation.LOOP_NONE


# Starts the clip for the current game animation. Idle holds the first frame of Run.
func _apply_animation() -> void:
	if _rig != null:
		_rig.update(0.0, animation, RUN_SPEEDS.get(animation, 1.0))
		return
	if _anim == null:
		return
	if animation == &"death":
		if _dead_clip != &"":
			_anim.speed_scale = 1.0
			_anim.play(_dead_clip)
		return
	if animation == &"idle" and _idle_clip != &"":
		_anim.speed_scale = 1.0
		_anim.play(_idle_clip)
		return
	if _run_clip == &"":
		return
	var speed: float = RUN_SPEEDS.get(animation, 1.0)
	_anim.play(_run_clip)
	_anim.speed_scale = speed
	if speed == 0.0:
		_anim.seek(0.0, true)
		_anim.pause()


func _process(delta: float) -> void:
	_time += delta
	if _rig != null:
		_rig.update(delta, animation, RUN_SPEEDS.get(animation, 1.0))
	if free_rotate:
		_spin_idle += delta
		if _spin_idle > 2.0:
			_yaw.rotation.y += delta * 0.6
	var bob := 0.0
	var roll := 0.0    # negative leans to the right
	var turn := 0.0    # negative turns to face right
	var shake := 0.0
	match animation:
		&"idle":
			bob = sin(_time * 2.4) * 0.03
		&"walk_left":
			roll = 0.15
			turn = 0.5
		&"walk_right":
			roll = -0.15
			turn = -0.5
		&"hurt":
			shake = sin(_time * 50.0) * 0.06
	var k := 1.0 - exp(-14.0 * delta)
	_lean.rotation.z = lerpf(_lean.rotation.z, roll, k)
	_lean.rotation.y = lerpf(_lean.rotation.y, turn, k)
	_lean.position = Vector3(shake, bob, 0.0)
