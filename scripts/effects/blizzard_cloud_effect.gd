## 文件用途：以流动云雾 Shader、双层 GPU 飘雪与冰晶闪光表现移动暴雪区域。
## 使用方式：由 AreaEffect configure/update_state 驱动；只消费视觉参数，不拥有战斗计时或全局 RNG。
extends Node2D

const FADE_IN_SECONDS: float = 0.30
const FADE_OUT_SECONDS: float = 0.55
const SPEED_MIN: Array[float] = [22.0, 60.0, 0.0]
const SPEED_MAX: Array[float] = [48.0, 96.0, 4.0]
var effect_radius: float = 168.0
var effect_duration: float = 5.0
var effect_age: float = 0.0
var _emitters: Array[GPUParticles2D] = []
var _cloud: ShaderMaterial
var _ground: ShaderMaterial

func _ready() -> void:
	_cloud = $CloudCanopy.material as ShaderMaterial
	_ground = $GroundFrost.material as ShaderMaterial
	_emitters.assign([$SnowFlakes, $IceStreaks, $IceImpacts])
	# Materials are built once per pooled visual. Emission and simulation stay on the GPU.
	_build_particles(_emitters[0], Color(0.84, 0.95, 1.0, 0.82), 22.0, 48.0, 0.23, 0.52)
	_build_particles(_emitters[1], Color(0.70, 0.89, 1.0, 0.74), 60.0, 96.0, 0.35, 0.68)
	_build_particles(_emitters[2], Color(0.88, 0.98, 1.0, 0.65), 0.0, 4.0, 0.35, 0.75)
	deactivate()

## 配置一次 spawn；种子来自宿主相位，不调用 randf/randi/randomize。
func configure(radius: float, duration: float, visual_phase: float) -> void:
	visible = true
	effect_duration = maxf(duration, 0.05)
	effect_age = 0.0
	set_effect_radius(radius)
	_cloud.set_shader_parameter("phase", visual_phase)
	_ground.set_shader_parameter("phase", visual_phase)
	for index: int in range(_emitters.size()):
		var emitter: GPUParticles2D = _emitters[index]
		emitter.seed = absi(int(visual_phase * 10007.0)) + index * 1031 + 1
		emitter.preprocess = emitter.lifetime * 0.45
		emitter.restart(true)
		emitter.emitting = true
	update_state(radius, 0.0, effect_duration)

## 同步技能时钟，支持持续时间延长；暂停时宿主停止更新，Shader 不使用 TIME。
func update_state(radius: float, age: float, duration: float) -> void:
	if not visible:
		return
	if not is_equal_approx(effect_radius, radius):
		set_effect_radius(radius)
	effect_age = maxf(age, 0.0)
	effect_duration = maxf(duration, 0.05)
	var fade_in: float = smoothstep(0.0, minf(FADE_IN_SECONDS, effect_duration * 0.25), effect_age)
	var remaining: float = maxf(effect_duration - effect_age, 0.0)
	var fade_out: float = smoothstep(0.0, minf(FADE_OUT_SECONDS, effect_duration * 0.35), remaining)
	var opacity: float = fade_in * fade_out
	_cloud.set_shader_parameter("effect_age", effect_age)
	_ground.set_shader_parameter("effect_age", effect_age)
	_cloud.set_shader_parameter("opacity", opacity)
	_ground.set_shader_parameter("opacity", opacity)
	for emitter: GPUParticles2D in _emitters:
		emitter.modulate.a = opacity
		emitter.emitting = remaining > minf(0.25, effect_duration * 0.2)

## 范围变化仅更新两张四边形、发射范围和可见性边界，不重建材质。
func set_effect_radius(radius: float) -> void:
	effect_radius = maxf(radius, 1.0)
	$GroundFrost.scale = Vector2.ONE * effect_radius * 1.08
	$CloudCanopy.scale = Vector2(effect_radius * 1.08, effect_radius * 0.92)
	$CloudCanopy.position = Vector2(0.0, -effect_radius * 0.14)
	for index: int in range(_emitters.size()):
		var emitter: GPUParticles2D = _emitters[index]
		var material: ParticleProcessMaterial = emitter.process_material
		material.emission_sphere_radius = effect_radius * (0.77 if index == 2 else 0.72)
		# Velocity scales down for small radii so ice stays inside the visual footprint.
		material.initial_velocity_min = SPEED_MIN[index] * minf(effect_radius / 168.0, 1.5)
		material.initial_velocity_max = SPEED_MAX[index] * minf(effect_radius / 168.0, 1.5)
		material.gravity = Vector3(8.0, 22.0, 0.0) * minf(effect_radius / 168.0, 1.5) if index != 2 else Vector3.ZERO
		emitter.position.y = -effect_radius * 0.15 if index != 2 else 0.0
		emitter.visibility_rect = Rect2(Vector2(-effect_radius * 1.4, -effect_radius * 1.6), Vector2(effect_radius * 2.8, effect_radius * 3.0))

## 回池立即关闭发射并隐藏所有层；再次 configure 时 restart 清除旧粒子。
func deactivate() -> void:
	visible = false
	for emitter: GPUParticles2D in _emitters:
		emitter.emitting = false
		emitter.modulate.a = 0.0

func _build_particles(emitter: GPUParticles2D, color: Color, speed_min: float, speed_max: float, size_min: float, size_max: float) -> void:
	var material := ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.direction = Vector3(0.35, 1.0, 0.0)
	material.spread = 22.0
	material.initial_velocity_min = speed_min
	material.initial_velocity_max = speed_max
	material.scale_min = size_min
	material.scale_max = size_max
	material.angular_velocity_min = -95.0
	material.angular_velocity_max = 95.0
	material.color = color
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.12, 0.7, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	material.color_ramp = ramp
	emitter.process_material = material
