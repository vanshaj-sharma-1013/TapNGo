extends RefCounted

# The cyberpunk agent glb is one rigid, textured mesh standing in a relaxed pose: no skeleton and no
# animation clips. This cuts that mesh into body, two arms and two legs at load time (by where each
# triangle sits), keeps the glb's own baked material, and swings the pieces around their joints so
# the agent can run, idle, get hurt and fall over. 
# All numbers are in the glb's own units (about 0.87 tall): Y up, X sideways, +Z the front.

const DEATH_TIME := 1.1

const CX := 0.012          # the body's centre line
const MID_Z := 0.0
const HIP_Y := -0.09       # below this the body splits into two legs
const SHOULDER_Y := 0.15   # arms hang from here down to the hands
const ARM_BOTTOM_Y := -0.1
const ARM_GAP := 0.103     # arms are further out than this from the centre line

# The cut pieces are shared by every instance (cutting 200k triangles takes a moment).
static var _cache := {}

var _fall: Node3D     # pivot at the feet: leaning and falling over
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _feet_y := -0.436   # the lowest point of this model's mesh
var _phase := 0.0
var _time := 0.0
var _death := 0.0


# Replaces `source`'s mesh with the animated pieces (added as its children). Returns false if the
# mesh isn't in the expected form.
func build(source: MeshInstance3D) -> bool:
	if source.mesh == null or source.mesh.get_surface_count() == 0:
		return false
	_feet_y = source.mesh.get_aabb().position.y
	var key := source.mesh.resource_path if source.mesh.resource_path != "" else "-"
	if not _cache.has(key):
		var pieces := _cut(source.mesh)
		if pieces.is_empty():
			return false
		_cache[key] = pieces
	var meshes: Dictionary = _cache[key]

	var pivots := {
		"body": Vector3(CX, 0.0, MID_Z),
		"arm_l": Vector3(CX - ARM_GAP - 0.03, SHOULDER_Y, MID_Z),
		"arm_r": Vector3(CX + ARM_GAP + 0.03, SHOULDER_Y, MID_Z),
		"leg_l": Vector3(CX - 0.075, HIP_Y, MID_Z),
		"leg_r": Vector3(CX + 0.075, HIP_Y, MID_Z),
	}
	_fall = Node3D.new()
	_fall.position = Vector3(CX, _feet_y, MID_Z)
	source.add_child(_fall)
	var inner := Node3D.new()
	inner.position = -_fall.position
	_fall.add_child(inner)

	var nodes := {}
	for part in meshes:
		var pivot := Node3D.new()
		pivot.position = pivots[part]
		inner.add_child(pivot)
		var piece := MeshInstance3D.new()
		piece.position = -pivots[part]
		piece.mesh = meshes[part]
		pivot.add_child(piece)
		nodes[part] = pivot
	_arm_l = nodes.get("arm_l")
	_arm_r = nodes.get("arm_r")
	_leg_l = nodes.get("leg_l")
	_leg_r = nodes.get("leg_r")
	source.mesh = null
	return true


# Splits the mesh into one ArrayMesh per part (vertices renumbered so each part holds only its own).
func _cut(mesh: Mesh) -> Dictionary:
	var material := mesh.surface_get_material(0)
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if verts.is_empty() or indices.is_empty():
		return {}

	var buckets := {
		"body": PackedInt32Array(), "arm_l": PackedInt32Array(), "arm_r": PackedInt32Array(),
		"leg_l": PackedInt32Array(), "leg_r": PackedInt32Array(),
	}
	for t in range(0, indices.size() - 2, 3):
		var a := indices[t]
		var b := indices[t + 1]
		var c := indices[t + 2]
		var p := (verts[a] + verts[b] + verts[c]) / 3.0
		var dx := p.x - CX
		var part := "body"
		if p.y < HIP_Y:
			part = "leg_l" if dx < 0.0 else "leg_r"
		elif p.y < SHOULDER_Y and p.y > ARM_BOTTOM_Y and absf(dx) > ARM_GAP:
			part = "arm_l" if dx < 0.0 else "arm_r"
		var list: PackedInt32Array = buckets[part]
		list.append(a)
		list.append(b)
		list.append(c)
		buckets[part] = list

	var result := {}
	for part in buckets:
		var old_indices: PackedInt32Array = buckets[part]
		if old_indices.is_empty():
			continue
		var remap := PackedInt32Array()
		remap.resize(verts.size())
		remap.fill(-1)
		var new_verts := PackedVector3Array()
		var new_normals := PackedVector3Array()
		var new_uvs := PackedVector2Array()
		var new_indices := PackedInt32Array()
		new_indices.resize(old_indices.size())
		for i in old_indices.size():
			var old := old_indices[i]
			var mapped := remap[old]
			if mapped < 0:
				mapped = new_verts.size()
				remap[old] = mapped
				new_verts.append(verts[old])
				if not normals.is_empty():
					new_normals.append(normals[old])
				if not uvs.is_empty():
					new_uvs.append(uvs[old])
			new_indices[i] = mapped
		var piece := []
		piece.resize(Mesh.ARRAY_MAX)
		piece[Mesh.ARRAY_VERTEX] = new_verts
		if not new_normals.is_empty():
			piece[Mesh.ARRAY_NORMAL] = new_normals
		if not new_uvs.is_empty():
			piece[Mesh.ARRAY_TEX_UV] = new_uvs
		piece[Mesh.ARRAY_INDEX] = new_indices
		var array_mesh := ArrayMesh.new()
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, piece)
		if material != null:
			array_mesh.surface_set_material(0, material)
		result[part] = array_mesh
	return result


