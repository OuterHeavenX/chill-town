extends RefCounted
## Small things that move: chimney smoke, firelight, lantern glow and the dust of
## a finished building. Everything here runs on the Compatibility renderer the
## web build uses, so it is CPU particles, omni lights and additive billboards —
## no post-processing.

static var _halo_texture: GradientTexture2D
static var _puff_texture: GradientTexture2D


## Grey puffs drifting up from a chimney top. Starts idle; the world turns it on
## while someone is working inside.
static func smoke(parent: Node3D, at: Vector3) -> CPUParticles3D:
	var puffs := CPUParticles3D.new()
	puffs.name = "Smoke"
	puffs.position = at
	puffs.emitting = false
	puffs.amount = 14
	puffs.lifetime = 3.4
	puffs.preprocess = 1.5
	puffs.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	puffs.emission_sphere_radius = 0.10
	puffs.direction = Vector3.UP
	puffs.spread = 9.0
	puffs.gravity = Vector3(0.22, 0.42, 0.10)
	puffs.initial_velocity_min = 0.55
	puffs.initial_velocity_max = 0.85
	puffs.angular_velocity_min = -20.0
	puffs.angular_velocity_max = 20.0
	puffs.scale_amount_min = 0.35
	puffs.scale_amount_max = 0.5
	var growth := Curve.new()
	growth.add_point(Vector2(0.0, 0.5))
	growth.add_point(Vector2(1.0, 2.6))
	puffs.scale_amount_curve = growth
	var fade := Gradient.new()
	fade.set_color(0, Color(0.62, 0.62, 0.64, 0.55))
	fade.set_color(1, Color(0.70, 0.70, 0.74, 0.0))
	puffs.color_ramp = fade
	puffs.mesh = _billboard_quad(0.55, _puff(), Color.WHITE, false)
	parent.add_child(puffs)
	return puffs


## A warm light with a soft halo where a fire burns. The world flickers it.
static func fire(parent: Node3D, at: Vector3) -> OmniLight3D:
	var light := _point(parent, at, Color("ffa050"), 5.6, 1.4)
	light.name = "Fire"
	_halo(light, Vector3.ZERO, Color("ff9a48", 0.55), 1.7)
	return light


## A lantern by a door: lit at night, out by day.
static func lantern(parent: Node3D, at: Vector3) -> OmniLight3D:
	var light := _point(parent, at, Color("ffc27a"), 8.5, 0.0)
	light.name = "Lantern"
	_halo(light, Vector3.ZERO, Color("ffbe70", 0.5), 1.15)
	return light


## A one-shot burst of dust where a building has just been finished.
static func dust(parent: Node3D, at: Vector3) -> CPUParticles3D:
	var burst := CPUParticles3D.new()
	burst.name = "Dust"
	burst.position = at + Vector3(0, 0.3, 0)
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 26
	burst.lifetime = 1.3
	burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 1.6
	burst.direction = Vector3.UP
	burst.spread = 70.0
	burst.gravity = Vector3(0, -0.9, 0)
	burst.initial_velocity_min = 1.2
	burst.initial_velocity_max = 2.6
	burst.scale_amount_min = 0.5
	burst.scale_amount_max = 0.9
	var growth := Curve.new()
	growth.add_point(Vector2(0.0, 0.6))
	growth.add_point(Vector2(1.0, 1.9))
	burst.scale_amount_curve = growth
	var fade := Gradient.new()
	fade.set_color(0, Color(0.62, 0.55, 0.42, 0.7))
	fade.set_color(1, Color(0.62, 0.55, 0.42, 0.0))
	burst.color_ramp = fade
	burst.mesh = _billboard_quad(0.8, _puff(), Color.WHITE, false)
	parent.add_child(burst)
	burst.emitting = true
	var tree := parent.get_tree()
	if tree != null:
		tree.create_timer(2.2).timeout.connect(burst.queue_free)
	return burst


static func _point(parent: Node3D, at: Vector3, colour: Color, reach: float, energy: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = colour
	light.omni_range = reach
	light.omni_attenuation = 1.6
	light.light_energy = energy
	light.shadow_enabled = false
	parent.add_child(light)
	return light


static func _halo(parent: Node3D, at: Vector3, colour: Color, size: float) -> MeshInstance3D:
	var glow := MeshInstance3D.new()
	glow.name = "Halo"
	glow.position = at
	glow.mesh = _billboard_quad(size, _halo_gradient(), colour, true)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(glow)
	return glow


## A camera-facing quad. Additive for glows, plain alpha for smoke.
static func _billboard_quad(size: float, texture: Texture2D, colour: Color, additive: bool) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES if not additive else BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = texture
	material.albedo_color = colour
	material.no_depth_test = false
	material.disable_receive_shadows = true
	quad.material = material
	return quad


static func _halo_gradient() -> GradientTexture2D:
	if _halo_texture == null:
		_halo_texture = _radial(Color(1, 1, 1, 1), Color(1, 1, 1, 0), 0.0)
	return _halo_texture


static func _puff() -> GradientTexture2D:
	if _puff_texture == null:
		_puff_texture = _radial(Color(1, 1, 1, 1), Color(1, 1, 1, 0), 0.35)
	return _puff_texture


static func _radial(centre: Color, edge: Color, hold: float) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, centre)
	gradient.set_color(1, edge)
	if hold > 0.0:
		gradient.add_point(hold, centre)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture
