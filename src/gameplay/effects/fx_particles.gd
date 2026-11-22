class_name FxParticles
extends MultiMeshInstance3D
## A pool of simple particles drawn in one call: puffs of smoke or dust (soft round blots that face
## the camera), sparks (thin bright sticks laid along their flight) or chunks (small tumbling
## boxes). The effects of a Shot (MuzzleFlash, Impact), the trail of a rocket and the dust behind a
## Unit's tyres are made of these.
##
## A picture only: nothing here is a body or on a collision layer. The node is top_level, so the
## particles stay where they were put in the world while the node's parent moves; they are emitted
## at world positions by burst() and emit(), or every frame at the node's own position while
## `rate` is above zero (a trail).
##
## Every look is data, exports of the scene that holds the node: the count, the life, the size from
## birth to death, the colour and alpha from birth to death, gravity, drag and the mesh's kind. The
## randomness comes from a RandomNumberGenerator seeded with `seed_value`, so one run draws the same
## particles every time. They move in _process, once per drawn frame, so they are smooth at any
## frame rate; the node's process mode is the scene's (an effect that must play under the Round-over
## pause sets ALWAYS on its root, as Explosion does).

## What a particle looks like.
enum Kind {
	## A soft round blot that always faces the camera: smoke, dust, a flash.
	PUFF,
	## A thin stick laid along the particle's flight, stretched by its speed: a spark.
	SPARK,
	## A small box that tumbles: a chunk of dirt, rock or metal.
	CHUNK,
}

@export var kind: Kind = Kind.PUFF
## Particles alive at most; an emission past it reuses the oldest.
@export_range(1, 512, 1) var max_particles: int = 32
## Seconds a particle lives, the least and the most.
@export var life_min: float = 0.6
@export var life_max: float = 1.0
## Size in metres at birth and at death (a PUFF's diameter, a SPARK's width, a CHUNK's edge), times a
## random factor between size_random_min and 1.0 drawn per particle.
@export var size_start: float = 0.3
@export var size_end: float = 0.8
@export_range(0.0, 1.0, 0.01) var size_random_min: float = 0.7
## Colour and alpha at birth and at death, sRGB; the alpha fades between them.
@export var colour_start: Color = Color(0.5, 0.5, 0.5, 0.6)
@export var colour_end: Color = Color(0.5, 0.5, 0.5, 0.0)
## Drawn unlit and added to what is behind it (a flash, a spark, a flame), or drawn lit and blended.
@export var glow: bool = false
## Drawn unlit but blended, so its colour stays the colour set whatever light falls on it (a burning thing's
## flames under the sun and their own glow).
@export var unshaded: bool = false
## Acceleration in m/s^2, world space (gravity pulls -Y; smoke rises with a small +Y).
@export var gravity: Vector3 = Vector3.ZERO
## The share of its speed a particle loses each second (0 none, 1 stops in about a second).
@export_range(0.0, 20.0, 0.01) var drag: float = 1.0
## How much longer than wide a SPARK is drawn, per m/s of its speed.
@export var spark_stretch: float = 0.02
## Turns per second a CHUNK tumbles at most.
@export var spin: float = 2.0
## Particles a second emitted at the node's own position while above zero (a trail), with
## rate_speed m/s in a random direction.
@export var rate: float = 0.0
@export var rate_speed: float = 0.3
## Where a trail is emitted from while `rate` is above zero (a point on a rocket); the node's own
## position when null. Emissions are spread along the way it moved since the last frame, so a fast
## rocket leaves an unbroken line.
@export var follow: Node3D
## Seed of the randomness, so a run draws the same particles every time.
@export var seed_value: int = 1

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _pos: PackedVector3Array = PackedVector3Array()
var _vel: PackedVector3Array = PackedVector3Array()
var _age: PackedFloat32Array = PackedFloat32Array()
var _life: PackedFloat32Array = PackedFloat32Array()
var _size: PackedFloat32Array = PackedFloat32Array()
var _axis: PackedVector3Array = PackedVector3Array()
var _next: int = 0
var _alive: int = 0
var _carry: float = 0.0
var _last_source: Vector3 = Vector3.ZERO
var _has_source: bool = false
## Frees the node once the last particle has died (finish()).
var _finishing: bool = false


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_rng.seed = seed_value
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _make_mesh()
	mm.instance_count = max_particles
	mm.visible_instance_count = 0
	multimesh = mm
	# Packed arrays are values in GDScript, so each is resized by name, never through a list.
	_pos.resize(max_particles)
	_vel.resize(max_particles)
	_axis.resize(max_particles)
	_age.resize(max_particles)
	_life.resize(max_particles)
	_size.resize(max_particles)
	for i: int in max_particles:
		_age[i] = 1.0
		_life[i] = 0.0
	# A wide box: the particles fly away from the node's position, which never moves the box.
	custom_aabb = AABB(Vector3(-1000.0, -50.0, -1000.0), Vector3(2000.0, 200.0, 2000.0))


## Emits one particle at `at` (world) with velocity `velocity` (m/s, world).
func emit(at: Vector3, velocity: Vector3) -> void:
	var i: int = _next
	_next = (_next + 1) % max_particles
	_pos[i] = at
	_vel[i] = velocity
	_age[i] = 0.0
	_life[i] = maxf(_rng.randf_range(life_min, life_max), 0.01)
	_size[i] = _rng.randf_range(size_random_min, 1.0)
	_axis[i] = Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-1.0, 1.0)).normalized()
	_alive = mini(_alive + 1, max_particles)


