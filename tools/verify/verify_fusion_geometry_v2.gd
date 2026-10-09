extends SceneTree
const Geometry = preload("res://scripts/skills/skill_object_geometry.gd")
var failed: bool = false
func _init() -> void:
 call_deferred("run")
func check(ok: bool, label: String) -> void:
 if not ok: failed = true; push_error(label)
func run() -> void:
 var circle: Dictionary = {"position":Vector2.ZERO,"radius":20.0}
 var line: Dictionary = {"position":Vector2.ZERO,"shape":"line","length":100.0,"width":10.0,"direction":Vector2.RIGHT}
 check(Geometry.contains(line,Vector2(99,5)),"line grazing included")
 check(not Geometry.contains(line,Vector2(50,6)),"line broadphase is not actual geometry")
 check(Geometry.overlaps(circle,{"position":Vector2(40,0),"radius":20.0}),"circle grazing")
 check(not Geometry.overlaps(circle,{"position":Vector2(41,0),"radius":20.0}),"separated circles")
 check(Geometry.overlaps(line,{"position":Vector2(50,20),"shape":"line","length":40.0,"width":4.0,"direction":Vector2.UP}),"crossing lines")
 check(not Geometry.overlaps(line,{"position":Vector2(50,20),"radius":10.0}),"near line no intersection")
 check(Geometry.swept(circle,Vector2(-100,0),Vector2(100,0)),"fast projectile crossing")
 check(not Geometry.swept(circle,Vector2(-100,21),Vector2(100,21)),"fast projectile miss")
 var cone: Dictionary = {"position":Vector2.ZERO,"radius":100.0,"shape":"cone","angle":60.0,"direction":Vector2.RIGHT}
 check(Geometry.contains(cone,Vector2(50,0)) and not Geometry.contains(cone,Vector2(-20,0)),"oriented cone")
 if not failed: print("[verify_fusion_geometry_v2] PASS")
 quit(1 if failed else 0)
