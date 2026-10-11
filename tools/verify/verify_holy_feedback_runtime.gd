## 真实应用、敌人与动作执行器验证神圣反馈；展示不可改变战斗资源。
extends "res://tools/verify/qa_app_fixture.gd"

const Fixture = preload("res://tools/verify/skill_rebalance_fixture.gd")
const EnemyScene = preload("res://scenes/enemies/enemy.tscn")
const Executor = preload("res://scripts/skills/skill_action_executor.gd")
const Absorb = preload("res://scripts/combat/application_stages/player_absorb_application_stage.gd")
const Application = preload("res://scripts/combat/damage_application_context.gd")
const Pipeline = preload("res://scripts/combat/damage_application_pipeline.gd")
const DEVOTION_SOURCE: String = "skill:holy_passive_devotion:damage_multiplier_add"
var _bus: Node
var _view: Node
var _executor: RefCounted

func run() -> void:
	await setup_run()
	_bus = player.get_node("SkillEventBus")
	_executor = Executor.new()
	_verify_judgment_rounding()
	if "--shield-rounding-only" in OS.get_cmdline_user_args():
		await finish()
		return
	_view = _bus.get_node_or_null("HolyCombatPresentation")
	check(_view != null, "production holy presentation attaches to real app")
	if _view == null:
		await finish()
		return
	_view.reset_presentation()
	_verify_actual_hits()
	_verify_shield_and_devotion()
	await _verify_guardian()
	_verify_pool_limits()
	_verify_actual_status_priority()
	await _verify_pause_and_cleanup()
	await finish()

func _verify_judgment_rounding() -> void:
	check(player.max_health == 75, "default Mage starts with seventy-five max HP")
	player.set_meta("fire_passive_shield", 0)
	var action: Dictionary = {"type":"grant_shield", "params":{"max_health_ratio":0.005, "shield_type":"holy_judgment", "duration":6.0, "respect_shield_cap":true, "shield_cap_health_ratio":0.35}}
	var granted: bool = bool(_executor.execute_action(action, _context(null, &"holy_attack_judgment")))
	check(granted and int(player.get_meta("fire_passive_shield", 0)) > 0, "positive canonical judgment ratio grants actual shield to default Mage")
	player.set_meta("fire_passive_shield", 0)
	player.set_meta("fire_passive_shield_expires_at", 0.0)
	for ratio: float in [0.0, -0.005]:
		action["params"]["max_health_ratio"] = ratio
		check(not bool(_executor.execute_action(action, _context(null, &"holy_attack_judgment"))) and int(player.get_meta("fire_passive_shield", 0)) == 0, "nonpositive judgment ratio %.3f still grants no shield" % ratio)
	action["params"]["max_health_ratio"] = 0.005
	action["params"]["shield_type"] = "unrelated"
	check(not bool(_executor.execute_action(action, _context(null, &"holy_attack_judgment"))) and int(player.get_meta("fire_passive_shield", 0)) == 0, "small unrelated shield ratio retains existing rounding behavior")

func _enemy_at(offset: Vector2) -> Node2D:
	var enemy: Node2D = EnemyScene.instantiate()
	enemy.enemy_id = &"skeleton"
	player.get_parent().add_child(enemy)
	enemy.global_position = player.global_position + offset
	enemy.max_health = 1000
	enemy.current_health = 1000
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	return enemy

func _visible_count(items: Array) -> int:
	var count: int = 0
	for item: Node2D in items:
		if item.visible:
			count += 1
	return count

