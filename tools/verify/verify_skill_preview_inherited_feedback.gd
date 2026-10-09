extends "res://tools/verify/skill_m2_combat_fixture.gd"
const Preview = preload("res://scripts/ui/skill_preview_service.gd")
const HUD = preload("res://scripts/ui/hud/run_hud_state_provider.gd")
func _init() -> void: call_deferred("run")
func run() -> void:
	setup()
	expect(manager.set_primary_attack_method(&"fireball"),"real primary installed")
	expect(manager.add_skill(&"fire_attack_searing","normal"),"real inherited attack installed")
	var attack: RefCounted = manager.get_skill(&"fire_attack_searing")
	var preview: Dictionary = Preview.build(player,attack.skill_id,1,"normal")
	var context: Dictionary = ctx(enemy,attack)
	context.source_id=&"fireball_projectile"
	bus.emit_skill_event(&"on_projectile_hit",context)
	expect(not enemy.packets.is_empty() and absf(preview.damage-float(enemy.packets[0].raw_amount))<=1,"inherited primary damage in preview")
	var pulse: RefCounted = install(&"chaos_cast_mutation_pulse")
	var echo: RefCounted = install(&"chaos_power_echo_cast")
	bus.emit_skill_event(&"on_cast",ctx(enemy,pulse))
	var hud: RefCounted = HUD.new()
	expect(hud._skill_feedback(player,echo)=="回声充能 1/4","a snapshot does not mean charged")
	bus.get("_chaos").echo_count=4
	expect(hud._skill_feedback(player,echo)=="回声就绪","charged snapshot is ready")
	var cast: RefCounted = install(&"frost_cast_glacial_lance")
	cast.current_level=5
	var expected: float = preload("res://scripts/skills/skill_component_runner.gd").new().get_cooldown(cast,ctx(enemy,cast))
	expect(absf(float(hud._build_skill_slot(player,cast).cooldown_total)-expected)<=.01,"HUD uses final grown cooldown")
	finish()
