## 出生与移动共用地图边界；背景用弱引用缓存，避免每只怪物每帧遍历节点树。
extends RefCounted
static var _background_ref: WeakRef
static var _tree_id := 0
static var _lookup_frame := -1

static func get_bounds(owner: Node) -> Rect2:
	if not is_instance_valid(owner) or owner.get_tree()==null:
		return Rect2()
	var tree := owner.get_tree()
	var background: Sprite2D = _background_ref.get_ref() as Sprite2D if _background_ref!=null else null
	if _tree_id!=tree.get_instance_id():
		background=null
		_background_ref=null
		_lookup_frame=-1
		_tree_id=tree.get_instance_id()
	if not is_instance_valid(background) or background.is_queued_for_deletion():
		if _lookup_frame!=Engine.get_process_frames():
			_lookup_frame=Engine.get_process_frames()
			background=tree.root.find_child("DungeonBackground",true,false) as Sprite2D
			_background_ref=weakref(background) if background!=null else null
		else:
			return Rect2()
	if not is_instance_valid(background) or background.texture==null:
		return Rect2()
	var size := background.texture.get_size()*background.global_scale.abs()
	var start := background.global_position-size*0.5 if background.centered else background.global_position
	return Rect2(start,size)

static func clamp_position(owner: Node, position: Vector2, radius: float) -> Vector2:
	var bounds := get_bounds(owner)
	if bounds.size.x<=0.0 or bounds.size.y<=0.0:
		return position
	var inside := bounds.grow(-radius)
	if inside.size.x<=0.0 or inside.size.y<=0.0:
		return bounds.get_center()
	return position.clamp(inside.position,inside.end)

static func limit_velocity(owner: Node2D, velocity: Vector2, delta: float, radius: float) -> Vector2:
	if delta<=0.0 or velocity.length_squared()<=0.01:
		return velocity
	var destination := clamp_position(owner,owner.global_position+velocity*delta,radius)
	return (destination-owner.global_position)/delta
