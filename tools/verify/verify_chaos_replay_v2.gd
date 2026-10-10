extends "res://tools/verify/skill_m2_combat_fixture.gd"
const Adapter = preload("res://scripts/skills/skill_effect_adapter.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	setup()
	expect(ResourceLoader.exists("res://scripts/skills/skill_cast_snapshot_service.gd"), "pure output snapshot service exists")
	expect(bus.has_method("replay_cast"), "bus has real replay entry")
	if failed > 0:
		finish()
		return
	var snapshots: RefCounted = load("res://scripts/skills/skill_cast_snapshot_service.gd").new()
	var cast: RefCounted = install(&"frost_cast_glacial_lance")
	cast.current_level = 2
	cast.current_rarity = "legendary"
	var actions: Array = Adapter.to_actions(cast.definition.trigger_rules[0].effects, cast)
	expect(snapshots.record(ctx(enemy, cast), actions), "successful lance records final actions")
	var snap: Dictionary = snapshots.get_last()
	expect(snap.origin_skill_id == "frost_cast_glacial_lance" and snap.base_growth_applied, "snapshot retains source and one-growth contract")
	expect(JSON.parse_string(JSON.stringify(snap)) == snap, "snapshot roundtrips pure JSON")
	var old: Dictionary = snap.duplicate(true)
	var summon: RefCounted = install(&"chaos_summon_chaos_clone")
	expect(not snapshots.record(ctx(enemy, summon), [{"type":"spawn_summon", "params":{}}]) and snapshots.get_last() == old, "summon cannot replace copyable record")
	var copy_ctx: Dictionary = ctx(enemy, cast)
	copy_ctx.is_copy = true
	expect(not snapshots.record(copy_ctx, actions), "copies never record themselves")
	var harmful: Array = [{"type":"instant_area_hit", "params":{"radius_r":2,"actions_on_apply":[{"type":"deal_damage","params":{"amount":100,"damage_type":"frost"}}],"actions_on_hit":[{"type":"heal_owner", "params":{"amount":500}}]}}, {"type":"grant_shield","params":{"amount":999}}, {"type":"repeat_skill","params":{}}]
	expect(snapshots.record(ctx(enemy,cast), harmful), "allowed output retained")
	var cleaned: Dictionary = snapshots.get_last()
	expect(cleaned.actions.size() == 1 and cleaned.actions[0].params.actions_on_hit.is_empty(), "business side effects stripped recursively")
	var before: int = enemy.current_health
	var context: Dictionary = ctx(enemy,cast)
	expect(bus.replay_cast(cleaned,context,0.4), "replay creates real original area output")
	expect(before - enemy.current_health == 40, "copy damage scale applied once through damage packet")
	expect(enemy.packets.back().is_copy and not enemy.packets.back().can_generate_secondary_proc, "copy packet cannot generate secondary copies")
	expect(not bus.replay_cast({},context,0.4), "empty record has no fake barrage")
	var dead: Enemy = make_enemy(Vector2(35,0))
	dead.current_health = 0
	context.target = dead
	before = enemy.current_health
	expect(bus.replay_cast(cleaned,context,0.35) and before-enemy.current_health == 35, "invalid target reselected, clone damage only once")
	snapshots.clear_origin(&"frost_cast_glacial_lance")
	expect(snapshots.get_last().is_empty(), "origin removal clears records")
	bus.emit_skill_event(&"on_cast",ctx(enemy,cast))
	expect(not bus.get_cast_snapshot({"skill_type":"cast"}).is_empty(), "real successful cast records output")
	bus.clear_origin(cast.skill_id)
	expect(bus.get_cast_snapshot().is_empty(), "replacement cleanup clears bus record")
	# Clone waits two seconds and copies the stored lance instead of firing chaos orbs.
	advance(10.0)
	bus.emit_skill_event(&"on_cast",ctx(enemy,cast))
	var clone: Node2D = preload("res://scripts/summons/summon_controller.gd").new()
	root.add_child(clone)
	clone.setup({"definition":preload("res://scripts/summons/summon_definition.gd").from_id(&"chaos_clone"),"owner":player,"parent":root,"event_bus":bus,"skill_manager":manager})
	clone.set_physics_process(false)
	await process_frame
	var count_before: int = projectiles().size()
	clone._physics_process_profiled(1.99)
	expect(projectiles().size() == count_before, "clone waits full two seconds")
	clone._physics_process_profiled(0.01)
	await process_frame
	expect(projectiles().size() == count_before+1, "clone creates original lance")
	if projectiles().is_empty(): finish(); return
	var copied: Node = projectiles().back()
	expect(String(copied.source_id) == String(bus.get_cast_snapshot().actions[0].params.projectile_id), "clone keeps original projectile identity")
	expect(copied.damage_packet.is_copy and copied.damage < 100, "clone original projectile is scaled 35 percent with no extra summon growth")
	clone.queue_free()
	var meteor: RefCounted = install(&"fire_cast_meteor_rain")
	bus.emit_skill_event(&"on_cast",ctx(enemy,meteor))
	var meteor_snapshot: Dictionary = bus.get_cast_snapshot({"skill_type":"cast"})
	expect(meteor_snapshot.origin_skill_id == "fire_cast_meteor_rain" and meteor_snapshot.actions[0].type == "spawn_projectiles_at_targets", "meteor records real delayed trajectory, not substitute barrage")
	expect(bus.replay_cast(meteor_snapshot,ctx(enemy,meteor),0.4), "meteor replay schedules original output")
	await create_timer(0.8).timeout
	print("[verify_chaos_replay_v2] " + ("PASS" if failed == 0 else "FAIL"))
	finish()

func projectiles() -> Array[Node]:
	var all: Array[Node] = []
	collect(root,all)
	return all
func collect(parent_node: Node, all: Array[Node]) -> void:
	for child: Node in parent_node.get_children():
		if child is Projectile: all.append(child)
		collect(child,all)
