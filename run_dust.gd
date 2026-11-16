extends Node2D

# Dust kicked up by the runner's feet. Two particle layers, everything randomised by code (no art):
#   - clouds: soft, noisy puffs that drift, tumble, swell and fade
#   - grit: a few tiny fast specks that fly out and settle
# Particles stay in the world (not the player), so they are left hanging behind as the runner moves on.
# Set `emitting` to start/stop, like a particle node.

const CLOUD_TEXTURE_SIZE := 64

# Warm dusty browns and greys; each puff picks a random colour from this.
const DUST_COLORS := [
	Color(0.78, 0.70, 0.58),
	Color(0.70, 0.63, 0.53),
	Color(0.86, 0.80, 0.70),
	Color(0.62, 0.58, 0.52),
]

static var _cloud_texture: ImageTexture

var emitting := false:
	set(value):
		emitting = value
		for emitter in _emitters:
			emitter.emitting = value

var _emitters: Array[CPUParticles2D] = []


func _init() -> void:
	z_index = -1
	_emitters.append(_make_clouds())
	_emitters.append(_make_grit())
	for emitter in _emitters:
		add_child(emitter)


func _make_clouds() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.local_coords = false
	p.emitting = false
	p.texture = _get_cloud_texture()
	p.amount = 18
	p.lifetime = 0.9
	p.lifetime_randomness = 0.5
	p.randomness = 1.0
	# Spawn spread over the width of the feet instead of from one point.
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 9.0
	p.direction = Vector2(0.0, 1.0)
	p.spread = 60.0
	p.gravity = Vector2(0.0, -14.0)           # warm dust drifts slowly up the screen
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 42.0
	p.damping_min = 25.0
	p.damping_max = 55.0
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -50.0
	p.angular_velocity_max = 50.0
	p.scale_amount_min = 0.14
	p.scale_amount_max = 0.34
	p.scale_amount_curve = _curve([Vector2(0.0, 0.5), Vector2(0.35, 1.0), Vector2(1.0, 2.3)])
	p.color_initial_ramp = _random_color_ramp()
	p.color_ramp = _alpha_ramp(0.42)
	return p


func _make_grit() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.local_coords = false
	p.emitting = false
	p.amount = 12
	p.lifetime = 0.5
	p.lifetime_randomness = 0.6
	p.randomness = 1.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 8.0
	p.direction = Vector2(0.0, 1.0)
	p.spread = 80.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 130.0
	p.damping_min = 90.0
	p.damping_max = 170.0
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.6
	p.color_initial_ramp = _random_color_ramp()
	p.color_ramp = _alpha_ramp(0.75)
	return p


# A soft round puff with a noisy, uneven edge. Built once and shared.
static func _get_cloud_texture() -> ImageTexture:
	if _cloud_texture != null:
		return _cloud_texture
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.09
	noise.seed = randi()
	var size := CLOUD_TEXTURE_SIZE
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := size / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - half, y + 0.5 - half).length() / half
			var n := noise.get_noise_2d(x, y) * 0.5 + 0.5          # 0..1
			var edge := clampf(1.0 - d - (1.0 - n) * 0.35, 0.0, 1.0)
			var alpha := smoothstep(0.0, 0.6, edge)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_cloud_texture = ImageTexture.create_from_image(image)
	return _cloud_texture


static func _random_color_ramp() -> Gradient:
	var ramp := Gradient.new()
	var count := DUST_COLORS.size()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in count:
		offsets.append(float(i) / float(count - 1))
		colors.append(DUST_COLORS[i])
	ramp.offsets = offsets
	ramp.colors = colors
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	return ramp


# Fades in quickly, then thins out to nothing.
static func _alpha_ramp(peak: float) -> Gradient:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.12, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, peak), Color(1, 1, 1, 0.0)])
	return ramp


static func _curve(points: Array) -> Curve:
	var curve := Curve.new()
	curve.max_value = 3.0
	for point in points:
		curve.add_point(point)
	return curve