func _verify_actual_hits() -> void:
	var enemy: Node2D = _enemy_at(Vector2(100, 0))
	_executor.execute_action({"type":"deal_damage", "params":{"amount":0, "damage_type":"holy"}}, _context(enemy, &"holy_cast_holy_ray"))
	check(enemy.current_health == 1000 and _visible_count(_view._hits) == 0, "zero actual holy damage creates no impact")
	_executor.execute_action({"type":"deal_damage", "params":{"amount":12, "damage_type":"holy"}}, _context(enemy, &"holy_cast_holy_ray"))
	check(enemy.current_health < 1000 and _visible_count(_view._hits) == 1, "positive actual holy ray damage creates one impact")
	if not _view._hits.is_empty():
		check(int(_view._hits[0]._material.get_shader_parameter("profile")) == 1, "actual holy ray source selects ray impact profile")
	_view.reset_presentation()
	var dot_target: Node2D = _enemy_at(Vector2(180, 0))
	_executor.execute_action({"type":"deal_damage", "params":{"amount":12, "damage_type":"holy", "damage_origin":"status_dot"}}, _context(dot_target, &"holy_cast_holy_ray"))
	check(dot_target.current_health < 1000 and _visible_count(_view._hits) == 0, "actual holy status DOT loses HP without false direct impact")
	var plain: Node2D = _enemy_at(Vector2(220, 0))
	_executor.execute_action({"type":"deal_damage", "params":{"amount":12, "damage_type":"physical"}}, _context(plain, &"hunter_cast_arrow"))
	check(plain.current_health < 1000 and _visible_count(_view._hits) == 0, "unrelated actual physical damage creates no holy impact")
	var holy: Node2D = _enemy_at(Vector2(260, 0))
	_executor.execute_action({"type":"deal_damage", "params":{"amount":12, "damage_type":"holy"}}, _context(holy, &"holy_cast_judgment_hammer"))
	check(holy.current_health < 1000 and _visible_count(_view._hits) == 1, "positive actual holy skill damage creates generic impact")
	var health_before: int = holy.current_health
	for hit: Node2D in _view._hits:
		if hit.visible:
			hit._process(1.0)
	check(holy.current_health == health_before and _visible_count(_view._hits) == 0, "feedback expires without extra damage")

func _grant(amount: int, id: StringName = &"holy_cast_divine_barrier") -> bool:
	return bool(_executor.execute_action({"type":"grant_shield", "params":{"amount":amount, "duration":6.0, "shield_type":"divine_barrier", "respect_shield_cap":true, "shield_cap_health_ratio":0.35}}, _context(null, id)))

