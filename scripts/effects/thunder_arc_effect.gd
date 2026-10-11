## 实际连锁命中之间的短促电弧；纯展示，由上层管理24实例池。
extends Node2D

const DURATION: float = 0.22
const SEGMENTS: int = 12
var _age: float = 0.0
var _active: bool = false
var _lines: Array[Line2D] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_ensure_lines()
	set_process(_active)


## 九条固定线：三层主干和三条双层分叉；配置时更新一次折线。
func _ensure_lines() -> void:
	if not _lines.is_empty():
		return
	top_level = true
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 4
	for index: int in range(9):
		var line: Line2D = Line2D.new()
		line.name = "Core" if index == 2 else "ArcLayer%d" % index
		line.width = [11.0, 4.5, 1.4][index] if index < 3 else (4.0 if index % 2 == 1 else 1.0)
		line.default_color = [Color(0.36, 0.23, 1.0, 0.22), Color(0.22, 0.72, 1.0, 0.78), Color(0.86, 0.98, 1.0, 1.0)][index] if index < 3 else (Color(0.32, 0.56, 1.0, 0.38) if index % 2 == 1 else Color(0.69, 0.91, 1.0, 0.78))
		line.joint_mode = Line2D.LINE_JOINT_BEVEL
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.antialiased = true
		add_child(line)
		_lines.append(line)


func configure(from: Vector2, to: Vector2, seed: float) -> void:
	_ensure_lines()
	global_position = from
	global_rotation = 0.0
	global_scale = Vector2.ONE
	_age = 0.0
	_active = true
	visible = true
	modulate = Color.WHITE
	var span: Vector2 = to - from
	var length: float = span.length()
	var direction: Vector2 = span.normalized() if length > 0.001 else Vector2.RIGHT
	var normal: Vector2 = Vector2(-direction.y, direction.x)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(seed * 65537.0)
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(SEGMENTS + 1):
		var t: float = index / float(SEGMENTS)
		var displacement: float = rng.randf_range(-1.0, 1.0) * minf(length * 0.09, 18.0) * sin(t * PI)
		points.append(span * t + normal * displacement)
	points[0] = Vector2.ZERO
	points[SEGMENTS] = span
	for index: int in range(3):
		_lines[index].points = points
	for branch: int in range(3):
		var begin: Vector2 = points[3 + branch * 3]
		var polarity: float = -1.0 if branch % 2 == 0 else 1.0
		var reach: float = minf(length * 0.18, 42.0)
		var fork: PackedVector2Array = PackedVector2Array()
		for segment: int in range(4):
			var t: float = segment / 3.0
			fork.append(begin + direction * reach * t * 0.6 + normal * (polarity * reach * t + rng.randf_range(-4.0, 4.0) * sin(t * PI)))
		fork[0] = begin
		_lines[3 + branch * 2].points = fork
		_lines[4 + branch * 2].points = fork
	set_process(true)


func _process(delta: float) -> void:
	if not _active:
		return
	_age += maxf(delta, 0.0)
	if _age >= DURATION:
		deactivate()
		return
	var progress: float = _age / DURATION
	modulate.a = pow(1.0 - progress, 0.65) * (0.85 + 0.15 * cos(progress * 22.0))


func deactivate() -> void:
	_active = false
	visible = false
	set_process(false)