func death_duration() -> float:
	return DEATH_TIME


# Moves the pieces. `speed` is how fast the run cycle plays (0 = standing still).
func update(delta: float, animation: StringName, speed: float) -> void:
	if _fall == null:
		return
	_time += delta
	var dying := animation == &"death"
	_death = _death + delta if dying else 0.0
	_phase += delta * 10.0 * speed
	var amp := clampf(speed, 0.0, 1.3)
	var swing := sin(_phase) * amp
	var breathe := sin(_time * 2.4) * 0.03

	var lean := 0.14 * amp
	var bob := absf(sin(_phase)) * 0.018 * amp
	var spread := 0.04 + breathe
	var arm_swing_l := swing * 0.9
	var arm_swing_r := -swing * 0.9
	var leg_swing_l := -swing * 0.85
	var leg_swing_r := swing * 0.85

	# Standing still: breathe, shift weight from foot to foot and let the arms drift, so the
	# character looks alive instead of frozen. Fades out as soon as it starts to run.
	var calm := clampf(1.0 - speed * 2.0, 0.0, 1.0)
	var breath := sin(_time * 1.9)
	var sway_roll := sin(_time * 0.7) * 0.025 * calm
	var sway_yaw := sin(_time * 0.45) * 0.07 * calm
	var chest := Vector3(1.0 + breath * 0.012 * calm, 1.0 + breath * 0.02 * calm, 1.0 + breath * 0.012 * calm)
	if not dying and calm > 0.0:
		spread += (breath * 0.5 + 0.5) * 0.05 * calm
		arm_swing_l += sin(_time * 1.9 + 0.6) * 0.06 * calm + sin(_time * 0.7) * 0.04 * calm
		arm_swing_r += sin(_time * 1.9 + 1.2) * 0.06 * calm - sin(_time * 0.7) * 0.04 * calm
		leg_swing_l += sin(_time * 0.7) * 0.035 * calm
		leg_swing_r -= sin(_time * 0.7) * 0.035 * calm

	if dying:
		var p := clampf(_death / DEATH_TIME, 0.0, 1.0)
		var e := p * p * (3.0 - 2.0 * p)
		lean = -e * (PI / 2.0 - 0.1)       # topples over backwards onto its back
		bob = sin(p * PI) * 0.05           # a little hop as it goes
		spread = lerpf(0.04, 0.7, e)       # arms fling outwards
		arm_swing_l = sin(_death * 12.0) * 0.6 * (1.0 - e) - e * 0.5
		arm_swing_r = sin(_death * 12.0 + 1.5) * 0.6 * (1.0 - e) - e * 0.5
		leg_swing_l = -0.3 * e
		leg_swing_r = 0.2 * e

	_fall.position.y = _feet_y + bob
	if dying:
		sway_roll = 0.0
		sway_yaw = 0.0
		chest = Vector3.ONE
	_fall.basis = Basis(Vector3.UP, sway_yaw) * Basis(Vector3.RIGHT, lean) * Basis(Vector3.BACK, sway_roll) * Basis.from_scale(chest)
	if _arm_l != null:
		_arm_l.basis = Basis(Vector3.RIGHT, arm_swing_l) * Basis(Vector3.BACK, -spread)
	if _arm_r != null:
		_arm_r.basis = Basis(Vector3.RIGHT, arm_swing_r) * Basis(Vector3.BACK, spread)
	if _leg_l != null:
		_leg_l.basis = Basis(Vector3.RIGHT, leg_swing_l)
	if _leg_r != null:
		_leg_r.basis = Basis(Vector3.RIGHT, leg_swing_r)
