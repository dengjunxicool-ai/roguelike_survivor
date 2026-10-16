## 文件用途：保护动作浮点读取的缺失、显式空值与动态元数据逐读语义。
extends SceneTree
const Reader=preload("res://scripts/combat/optional_combat_property_reader.gd")
const Support=preload("res://scripts/skills/skill_action_support.gd")
class StaticValues extends RefCounted:
 var number: Variant=0.0
 var reads: int=0
 var nullable: Variant:
  get:
   reads+=1
   return null
class DynamicValues extends RefCounted:
 var expose_defense: bool=false
 var trace: Array=[]
 func _get_property_list() -> Array[Dictionary]:
  trace.append("list")
  var values: Array[Dictionary]=[{"name":"armor","type":TYPE_FLOAT},{"name":"nullable","type":TYPE_NIL}]
  if expose_defense: values.append({"name":"defense","type":TYPE_FLOAT})
  return values
 func _get(property: StringName) -> Variant:
  trace.append("get:"+String(property))
  if property==&"armor": expose_defense=true;return 2.5
  if property==&"defense": return -3.0
  if property==&"hidden": return 99.0
  return null
class InheritedDynamic extends DynamicValues:
 pass
class ValidatedValues extends RefCounted:
 var number: float=4.5
 var validates: int=0
 func _validate_property(property: Dictionary) -> void:
  if property.name=="number": validates+=1
class InheritedValidated extends ValidatedValues:
 pass
var failures: Array[String]=[]
var checks: int=0
func _init() -> void: call_deferred("run")
func expect(ok: bool,label: String) -> void:
 checks+=1
 if not ok: failures.append(label);push_warning(label)
func legacy(object: Object,property: String,fallback: float) -> float:
 if object==null: return fallback
 for info: Dictionary in object.get_property_list():
  if str(info.get("name",""))==property:
   var value: Variant=object.get(property)
   # Godot 4.6 float(null) reports a script error then returns zero. Assert the
   # numeric contract without deliberately emitting that error in the oracle.
   return 0.0 if value==null else float(value)
 return fallback
func run() -> void:
 var reader: RefCounted=Reader.new()
 var support: RefCounted=Support.new()
 var api: String="read_float_preserving_null"
 expect(reader.has_method(api),"dedicated present-null API exists")
 if reader.has_method(api):
  expect(reader.call(api,null,"number",7.0)==7.0,"null object fallback")
  var object: RefCounted=StaticValues.new()
  expect(not Reader.uses_dynamic_properties(object),"nullable getter does not activate dynamic fallback")
  for value: Variant in [null,0.0,-4.25,2.5]:
   object.number=value
   var expected: float=legacy(object,"number",7.0)
   expect(reader.call(api,object,"number",7.0)==expected,"static value "+str(value))
   expect(support._get_float_property(object,"number",7.0)==expected,"Support static value "+str(value))
  expect(reader.call(api,object,"missing",7.0)==7.0,"missing property fallback")
  object.reads=0
  expect(reader.call(api,object,"nullable",7.0)==0.0 and object.reads==1,"present null getter exactly once")
  object.reads=0
  expect(support._get_float_property(object,"nullable",7.0)==0.0 and object.reads==1,"Support present null getter exactly once")
  for derived: bool in [false,true]:
   var dynamic: RefCounted=InheritedDynamic.new() if derived else DynamicValues.new()
   var reference: RefCounted=InheritedDynamic.new() if derived else DynamicValues.new()
   expect(Reader.uses_dynamic_properties(dynamic),"inherited dynamic hook detection "+str(derived))
   for property: String in ["hidden","defense","armor","defense","nullable","missing"]:
    var expected: float=legacy(reference,property,7.0)
    expect(reader.call(api,dynamic,property,7.0)==expected,"dynamic value "+property)
    expect(dynamic.trace==reference.trace,"dynamic whitelist/getter order "+property)
   expect(not dynamic.trace.has("get:hidden"),"unlisted _get ignored")
   dynamic=InheritedDynamic.new() if derived else DynamicValues.new()
   reference=InheritedDynamic.new() if derived else DynamicValues.new()
   for property: String in ["hidden","armor","defense","nullable"]:
    expect(support._get_float_property(dynamic,property,7.0)==legacy(reference,property,7.0),"Support dynamic value "+property)
    expect(dynamic.trace==reference.trace,"Support dynamic ordering "+property)
  for object_with_validation: RefCounted in [ValidatedValues.new(),InheritedValidated.new()]:
   expect(Reader.uses_dynamic_properties(object_with_validation),"validation hook detected")
   var before: int=object_with_validation.validates
   expect(reader.call(api,object_with_validation,"number",7.0)==4.5,"validation value")
   expect(object_with_validation.validates>before,"validation metadata side effect retained")
  var player: Node=load("res://scenes/characters/player.tscn").instantiate()
  var enemy: Node=load("res://scenes/enemies/enemy.tscn").instantiate()
  enemy.enemy_id=&"armored_skeleton"
  root.add_child(player);root.add_child(enemy)
  for actor: Node in [player,enemy]:
   expect(not Reader.uses_dynamic_properties(actor),"real actor static "+actor.name)
   for property: String in ["crit_damage","damage_multiplier","max_health","current_health","unknown_property"]:
    var expected: float=legacy(actor,property,7.0)
    expect(reader.call(api,actor,property,7.0)==expected,"real actor reader "+property)
    expect(support._get_float_property(actor,property,7.0)==expected,"real actor Support "+property)
  player.queue_free();enemy.queue_free()
  await process_frame
  await process_frame
 print("[verify_skill_action_float_property_access] checks=",checks," failures=",failures)
 quit(0 if failures.is_empty() else 1)
