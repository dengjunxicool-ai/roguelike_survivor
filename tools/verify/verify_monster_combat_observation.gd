extends SceneTree
const Observation = preload("res://tools/verify/fixtures/monster_combat_observation.gd")
var failed := false
func _init() -> void: call_deferred("run")
func run() -> void:
	var data = Observation.new()
	data.enroll(1,{"enemy":"armored"},100)
	data.health_changed(1,100,2,{"level":1})
	data.health_changed(1,80,10,{"level":2})
	data.health_changed(1,90,11,{"level":3})
	data.health_changed(1,0,14,{"level":4})
	data.finish(1,14,"killed")
	check(data.rows[1].first_hit_seconds==10.0,"first damage excludes waiting and healing")
	check(data.rows[1].get("first_hit_context",{}).get("level")==2,"retain initial hit build context")
	check(data.rows[1].ttk_seconds==4.0,"TTK measures first health loss to real death")
	data.finish(1,20,"cleanup")
	check(data.rows[1].outcome=="killed","cleanup cannot overwrite death")
	data.enroll(2,{},100)
	data.health_changed(2,70,10,{})
	data.finish(2,12,"cleanup")
	check(data.rows[2].ttk_seconds==null,"uncompleted kill is censored")
	check(data.rows[2].get("observed_after_hit_seconds")==2.0,"retain censored exposure")
	var copy: Array=data.snapshot()
	copy[0].outcome="changed"
	check(data.rows[1].outcome=="killed","output snapshot is independent")
	print("[monster_combat_observation] ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
func check(ok: bool,label: String) -> void:
	if ok: return
	failed=true
	push_error(label)