## Emits `count` particles at `at` (world), each flying along `direction` turned by up to `spread`
## degrees at a speed between speed_min and speed_max, from points up to `radius` metres apart.
func burst(at: Vector3, count: int, direction: Vector3, spread: float, speed_min: float,
		speed_max: float, radius: float = 0.0) -> void:
	var dir: Vector3 = direction.normalized() if direction.length_squared() > 0.0 else Vector3.UP
	for _k: int in count:
		var v: Vector3 = _spread(dir, deg_to_rad(spread)) * _rng.randf_range(speed_min, speed_max)
		var offset: Vector3 = Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0),
				_rng.randf_range(-1.0, 1.0)) * radius
		emit(at + offset, v)


## Moves every living particle by `offset` metres (world), so they ride along with something that moves (a burning
## Unit's fire).
func shift(offset: Vector3) -> void:
	for i: int in max_particles:
		if _age[i] < _life[i]:
			_pos[i] += offset


## Stops the trail and frees the node once its last particle has died, after taking it out of its
## parent into `keep_under` (so a trail outlives the rocket that drew it).
func finish(keep_under: Node = null) -> void:
	rate = 0.0
	follow = null
	_finishing = true
	if keep_under != null and get_parent() != keep_under:
		var at: Transform3D = global_transform
		get_parent().remove_child(self)
		keep_under.add_child(self)
		global_transform = at


## The random generator, so an effect draws its own numbers from the same seeded stream.
func rng() -> RandomNumberGenerator:
	return _rng


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	if rate > 0.0:
		var source: Vector3 = follow.global_position if is_instance_valid(follow) else global_position
		var from: Vector3 = _last_source if _has_source else source
		_carry += rate * delta
		var count: int = floori(_carry)
		_carry -= float(count)
		for k: int in count:
			var at: Vector3 = from.lerp(source, float(k + 1) / float(count))
			emit(at, _spread(Vector3.UP, PI) * rate_speed)
		_last_source = source
		_has_source = true
	var mm: MultiMesh = multimesh
	var shown: int = 0
	var keep: float = maxf(1.0 - drag * delta, 0.0)
	for i: int in max_particles:
		if _age[i] >= _life[i]:
			continue
		_age[i] += delta
		if _age[i] >= _life[i]:
			continue
		_vel[i] = _vel[i] * keep + gravity * delta
		_pos[i] += _vel[i] * delta
		var t: float = _age[i] / _life[i]
		var s: float = lerpf(size_start, size_end, t) * _size[i]
		mm.set_instance_transform(shown, _pose(i, s, t))
		mm.set_instance_color(shown, colour_start.lerp(colour_end, t))
		shown += 1
	mm.visible_instance_count = shown
	_alive = shown
	if _finishing and shown == 0:
		queue_free()


func _pose(i: int, s: float, t: float) -> Transform3D:
	match kind:
		Kind.SPARK:
			var v: Vector3 = _vel[i]
			var speed: float = v.length()
			if speed < 0.001:
				return Transform3D(Basis.from_scale(Vector3.ONE * s), _pos[i])
			var forward: Vector3 = v / speed
			var up: Vector3 = Vector3.UP if absf(forward.y) < 0.99 else Vector3.RIGHT
			var b: Basis = Basis.looking_at(forward, up)
			return Transform3D(b.scaled_local(Vector3(s, s, s + speed * spark_stretch)), _pos[i])
		Kind.CHUNK:
			var b: Basis = Basis(_axis[i], _age[i] * spin * TAU + float(i))
			return Transform3D(b.scaled_local(Vector3.ONE * s), _pos[i])
		_:
			return Transform3D(Basis.from_scale(Vector3.ONE * s), _pos[i])


func _spread(dir: Vector3, angle: float) -> Vector3:
	# A random direction within `angle` of dir.
	var cos_a: float = lerpf(1.0, cos(angle), _rng.randf())
	var sin_a: float = sqrt(maxf(1.0 - cos_a * cos_a, 0.0))
	var phi: float = _rng.randf() * TAU
	var side: Vector3 = dir.cross(Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT).normalized()
	var up: Vector3 = side.cross(dir).normalized()
	return (dir * cos_a + (side * cos(phi) + up * sin(phi)) * sin_a).normalized()


func _make_mesh() -> Mesh:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if glow:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	match kind:
		Kind.SPARK:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(1.0, 1.0, 1.0)
			box.material = material
			return box
		Kind.CHUNK:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(1.0, 1.0, 1.0)
			box.material = material
			return box
		_:
			if not glow:
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			material.billboard_keep_scale = true
			material.albedo_texture = _soft_dot()
			material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
			var quad: QuadMesh = QuadMesh.new()
			quad.size = Vector2(1.0, 1.0)
			quad.material = material
			return quad


static var _dot: GradientTexture2D


## A soft round blot, white at its heart and clear at its edge, shared by every puff.
static func _soft_dot() -> GradientTexture2D:
	if _dot == null:
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.75))
		_dot = GradientTexture2D.new()
		_dot.gradient = g
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		_dot.width = 64
		_dot.height = 64
	return _dot
