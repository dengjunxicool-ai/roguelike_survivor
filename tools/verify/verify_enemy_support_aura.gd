extends SceneTree
const EnemyScene = preload("res://scenes/enemies/enemy.tscn")
var failed := false
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var player := Node2D.new()
	player.position = Vector2(300,0)
	world.add_child(player)
	var drum := make_enemy(world, player, "war_drum_goblin", Vector2.ZERO)
	var ally := make_enemy(world, player, "skeleton", Vector2(100,0))
	var other := make_enemy(world, player, "war_drum_goblin", Vector2(40,0))
	var elite := make_enemy(world, player, "skeleton_captain", Vector2(80,0))
	var boss := make_enemy(world, player, "dungeon_heart", Vector2(90,0))
	var core := make_enemy(world, player, "skeleton", Vector2(120,0))
	core.set_meta("enemy_rank", "boss_core")
	var base_speed := float(ally.get("move_speed"))
	drum.call("_update_behavior", 0.01)
	var strategy: RefCounted = drum.get("_behavior_controller").get("_behavior")
	for index in range(29):
		drum.call("_update_behavior",1.0/60.0)
	expect(strategy.get("_scan_count")==1,"aura scan occurs once per 0.5 seconds, not each frame")
	expect(is_equal_approx(float(ally.call("_get_effective_move_speed")), base_speed * 1.15), "normal ally within 220 gains 1.15 move speed")
	other.call("_update_behavior", 0.01)
	expect(is_equal_approx(float(ally.call("_get_effective_move_speed")), base_speed * 1.15), "two drums take strongest instead of multiplying")
	for excluded: Node in [drum, other, elite, boss, core]:
		expect(is_equal_approx(float(excluded.call("_get_effective_move_speed")), float(excluded.get("move_speed"))), "excluded rank or drummer receives no buff")
	var buffs: RefCounted = ally.get("_support_buff_controller")
	expect(buffs != null, "enemy owns source-aware support buff controller")
	if buffs != null:
		ally.position = Vector2(500,0)
		buffs.call("tick",0.61)
		expect(is_equal_approx(float(ally.call("_get_effective_move_speed")), base_speed), "leaving aura restores speed within 0.6 seconds")
		ally.position = Vector2(100,0)
		drum.call("_update_behavior",0.5)
		other.call("_update_behavior",0.5)
		drum.set("_is_dead", true)
		expect(is_equal_approx(float(ally.call("_get_effective_move_speed")),base_speed*1.15), "another source survives one drummer death")
		other.set("_is_dead",true)
		expect(is_equal_approx(float(ally.call("_get_effective_move_speed")),base_speed), "last drummer death removes source immediately")
		drum.set("_is_dead",false)
		drum.call("_update_behavior",0.5)
		var status: RefCounted = ally.get("_status_facade")
		expect(bool(ally.call("apply_status", &"slow", {"duration": 2.0})), "real slow status applies")
		var slowed: float = status.call("get_effective_move_speed",base_speed)
		expect(slowed < base_speed and is_equal_approx(float(ally.call("_get_effective_move_speed")),slowed*1.15) and ally.get("move_speed")==base_speed, "support multiplies status speed and preserves base stat")
	await process_frame
	expect(_areas(world)==0, "drummer creates no damage field")
	world.queue_free()
	await process_frame
	quit(1 if failed else 0)
func make_enemy(world: Node, player: Node2D, id: String, position: Vector2) -> Node2D:
	var enemy: Node2D = EnemyScene.instantiate()
	enemy.set("enemy_id",StringName(id))
	world.add_child(enemy)
	enemy.position=position
	enemy.set("target",player)
	return enemy
func _areas(node: Node) -> int:
	var count:=0
	for child in node.get_children():
		if child is DamageArea and child.get("_attack_finished")==false:
			count+=1
		count+=_areas(child)
	return count
func expect(ok: bool,message: String) -> void:
	if not ok:
		failed=true
		push_error("[SupportAura] FAIL "+message)
	else:
		print("[SupportAura] PASS "+message)