func _verify_shield_and_devotion() -> void:
	_view.reset_presentation()
	manager.clear_skills()
	player.set_meta("fire_passive_shield", 0)
	player.set_meta("fire_passive_shield_expires_at", 0.0)
	check(Fixture.install_runtime_skill(manager, &"holy_passive_devotion"), "install real canonical holy devotion listener")
	var store: Node = player.get_node("ModifierStore")
	store.set_timed_source("skill:unrelated:damage_multiplier_add", [{"stat":"damage", "op":"multiplier_add", "value":0.2, "scope":{}, "source":"skill"}], [], 4.0)
	_view._process(0.11)
	check(_view._devotion == null or not _view._devotion.visible, "unrelated positive damage source cannot show devotion")
	store.clear_source("skill:unrelated:damage_multiplier_add")
	for value: float in [0.0, -0.2]:
		store.set_timed_source(DEVOTION_SOURCE, [{"stat":"damage", "op":"multiplier_add", "value":value, "scope":{}, "source":"skill"}], [], 4.0)
		_view._process(0.11)
		check(_view._devotion == null or not _view._devotion.visible, "nonpositive exact devotion source %.1f cannot display positive buff aura" % value)
	store.clear_source(DEVOTION_SOURCE)
	var before: int = _visible_count(_view._bursts)
	check(not _grant(0), "zero shield action grants no gameplay shield")
	check(_visible_count(_view._bursts) == before, "zero shield action creates no restoration pulse")
	check(_grant(12), "real holy action grants twelve shield points")
	_view._process(0.11)
	check(int(player.get_meta("fire_passive_shield", 0)) == 12 and _view._shield != null and _view._shield.visible, "positive actual shield displays live shield aura")
	check(_visible_count(_view._bursts) == before + 1, "positive actual shield gain creates restoration pulse")
	var actual_shield: int = int(player.get_meta("fire_passive_shield", 0))
	var expiry: float = float(player.get_meta("fire_passive_shield_expires_at", 0.0))
	_view._process(0.11)
	check(int(player.get_meta("fire_passive_shield", 0)) == actual_shield and float(player.get_meta("fire_passive_shield_expires_at", 0.0)) == expiry, "aura refresh preserves actual shield value and expiry")
	var health_before: int = player.current_health
	before = _visible_count(_view._bursts)
	var application: RefCounted = Application.create(player, DamagePacket.from_dictionary({"raw_amount":5, "amount":5, "element":"physical"}))
	application.incoming_amount = 5
	var absorb_queue_before: int = _bus._pending_events.size()
	var absorb_budget_before: int = _bus._frame_events
	Absorb.new().apply_with_host(Pipeline, application)
	check(application.absorbed_amount == 0 and int(player.get_meta("fire_passive_shield", 0)) == 7 and player.current_health == health_before, "actual shield fully absorbs five damage without HP loss")
	check(_visible_count(_view._bursts) == before + 1, "fully absorbed real hit creates absorb pulse")
	check(_bus._pending_events.size() == absorb_queue_before and _bus._frame_events == absorb_budget_before, "actual positive absorb feedback does not enqueue gameplay or spend event budget")
	var queue_before: int = _bus._pending_events.size()
	var budget_before: int = _bus._frame_events
	_bus.present_holy_absorb(player.global_position, 0)
	check(_visible_count(_view._bursts) == before + 1 and _bus._pending_events.size() == queue_before and _bus._frame_events == budget_before, "zero absorb notification creates no pulse or queued gameplay event")
	check(_grant(5000), "actual shield cap overflow action succeeds")
	_bus.process_pending_events()
	check(store._sources.has(DEVOTION_SOURCE), "actual canonical shield overflow creates exact devotion timed source")
	_view._process(0.11)
	check(_view._devotion != null and _view._devotion.visible, "actual positive devotion source displays aura")
	var sources_before: Dictionary = store._sources.duplicate(true)
	var shield_before: int = int(player.get_meta("fire_passive_shield", 0))
	_view._process(0.11)
	check(store._sources == sources_before and int(player.get_meta("fire_passive_shield", 0)) == shield_before, "presentation refresh leaves timed modifiers and shield untouched")
	store.tick_timed_sources(4.1)
	_view._process(0.11)
	check(not store._sources.has(DEVOTION_SOURCE) and not _view._devotion.visible, "actual timed-source expiry hides devotion aura")
	_bus._clock.tick(6.1)
	_view._process(0.11)
	check(not _view._shield.visible, "actual combat-clock shield expiry hides aura")
	check(int(player.get_meta("fire_passive_shield", 0)) == shield_before, "read-only shield expiry refresh does not consume metadata")

