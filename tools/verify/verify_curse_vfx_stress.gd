## 可复现表现压力测试：同样的真实战斗结果，独立测 CPU 和可见/隐藏 GPU 开销。
extends "res://tools/verify/qa_app_fixture.gd"
const Factory = preload("res://scripts/combat/combat_object_factory.gd")
const Enemy = preload("res://scenes/enemies/enemy.tscn")
const Crow = preload("res://scenes/effects/soul_crow_effect.tscn")
const Lynx = preload("res://scenes/effects/bone_servant_effect.tscn")
var effects: Array[Node2D] = []
var summons: Array[Node2D] = []
var targets: Array[Node2D] = []
var fields: Array[AreaEffect] = []
var projectiles: Array[Projectile] = []
var mode := "shown"
var output := "E:/codex/curse-vfx/stress/shown"
func percentile(samples: Array[float], portion: float) -> float:
	samples.sort()
	return samples[mini(int(samples.size()*portion),samples.size()-1)]
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="): mode=argument.trim_prefix("--mode=")
		if argument.begins_with("--capture-dir="): output=argument.trim_prefix("--capture-dir=").replace("\\","/").simplify_path()
	check(output.begins_with("E:/codex/"),"stress reports remain on E drive")
	if failures: quit(1); return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await setup_run()
	var parent: Node = player.get_parent()
	for i: int in 16:
		var enemy: Node2D = Enemy.instantiate()
		enemy.enemy_id=&"skeleton"
		parent.add_child(enemy)
		enemy.process_mode=Node.PROCESS_MODE_DISABLED
		enemy.global_position=player.global_position+Vector2(-210+(i%4)*140,-150+(i/4)*100)
		enemy.max_health=10000
		enemy.current_health=10000
		enemy.armor=0
		enemy.apply_status(&"cursed",{"stacks":3,"duration":10.0,"source":player})
		targets.append(enemy)
	for i: int in 8:
		var id: String = ["doom_circle_delay","doom_circle_burst","curse_whisper_burst","soul_explosion_area"][i%4]
		var area := Factory.create_area_effect({"parent":parent,"area_id":id,"source_id":id,"position":player.global_position+Vector2(-160+(i%4)*110,-100+(i/4)*190),"radius":100.0,"duration":20.0,"damage":10,"caster":player,"damage_packet":{"raw_amount":10,"amount":10,"damage_origin":"field","damage_type":"area_direct","element":"arcane","attacker":player,"source_skill_id":"curse_stress","source_id":id,"source_instance_id":"curse_stress_%d" % i}}) as AreaEffect
		area.set_physics_process(false)
		area._age=0.5
		area._visual_effect_node.update_state(area.radius,0.5,20.0)
		fields.append(area)
		effects.append(area._visual_effect_node)
		area.apply_immediate_tick_once()
	for i: int in 128:
		var id: String = ["black_serpent_projectile","death_scythe_projectile","soul_bolt_projectile","soul_storm_bolt"][i%4]
		var point: Vector2 = player.global_position+Vector2(-400+(i%16)*50,-170+(i/16)*48)
		var projectile := Factory.create_projectile({"parent":parent,"projectile_id":id,"source_id":id,"position":point,"direction":Vector2.from_angle(float(i)*0.618),"speed":540.0,"lifetime":20.0}) as Projectile
		projectile.set_physics_process(false)
		projectiles.append(projectile)
		effects.append(projectile._visual_effect_node)
	for i: int in 16:
		var effect: Node2D = Lynx.instantiate() if i%4==0 else Crow.instantiate()
		parent.add_child(effect)
		effect.global_position=player.global_position+Vector2(-330+(i%8)*90,-100+(i/8)*190)
		effect.configure_summon({"duration":20.0,"effect_scale":0.9})
		effect.set_attack_target(Vector2(110,0).rotated(float(i)*0.4))
		summons.append(effect)
		effects.append(effect)
	await settle()
	for i: int in 24:
		var arc: Node2D=preload("res://scripts/effects/curse_link_effect.gd").new()
		parent.add_child(arc)
		var begin: Vector2=player.global_position+Vector2(-320+(i%8)*90,-140+(i/8)*120)
		arc.configure(begin,begin+Vector2(90,60),float(i))
		arc.set_process(false)
		effects.append(arc)
	for target: Node2D in targets:
		var status: Node = target.get_node("StatusEffectManager")
		effects.append(status._status_visual_overlay.get_node("ProceduralStatus"))
	# CPU timings exclude draw and the real damage pipeline; repeat the same 16 poses.
	var cpu: Array[float]=[]
	for i: int in 360:
		if i%72==0:
			for effect: Node2D in summons: effect.play_attack()
		var started:=Time.get_ticks_usec()
		for effect: Node2D in summons: effect.update_summon(1.0/60.0,Vector2(1.2,0),10.0)
		cpu.append(float(Time.get_ticks_usec()-started)/1000.0)
	if mode=="hidden":
		for effect: Node2D in effects: RenderingServer.canvas_item_set_visible(effect.get_canvas_item(),false)
	var frames: Array[float]=[]
	var updates: Array[float]=[]
	var start:=Time.get_ticks_usec()
	var previous:=start
	var frame_index:=0
	while Time.get_ticks_usec()-start<4000000:
		await process_frame
		var now:=Time.get_ticks_usec()
		frames.append(float(now-previous)/1000.0)
		previous=now
		var age:=0.5+float(now-start)/1000000.0
		var update_start:=Time.get_ticks_usec()
		for projectile: Projectile in projectiles: projectile._visual_effect_node.update_projectile(age)
		for area: AreaEffect in fields: area._visual_effect_node.update_state(area.radius,age,20.0)
		for effect: Node2D in summons:
			if frame_index%72==0: effect.play_attack()
			effect.update_summon(1.0/60.0,Vector2(1.2,0),10.0)
		for target: Node2D in targets:
			var status: Node = target.get_node("StatusEffectManager")
			status._status_visual_overlay.get_node("ProceduralStatus")._process(1.0/60.0)
		updates.append(float(Time.get_ticks_usec()-update_start)/1000.0)
		frame_index+=1
	var health: Array[int]=[]
	for target: Node2D in targets: health.append(int(target.current_health))
	check(health.any(func(value: int)->bool: return value<10000),"stress workload uses actual enemy damage")
	var result: Dictionary={"mode":mode,"renderer":DisplayServer.get_name(),"resolution":root.size,"areas":8,"projectiles":128,"summons":16,"cursed_targets":16,"arcs":24,"frames":frames.size(),"p50_ms":percentile(frames,0.5),"p95_ms":percentile(frames,0.95),"max_ms":frames[-1],"visual_update_p95_ms":percentile(updates,0.95),"summon_cpu_p50_ms":percentile(cpu,0.5),"summon_cpu_p95_ms":percentile(cpu,0.95),"enemy_health":health}
	DirAccess.make_dir_recursive_absolute(output)
	var report:=FileAccess.open(output.path_join("metrics.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify(result,"\t"))
	report.close()
	print("[curse_stress] ",JSON.stringify(result))
	if DisplayServer.get_name()!="headless": await capture("curse_stress_"+mode)
	await finish()
