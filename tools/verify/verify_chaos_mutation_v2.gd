extends "res://tools/verify/skill_m2_combat_fixture.gd"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	setup()
	expect(bus.has_method("chaos_state"), "bounded chaos runtime exists")
	if failed > 0:
		finish()
		return
	install(&"chaos_passive_entropy_growth")
	install(&"chaos_power_fission_burst")
	install(&"chaos_passive_anomalous_stability")
	var cast: RefCounted = install(&"chaos_cast_mutation_pulse")
	for i: int in range(4):
		var context: Dictionary = ctx(enemy,cast)
		context.status_id = "instability"
		bus.emit_skill_event(&"status_max_stack_reached",context)
		var state: Dictionary = bus.chaos_state()
		expect(state.entropy_next == (i+1)%4 and state.entropy.size() == mini(i+1,2), "entropy rotates 4 branches, keeps last two %d" % i)
	advance(5.01)
	player.get_node("ModifierStore").tick_timed_sources(5.01)
	bus.update_skill_cycles()
	expect(bus.chaos_state().entropy.is_empty(), "entropy expires on combat clock")
	for i: int in range(5):
		bus.emit_skill_event(&"skill_cast_succeeded",ctx(enemy,cast))
	expect(bus.chaos_state().stability_ready, "five successful normal chaos casts charge next")
	var context: Dictionary = ctx(null,cast)
	bus.emit_skill_event(&"on_cast",context)
	expect(not bus.chaos_state().stability_ready, "sixth successful normal cast consumes charge")
	await physics_frame
	await physics_frame
	print("pulse packets: ",enemy.packets.map(func(x: Dictionary) -> int: return int(x.raw_amount)))
	expect(enemy.packets.any(func(x: Dictionary) -> bool: return int(x.raw_amount) == 113), "sixth pulse receives +25% once")
	var geometry: RefCounted = install(&"chaos_passive_geometric_imbalance")
	expect(bus.has_method("prepare_geometry"), "real one-generation geometry exists")
	if bus.has_method("prepare_geometry"):
		for i: int in range(3):
			var original: Dictionary = {"damage":{"stat":"power","scale":1.0},"count":1}
			var changed: Dictionary = bus.prepare_geometry(original,ctx(enemy,cast))
			expect(changed.get("chaos_geometry_branch",-1) == i and is_equal_approx(changed.damage.scale,0.9), "geometry rotates and original damage is 90 percent %d" % i)
			var child: Dictionary = ctx(enemy,cast)
			child.can_generate_secondary_proc = false
			expect(bus.prepare_geometry(changed,child) == changed, "child cannot transform a second generation")
	install(&"chaos_core_chaos_singularity")
	for i: int in range(25):
		var fission: Dictionary = ctx(enemy,cast)
		fission.status_id = "instability"
		bus.emit_skill_event(&"status_max_stack_reached",fission)
		await process_frame
	var bursts_before: int = burst_count()
	expect(bus.chaos_state().pending == 1 and bursts_before == 0, "25 fissions start suction without simultaneous burst")
	bus.update_skill_cycles()
	expect(burst_count() == 0, "pause with zero combat time preserves delayed burst")
	advance(1.99)
	bus.update_skill_cycles()
	expect(burst_count() == 0, "singularity waits full two seconds")
	advance(0.01)
	bus.update_skill_cycles()
	expect(burst_count() == 1 and bus.chaos_state().pending == 0, "singularity bursts exactly once at two seconds")
	bus.reset_run_state()
	expect(not bus.chaos_state().stability_ready and bus.chaos_state().entropy.is_empty(), "run reset clears chaos pending state")
	print("[verify_chaos_mutation_v2] " + ("PASS" if failed == 0 else "FAIL"))
	finish()

func burst_count() -> int:
	var total: int = 0
	for child: Node in root.get_children():
		if child is AreaEffect and child.source_id == &"chaos_singularity_burst": total += 1
	return total