func _verify_guardian() -> void:
	manager.clear_skills()
	_view.reset_presentation()
	player.set_meta("fire_passive_shield", 0)
	player.set_meta("fire_passive_shield_expires_at", 0.0)
	check(Fixture.install_runtime_skill(manager, &"holy_summon_shield_guardian"), "install canonical holy guardian skill")
	var context: Dictionary = _context(null, &"holy_summon_shield_guardian")
	context["skill_instance"] = manager.get_skill(&"holy_summon_shield_guardian")
	context["parent"] = player.get_parent()
	_bus.emit_skill_event(&"on_cast", context)
	_bus.process_pending_events()
	await settle(1)
	var summons: Node = player.get_node("SummonManager")
	var guards: Array = summons._active_by_id.get(&"holy_shield_guardian", [])
	check(guards.size() == 1, "canonical cast spawns one real managed shield guardian")
	if guards.is_empty():
		return
	var guard: Node2D = guards[0]
	guard.global_position = player.global_position + Vector2(30, 0)
	guard.set_physics_process(false)
	var guard_effect: Node2D = guard.get("_summon_effect") as Node2D
	check(guard_effect != null and guard_effect.visual_profile == "guardian", "actual managed guardian has correct procedural presentation")
	player.set_meta("holy_guard_ready_at", 0.0)
	var application: RefCounted = Application.create(player, DamagePacket.from_dictionary({"raw_amount":20, "amount":20, "element":"physical"}))
	application.incoming_amount = 20
	var health_before: int = player.current_health
	var guard_queue_before: int = _bus._pending_events.size()
	var guard_budget_before: int = _bus._frame_events
	Absorb.new().apply_with_host(Pipeline, application)
	check(application.absorbed_amount == 12 and player.current_health == health_before, "real guardian consumes eight-point guard before HP application")
	check(guard_effect != null and guard_effect._guard_remaining > 0.0 and guard_effect._guard_light.visible, "actual guardian block lights the actual guardian shield")
	check(_bus._pending_events.size() == guard_queue_before and _bus._frame_events == guard_budget_before, "actual positive guardian feedback does not queue gameplay or spend event budget")
	var before: int = _visible_count(_view._bursts)
	var guard_remaining: float = guard_effect._guard_remaining if guard_effect != null else 0.0
	var second: RefCounted = Application.create(player, application.packet)
	second.incoming_amount = 20
	Absorb.new().apply_with_host(Pipeline, second)
	check(second.absorbed_amount == 20 and _visible_count(_view._bursts) == before and (guard_effect == null or is_equal_approx(guard_effect._guard_remaining, guard_remaining)), "guardian cooldown prevents a second block and false pulse")
	var queue_before: int = _bus._pending_events.size()
	var budget_before: int = _bus._frame_events
	_bus.present_holy_guard(guard, 0)
	check(_visible_count(_view._bursts) == before and _bus._pending_events.size() == queue_before and _bus._frame_events == budget_before and (guard_effect == null or is_equal_approx(guard_effect._guard_remaining, guard_remaining)), "zero guardian notification creates no pulse or gameplay queue entries")

func _verify_pool_limits() -> void:
	manager.clear_skills()
	_view.reset_presentation()
	check(Fixture.install_runtime_skill(manager, &"holy_passive_devotion"), "install holy shield ownership for bounded absorb feedback")
	var enemy: Node2D = _enemy_at(Vector2(330, 50))
	for index: int in range(30):
		_executor.execute_action({"type":"deal_damage", "params":{"amount":12, "damage_type":"holy"}}, _context(enemy, &"holy_cast_holy_ray"))
	check(enemy.current_health < 700 and _view._hits.size() == 24 and _visible_count(_view._hits) == 24, "thirty actual ray hits saturate at twenty-four impact nodes without suppressing damage")
	for index: int in range(8):
		player.set_meta("fire_passive_shield", 0)
		_grant(1)
		var application: RefCounted = Application.create(player, DamagePacket.from_dictionary({"raw_amount":1, "amount":1, "element":"physical"}))
		application.incoming_amount = 1
		Absorb.new().apply_with_host(Pipeline, application)
	check(_view._bursts.size() == 12 and _visible_count(_view._bursts) == 12 and int(player.get_meta("fire_passive_shield", 0)) == 0, "sixteen real grant and absorb notifications saturate at twelve bursts while shields still resolve")
	var count: int = _view.get_child_count()
	var hit: Node2D = _view._hits[0]
	var material: ShaderMaterial = hit._material
	_view.reset_presentation()
	_executor.execute_action({"type":"deal_damage", "params":{"amount":12, "damage_type":"holy"}}, _context(enemy, &"holy_cast_holy_ray"))
	check(_view._hits[0] == hit and hit._material == material and hit.visible and _view.get_child_count() == count, "confirmed impact reuses hidden pooled node and material")

