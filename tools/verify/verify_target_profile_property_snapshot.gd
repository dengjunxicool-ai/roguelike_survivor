## Defensive snapshots stay live and independent; dynamic metadata retains legacy reads.
extends SceneTree
const Resolver = preload("res://scripts/combat/target_damage_profile_resolver.gd")
class DynamicSchema:
 extends Node2D
 var list_reads: int = 0
 var unlocked: bool = false
 var read_order: Array[String] = []
 var mutate_rank: bool = false
 func _get_property_list() -> Array[Dictionary]:
  list_reads += 1
  if mutate_rank:
   set_meta("enemy_rank","boss")
   add_to_group(&"player")
  var properties: Array[Dictionary] = [{"name":"armor","type":TYPE_FLOAT}]
  if unlocked:
   properties.append({"name":"defense","type":TYPE_FLOAT})
   properties.append({"name":"resistances","type":TYPE_DICTIONARY})
   properties.append({"name":"player_damage_reduction_total","type":TYPE_FLOAT})
  return properties
 func _get(key: StringName) -> Variant:
  read_order.append(String(key))
  if key == &"armor": unlocked = true; return 7.0
  if key == &"defense": return 19.0
  if key == &"resistances": return {"fire":0.2}
  if key == &"player_damage_reduction_total": return 0.3
  return null
class InheritedDynamic:
 extends DynamicSchema
class ValidatedSchema:
 extends Node2D
 var checks: int = 0
 var armor: float = 13.0
 func _validate_property(_property: Dictionary) -> void: checks += 1
class NullFields:
 extends Node2D
 var armor: Variant = null
 var defense: Variant = null
 var resistances: Variant = null
 var player_damage_reduction_total: Variant = null
var failed: int = 0
func _init() -> void: call_deferred("run")
func expect(ok: bool,label: String) -> void:
 print(("PASS " if ok else "FAIL ")+label)
 if not ok: failed += 1
func run() -> void:
 var plain := Node2D.new()
 root.add_child(plain)
 var empty: RefCounted = Resolver.resolve(plain)
 expect(empty.armor == 0.0 and empty.defense == 0.0 and empty.resistances.is_empty() and empty.incoming_damage_reduction == 0.0,"generic Node missing defensive fields preserves defaults")
 plain.free()
 var null_fields := NullFields.new()
 var nulls: RefCounted = Resolver.resolve(null_fields)
 expect(nulls.armor == 0.0 and nulls.defense == 0.0 and nulls.resistances.is_empty(),"explicit null defensive fields preserve defaults")
 null_fields.free()
 var no_target: RefCounted = Resolver.resolve(null)
 expect(no_target.armor == 0.0 and no_target.target_type == &"normal","null target preserves full profile defaults")
 for inherited: bool in [false,true]:
  var dynamic: DynamicSchema = InheritedDynamic.new() if inherited else DynamicSchema.new()
  root.add_child(dynamic)
  dynamic.list_reads = 0
  dynamic.read_order.clear()
  dynamic.unlocked = false
  dynamic.mutate_rank = true
  dynamic.set_meta("enemy_rank","normal")
  var value: RefCounted = Resolver.resolve(dynamic)
  expect(dynamic.list_reads == 4,"dynamic schema is re-enumerated for all four reads")
  expect(value.armor == 7.0 and value.defense == 19.0 and value.resistances == {"fire":0.2} and value.incoming_damage_reduction == 0.3,"armor getter can reveal later defensive fields")
  expect(dynamic.read_order == ["armor","defense","resistances","player_damage_reduction_total"],"dynamic getter read order remains unchanged")
  expect(value.target_type == &"normal" and dynamic.is_in_group(&"player"),"classification precedes metadata side effects that change rank and player group")
  dynamic.free()
 var validated := ValidatedSchema.new()
 var validated_profile: RefCounted = Resolver.resolve(validated)
 expect(validated_profile.armor==13.0 and validated.checks>0,"validate_property override preserves metadata queries and current values")
 validated.free()
 verify_actual("res://scenes/enemies/enemy.tscn")
 verify_actual("res://scenes/characters/player.tscn")
 await process_frame
 await process_frame
 print("[verify_target_profile_property_snapshot] failures=",failed)
 quit(1 if failed > 0 else 0)
func verify_actual(path: String) -> void:
 var target: Node = load(path).instantiate()
 root.add_child(target)
 target.set_physics_process(false)
 var executor: Node = target.get_node_or_null("SkillExecutor")
 if executor != null: executor.set_physics_process(false)
 expect(not target.has_method("_get_property_list") and not target.has_method("_get") and not target.has_method("_validate_property"),"real target uses static metadata: "+path)
 target.armor = 17
 var has_resistances: bool = target.get("resistances") is Dictionary
 if has_resistances: target.resistances = {"fire":0.2}
 var first: RefCounted = Resolver.resolve(target)
 expect(first.armor == 17.0 and (first.resistances.get("fire",0.0) == 0.2 if has_resistances else first.resistances.is_empty()),"real target reads live defense with missing-field fallback: "+path)
 first.resistances.fire = 0.8
 expect(target.resistances.fire == 0.2 if has_resistances else Resolver.resolve(target).resistances.is_empty(),"real target resistance snapshot is independent: "+path)
 target.armor = 29
 if has_resistances: target.resistances.fire = 0.5
 var next: RefCounted = Resolver.resolve(target)
 expect(next.armor == 29.0 and (next.resistances.get("fire",0.0) == 0.5 if has_resistances else next.resistances.is_empty()),"next resolve refreshes defensive values: "+path)
 expect(next.defense == float(target.get("defense")) if target.get("defense") != null else next.defense == next.armor,"real defense fallback remains unchanged: "+path)
 target.queue_free()
