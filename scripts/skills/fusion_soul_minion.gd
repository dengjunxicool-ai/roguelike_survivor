extends Node2D
const Registry = preload("res://scripts/combat/combat_target_registry.gd")
var _context: Dictionary = {}
var _actions: Array = []
var _expiry: float = 0.0
var _attack_at: float = 0.0
var _first: bool = true
var _generation: int = 0
func setup(context: Dictionary,duration: float,actions: Array) -> void:
 _context=context.duplicate(true);_actions=actions;_expiry=context.event_bus.combat_seconds()+duration;_generation=context.skill_manager.run_generation
 global_position=context.position
func _physics_process(delta: float) -> void:
 var bus: Node=_context.get("event_bus") as Node
 var manager: Node=_context.get("skill_manager") as Node
 if bus==null or manager==null or not is_instance_valid(manager) or manager.run_generation!=_generation or not manager.has_skill(_context.origin_skill_id) or bus.combat_seconds()>=_expiry: queue_free();return
 var candidates: Array=Registry.get_or_create(self).get_targets_in_radius(global_position,336,&"enemies")
 for target: Node2D in candidates:
  if target.is_dead(): continue
  global_position=global_position.move_toward(target.global_position,150.0*delta)
  if global_position.distance_to(target.global_position)<52.0 and bus.combat_seconds()>=_attack_at:
   var c: Dictionary=_context.duplicate(true);c.target=target;c.position=target.global_position;c.erase("target_statuses")
   bus.execute_adapted_actions(_actions if _first else [{"type":"deal_damage","params":{"amount":{"stat":"power","scale":0.25},"damage_type":"curse"}}],c)
   _first=false;_attack_at=bus.combat_seconds()+1.0
  break
func _draw() -> void:
 draw_circle(Vector2.ZERO,12,Color(0.7,0.25,0.9))