func _verify_actual_status_priority() -> void:
	# No divine-punishment/core listener is installed: the two actual statuses
	# independently exercise overlay selection, pauses and authoritative expiry.
	manager.clear_skills()
	var enemy: Node2D = _enemy_at(Vector2(350, -70))
	check(enemy.apply_status(&"judgment", {"duration":6.0, "stacks":2}), "actual enemy receives two judgment stacks")
	check(enemy.apply_status(&"weaken", {"duration":1.5, "stacks":1}), "actual enemy receives short weakening status")
	var statuses: Node = enemy.get_node("StatusEffectManager")
	statuses._flush_status_visual_refresh()
	var surface: Node2D = statuses._status_visual_overlay.get_node_or_null("ProceduralStatus") if statuses._status_visual_overlay != null else null
	check(surface != null and surface.visible and surface.profile == 3, "actual weakening priority displays weaken profile above concurrent judgment")
	if surface == null:
		return
	statuses.pause_status(&"judgment", &"holy_priority_pause")
	statuses.pause_status(&"weaken", &"holy_priority_pause")
	statuses._flush_status_visual_refresh()
	statuses.update_status_effects(1.6)
	surface._process(1.6)
	statuses._flush_status_visual_refresh()
	check(enemy.get_status_stack(&"judgment") == 2 and enemy.has_status(&"weaken") and is_equal_approx(float(statuses.export_status(&"judgment").get("duration_remaining", 0.0)), 6.0) and is_equal_approx(float(statuses.export_status(&"weaken").get("duration_remaining", 0.0)), 1.5), "actual paused status manager preserves both full durations and judgment stacks")
	check(surface.visible and surface.profile == 3, "paused weakening overlay cannot expire independently")
	statuses.resume_status(&"judgment", &"holy_priority_pause")
	statuses.resume_status(&"weaken", &"holy_priority_pause")
	statuses.update_status_effects(1.6)
	statuses._flush_status_visual_refresh()
	var resumed_surface: Node2D = statuses._status_visual_overlay.get_node_or_null("ProceduralStatus") if statuses._status_visual_overlay != null else null
	check(not enemy.has_status(&"weaken") and enemy.get_status_stack(&"judgment") == 2 and is_equal_approx(float(statuses.export_status(&"judgment").get("duration_remaining", 0.0)), 4.4), "actual resumed expiry removes weakening and retains two judgment stacks for 4.4 seconds")
	check(resumed_surface != null and resumed_surface.visible and resumed_surface.profile == 0 and resumed_surface.status_stacks == 2, "authoritative weakening expiry restores two-stack judgment presentation")

func _verify_pause_and_cleanup() -> void:
	_view.reset_presentation()
	var enemy: Node2D = _enemy_at(Vector2(130, -50))
	_executor.execute_action({"type":"deal_damage", "params":{"amount":12, "damage_type":"holy"}}, _context(enemy, &"holy_cast_holy_ray"))
	var hit: Node2D
	for item: Node2D in _view._hits:
		if item.visible:
			hit = item
			break
	check(hit != null, "pause fixture uses an actual confirmed holy hit")
	if hit != null:
		_view.process_mode = Node.PROCESS_MODE_PAUSABLE
		var age: float = hit.effect_age
		paused = true
		await settle(3)
		check(hit.visible and is_equal_approx(hit.effect_age, age), "real scene pause freezes active feedback clock")
		paused = false
		_view.process_mode = Node.PROCESS_MODE_INHERIT
	check(_view._hits.size() <= 24 and _view._bursts.size() <= 12, "runtime pools retain bounded impact and burst capacity")
	manager.clear_skills()
	_view._process(0.11)
	check((_view._shield == null or not _view._shield.visible) and (_view._devotion == null or not _view._devotion.visible), "skill removal hides actual shield and devotion auras")
	check(_visible_count(_view._hits) == 0 and _visible_count(_view._bursts) == 0, "clear_skills resets transient holy feedback")
	_bus.reset_run_state()
	check(_visible_count(_view._hits) == 0 and _visible_count(_view._bursts) == 0, "run reset leaves no holy feedback active")

func _context(target: Node2D, id: StringName) -> Dictionary:
	return {"caster":player, "owner":player, "target":target, "event_bus":_bus, "skill_manager":manager, "skill_id":id, "origin_skill_id":id, "combat_seconds":_bus.combat_seconds()}
