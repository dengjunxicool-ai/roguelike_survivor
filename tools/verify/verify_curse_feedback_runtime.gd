## 真实app、Enemy与动作执行器验证诅咒展示，展示刷新不得消耗战斗资源。
extends "res://tools/verify/qa_app_fixture.gd"

const Fixture = preload("res://tools/verify/skill_rebalance_fixture.gd")
const EnemyScene = preload("res://scenes/enemies/enemy.tscn")
const Executor = preload("res://scripts/skills/skill_action_executor.gd")
const HARVEST_SOURCE: String = "skill:curse_power_soul_harvest:next_cast"
var _bus: Node
var _view: Node
var _executor: RefCounted

func run() -> void:
	await setup_run()
	_bus = player.get_node("SkillEventBus")
	_view = _bus.get_node_or_null("CurseCombatPresentation")
	check(_view != null, "production curse presentation attached to real app")
	if _view == null:
		await finish()
		return
	_executor = Executor.new()
	var enemy: Node2D = _enemy_at(Vector2(100, 0))
	var context: Dictionary = _context(enemy, &"curse_attack_cursing")
	_executor.execute_action({"type":"deal_damage", "params":{"amount":0, "damage_type":"curse"}}, context)
	check(enemy.current_health == 1000 and _view._hits.is_empty(), "zero curse hit changes no HP and creates no impact")
	_executor.execute_action({"type":"deal_damage", "params":{"amount":12, "damage_type":"curse"}}, context)
	check(enemy.current_health < 1000 and not _view._hits.is_empty(), "confirmed curse action changes real HP and creates impact")
	var statuses: Node = enemy.get_node("StatusEffectManager")
	enemy.apply_status(&"cursed", {"duration":3.0, "stacks":2, "power":24.0})
	var health_before: int = enemy.current_health
	statuses.resolve_cursed(&"forced")
	check(enemy.current_health < health_before, "real cursed settlement produces positive HP loss")
	check(_view._bursts.size() == 1 and _view._bursts[0].visible, "actual cursed settlement creates one burst")
	if not _view._bursts.is_empty():
		check(int(_view._bursts[0]._material.get_shader_parameter("profile")) == 1, "settlement uses confirmed resolution profile")
	var bursts_before: int = _view._bursts.size()
	enemy.apply_status(&"cursed", {"duration":3.0, "stacks":1, "power":0.0})
	health_before = enemy.current_health
	statuses.resolve_cursed(&"forced")
	check(enemy.current_health == health_before and _view._bursts.size() == bursts_before, "zero-power actual settlement creates no false burst")
	_verify_healing()
	_verify_chains(enemy)
	_verify_status_presentation_regressions()
	_verify_contract(enemy)
	await _verify_crow_soul_capture()
	await _verify_resources()
	manager.clear_skills()
	_view._process(0.11)
	check((_view._harvest == null or not _view._harvest.visible) and (_view._debt == null or not _view._debt.visible), "clear_skills hides harvest and coffin auras")
	check(player.get_node("ModifierStore").get_cast_charge_snapshot().sources.is_empty(), "clear_skills removes actual next-cast resource")
	var hidden: bool = true
	for effect: Node2D in _view._hits + _view._bursts + _view._links + _view._contracts:
		hidden = hidden and not effect.visible
	check(hidden and _view._contract_targets.is_empty(), "clear_skills resets all curse feedback and weak contract references")
	await finish()

func _enemy_at(offset: Vector2) -> Node2D:
	var enemy: Node2D = EnemyScene.instantiate()
	enemy.enemy_id = &"skeleton"
	player.get_parent().add_child(enemy)
	enemy.global_position = player.global_position + offset
	enemy.max_health = 1000
	enemy.current_health = 1000
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	return enemy

func _context(target: Node2D, id: StringName) -> Dictionary:
	return {"caster":player, "owner":player, "target":target, "event_bus":_bus, "skill_manager":manager, "skill_id":id, "origin_skill_id":id, "combat_seconds":_bus.combat_seconds()}

func _verify_status_presentation_regressions() -> void:
	# A skill-origin curse settlement goes through the canonical typed DOT packet.
	# Existing hit cooldowns cannot mask this regression: use a fresh real Enemy.
	# Full health prevents a separately valid vampiric restoration burst.
	player.current_health = player.max_health
	var enemy: Node2D = _enemy_at(Vector2(250, -90))
	var observed: Array[Dictionary] = []
	_bus.subscribe(&"post_damage_hit", func(context: Dictionary) -> void:
		if context.get("target") == enemy:
			observed.append(context.duplicate(true)))
	for hit: Node2D in _view._hits:
		hit.deactivate()
	var bursts_before: int = _view._bursts.size()
	var health_before: int = enemy.current_health
	enemy.apply_status(&"cursed", {"duration":3.0, "stacks":2, "power":24.0, "source_skill_id":&"curse_cast_black_serpent_hunt", "source":player, "attacker":player})
	var statuses: Node = enemy.get_node("StatusEffectManager")
	statuses.resolve_cursed(&"forced")
	check(enemy.current_health < health_before, "skill-origin real curse settlement applies positive HP loss")
	check(observed.size() == 1 and String(observed[0].get("damage_origin", "")) == "status_dot" and String(observed[0].get("source_skill_id", "")) == "curse_cast_black_serpent_hunt", "real settlement emits canonical status_dot with actual curse skill source")
	var visible_hits: int = 0
	for hit: Node2D in _view._hits:
		if hit.visible:
			visible_hits += 1
	check(visible_hits == 0, "status_dot settlement never creates a second visible hit")
	check(_view._bursts.size() == bursts_before + 1, "status_dot settlement creates exactly one resolution burst")

	# Keep the actual manager and procedural child under the disabled run world;
	# manual clocks prove presentation cannot independently expire live status.
	var paused_enemy: Node2D = _enemy_at(Vector2(260, 95))
	paused_enemy.apply_status(&"cursed", {"duration":3.0, "stacks":1, "power":24.0})
	var paused_manager: Node = paused_enemy.get_node("StatusEffectManager")
	paused_manager._flush_status_visual_refresh()
	var surface: Node2D = paused_manager._status_visual_overlay.get_node_or_null("ProceduralStatus") if paused_manager._status_visual_overlay != null else null
	check(surface != null and surface.visible, "real paused-status fixture has procedural curse overlay")
	if surface == null:
		return
	paused_manager.pause_status(&"cursed", &"curse_freeze")
	paused_manager._flush_status_visual_refresh()
	surface._process(4.0)
	paused_manager.update_status_effects(4.0)
	paused_manager._flush_status_visual_refresh()
	check(paused_enemy.has_status(&"cursed") and surface.visible, "four-second curse freeze preserves real status and its visible overlay")
	check(is_equal_approx(float(paused_manager.export_status(&"cursed").get("duration_remaining", -1.0)), 3.0), "paused gameplay manager retains full three-second duration")
	paused_manager.resume_status(&"cursed", &"curse_freeze")
	paused_manager._flush_status_visual_refresh()
	check(is_equal_approx(float(paused_manager.export_status(&"cursed").get("duration_remaining", -1.0)), 3.0), "resume preserves actual remaining three seconds")
	surface._process(3.1)
	check(paused_enemy.has_status(&"cursed") and surface.visible, "overlay cannot expire resumed curse before authoritative manager update")
	paused_manager.update_status_effects(3.1)
	paused_manager._flush_status_visual_refresh()
	check(not paused_enemy.has_status(&"cursed") and not surface.visible and not paused_manager._status_visual_overlay.visible, "authoritative resumed expiry removes curse and hides overlay")

func _verify_healing() -> void:
	check(Fixture.install_runtime_skill(manager, &"curse_passive_vampiric_ritual"), "install real vampiric ritual listener")
	var context: Dictionary = _context(player, &"curse_cast_black_serpent_hunt")
	context["skill_instance"] = manager.get_skill(&"curse_passive_vampiric_ritual")
	player.current_health = player.max_health
	var before: int = _view._bursts.size()
	_executor.execute_action({"type":"heal_owner", "params":{"amount":12}}, context)
	check(player.current_health == player.max_health and _view._bursts.size() == before, "full-health vampiric heal creates no restoration feedback")
	player.current_health = player.max_health - 20
	var health_before: int = player.current_health
	_executor.execute_action({"type":"heal_owner", "params":{"amount":12}}, context)
	check(player.current_health - health_before == 12, "vampiric listener actually restores twelve HP")
	check(_view._bursts.size() == before + 1, "positive restoration creates feedback even when origin is another skill")
	if _view._bursts.size() > before:
		check(int(_view._bursts[before]._material.get_shader_parameter("profile")) == 2, "actual restored HP uses heal profile")

func _verify_chains(origin: Node2D) -> void:
	var target: Node2D = _enemy_at(Vector2(165, 0))
	var context: Dictionary = _context(origin, &"curse_power_epidemic_spread")
	var before: int = _view._links.size()
	_executor.execute_action({"type":"chain_to_targets", "params":{"radius":80.0, "count":1, "amount":0, "damage_type":"curse"}}, context)
	check(target.current_health == 1000 and _view._links.size() == before, "zero-damage chain creates no decorative false hit")
	_executor.execute_action({"type":"chain_to_targets", "params":{"radius":80.0, "count":1, "actions":[{"type":"apply_status", "params":{"status_id":"cursed", "stacks":1, "duration":3.0}}]}}, context)
	check(target.has_status(&"cursed") and _view._links.size() == before + 1, "actual cursed stack application creates epidemic link")
	if _view._links.size() > before:
		var link: Node2D = _view._links[before]
		check(int(link.get_node("BatchedSouls").material.get_shader_parameter("link_kind")) == 1, "epidemic chain selects target-flow kind")
		check(link.global_position == origin.global_position and link.get_node("Core").points[-1] == target.global_position - origin.global_position, "epidemic presentation uses exact actual world endpoints")
	context = _context(player, &"curse_dash_soul_chain")
	var health_before: int = origin.current_health
	before = _view._links.size()
	_executor.execute_action({"type":"chain_to_targets", "params":{"radius":125.0, "count":1, "amount":12, "damage_type":"curse"}}, context)
	check(origin.current_health < health_before and _view._links.size() == before + 1, "actual soul-chain damage creates link only after HP loss")
	if _view._links.size() > before:
		check(int(_view._links[before].get_node("BatchedSouls").material.get_shader_parameter("link_kind")) == 0, "soul-chain listener selects caster-flow kind")

func _verify_contract(enemy: Node2D) -> void:
	check(Fixture.install_runtime_skill(manager, &"curse_power_death_pact"), "install real death-pact skill")
	var context: Dictionary = _context(enemy, &"curse_power_death_pact")
	context["skill_instance"] = manager.get_skill(&"curse_power_death_pact")
	_executor.execute_action({"type":"mark_target", "params":{"mark":"death_pact", "duration":5.0}}, context)
	check(bool(enemy.get_meta("death_pact", false)) and _bus._cycles.marks.has(enemy.get_instance_id()), "actual mark action registers real five-second death contract")
	check(_view._contracts.size() == 1 and _view._contracts[0].visible, "actual death-contract registration creates marker")
	if not _view._contracts.is_empty():
		var marker: Node2D = _view._contracts[0]
		enemy.global_position += Vector2(7, 9)
		_view._process(0.01)
		check(marker.global_position == enemy.global_position, "registered contract follows actual target motion")
	_bus._clock.tick(5.1)
	_bus.update_skill_cycles()
	_view._process(0.11)
	check(not bool(enemy.get_meta("death_pact", false)) and not _bus._cycles.marks.has(enemy.get_instance_id()), "actual run clock expires and clears contract metadata")
	check(not _view._contracts[0].visible, "expired gameplay contract clears its marker")
	_executor.execute_action({"type":"mark_target", "params":{"mark":"death_pact", "duration":5.0}}, context)
	_bus.clear_origin(&"curse_power_death_pact")
	_view._process(0.11)
	check(not bool(enemy.get_meta("death_pact", false)) and not _view._contracts[0].visible, "origin clear removes actual contract and presentation")

func _verify_crow_soul_capture() -> void:
	manager.clear_skills()
	check(Fixture.install_runtime_skill(manager, &"curse_summon_soul_crow"), "install canonical soul-crow capture skill")
	var skill: RefCounted = manager.get_skill(&"curse_summon_soul_crow")
	for index: int in range(2):
		await settle(1)
		var context: Dictionary = _context(null, &"curse_summon_soul_crow")
		context.merge({"skill_instance":skill, "scheduled_cast":true, "parent":player.get_parent(), "power":float(player.attack_power)}, true)
		_bus.emit_skill_event(&"on_cast", context)
		_bus.process_pending_events()
	var summons: Node = player.get_node_or_null("SummonManager")
	var crows: Array = summons._active_by_id.get(&"soul_crow", []) if summons != null else []
	check(crows.size() == 2, "two canonical casts create two real managed soul crows")
	if crows.size() != 2:
		return
	for index: int in range(crows.size()):
		var crow: Node2D = crows[index]
		crow.set_physics_process(false)
		crow.global_position = player.global_position + Vector2(70 + index * 55, -60)

	# A real attack and hit can apply curse, but no corpse yet exists to absorb.
	var attack_target: Node2D = _enemy_at(Vector2(85, -70))
	var links_before: int = _visible_link_count()
	var health_before: int = attack_target.current_health
	crows[0]._physics_process(0.05)
	var bolt: Projectile = _find_crow_bolt(root)
	check(crows[0].state == SummonController.STATE_ATTACK and bolt != null, "managed soul crow performs actual projectile attack")
	if bolt != null:
		bolt.set_physics_process(false)
		bolt._on_body_entered(attack_target)
	check(attack_target.current_health < health_before and not attack_target.is_dead(), "actual crow projectile hit damages a living Enemy")
	check(_visible_link_count() == links_before, "ordinary soul-crow attack and living hit create no absorption chain")

	await settle(1)
	_bus.process_pending_events()
	var plain: Node2D = _enemy_at(Vector2(280, -40))
	_executor.execute_action({"type":"deal_damage", "params":{"amount":2000, "damage_type":"curse"}}, _context(plain, &"curse_attack_cursing"))
	_bus.process_pending_events()
	check(plain.current_health <= 0 and not plain.has_status(&"cursed"), "negative capture fixture is real uncursed Enemy death")
	check(_visible_link_count() == links_before, "uncursed actual death creates no soul-crow absorption chain")

	await settle(1)
	_bus.process_pending_events()
	var victim: Node2D = _enemy_at(Vector2(300, 70))
	victim.apply_status(&"cursed", {"duration":5.0, "stacks":1, "power":24.0})
	var corpse_position: Vector2 = victim.global_position
	var living_health_before_capture: int = attack_target.current_health
	var count_before: int = _visible_link_count()
	_executor.execute_action({"type":"deal_damage", "params":{"amount":2000, "damage_type":"curse"}}, _context(victim, &"curse_attack_cursing"))
	_bus.process_pending_events()
	check(victim.current_health <= 0 and victim.is_dead(), "capture fixture is real cursed Enemy death")
	check(_visible_link_count() == count_before + crows.size(), "actual cursed death creates one visible absorption chain per managed soul crow")
	for crow: Node2D in crows:
		var connected: bool = false
		for link: Node2D in _view._links:
			if not link.visible or link.global_position != crow.global_position:
				continue
			var core: Line2D = link.get_node("Core") as Line2D
			var material: ShaderMaterial = link.get_node("BatchedSouls").material as ShaderMaterial
			connected = core.points[-1].is_equal_approx(corpse_position - crow.global_position) and int(material.get_shader_parameter("link_kind")) == 0
			if connected:
				break
		check(connected, "absorption connects actual crow %d to corpse and flows toward crow" % crows.find(crow))
	check(is_equal_approx(float(skill.get_meta("soul_crow_cursed_deaths", 0.0)), 1.0), "capture presentation does not change canonical cursed-death resource count")
	check(attack_target.current_health == living_health_before_capture and not attack_target.is_dead(), "absorption presentation creates no extra attack or damage")

func _visible_link_count() -> int:
	var count: int = 0
	for link: Node2D in _view._links:
		if link.visible:
			count += 1
	return count

func _find_crow_bolt(node: Node) -> Projectile:
	if node is Projectile and node.visible and node.source_id == &"soul_bolt_projectile" and String(node.damage_packet.get("source_skill_id", "")) == "curse_summon_soul_crow":
		return node
	for child: Node in node.get_children():
		var found: Projectile = _find_crow_bolt(child)
		if found != null:
			return found
	return null

func _verify_resources() -> void:
	# Resource fixtures are actual Enemy deaths and the real ModifierStore.
	manager.clear_skills()
	check(Fixture.install_runtime_skill(manager, &"curse_power_soul_harvest"), "install real harvest counter")
	check(Fixture.install_runtime_skill(manager, &"curse_core_grand_coffin"), "install real coffin debt counter")
	var harvest: RefCounted = manager.get_skill(&"curse_power_soul_harvest")
	var core: RefCounted = manager.get_skill(&"curse_core_grand_coffin")
	var store: Node = player.get_node("ModifierStore")
	store.set_cast_charge("skill:another_school:next_cast", 0.5)
	_view._process(0.11)
	check(_view._harvest == null or not _view._harvest.visible, "unrelated next-cast source cannot display harvest readiness")
	store.consume_cast_charges(["skill:another_school:next_cast"])
	for index: int in range(12):
		var enemy: Node2D = _enemy_at(Vector2(320, 140))
		enemy.apply_status(&"cursed", {"duration":5.0, "stacks":1, "power":24.0})
		_executor.execute_action({"type":"deal_damage", "params":{"amount":2000, "damage_type":"curse"}}, _context(enemy, &"curse_attack_cursing"))
		check(enemy.current_health <= 0, "resource fixture %d is a real cursed Enemy death" % (index + 1))
		await settle(1)
		_bus.process_pending_events()
		if index == 0:
			check(is_equal_approx(float(harvest.get_meta("soul_harvest_cursed_kills", 0.0)), 1.0), "actual cursed death increments harvest metadata")
			check(is_equal_approx(float(core.get_meta("grand_coffin_soul_debt", 0.0)), 1.0), "actual cursed death increments coffin debt metadata")
			_view._process(0.11)
			check(_view._harvest != null and _view._harvest.visible and not bool(_view._harvest._material.get_shader_parameter("ready")), "real partial harvest metadata displays charge without readiness")
			check(_view._debt != null and _view._debt.visible, "real coffin debt metadata displays its aura")
			var before: Dictionary = store.get_cast_charge_snapshot().duplicate(true)
			_view._process(0.11)
			check(is_equal_approx(float(harvest.get_meta("soul_harvest_cursed_kills", 0.0)), 1.0) and is_equal_approx(float(core.get_meta("grand_coffin_soul_debt", 0.0)), 1.0) and store.get_cast_charge_snapshot() == before, "presentation refresh cannot mutate resource counters or next-cast charges")
	check(store.get_cast_charge_snapshot().sources.has(HARVEST_SOURCE), "twelve actual cursed deaths create exact harvest next-cast source")
	check(is_equal_approx(float(harvest.get_meta("soul_harvest_cursed_kills", -1.0)), 0.0) and is_equal_approx(float(core.get_meta("grand_coffin_soul_debt", 0.0)), 12.0), "actual counters reset harvest threshold while retaining twelve coffin debt")
	_view._process(0.11)
	check(_view._harvest != null and _view._harvest.visible and bool(_view._harvest._material.get_shader_parameter("ready")), "exact real harvest source displays ready aura")
	var before: Dictionary = store.get_cast_charge_snapshot().duplicate(true)
	for frame: int in range(5):
		_view._process(0.11)
	check(store.get_cast_charge_snapshot() == before, "repeated aura refresh preserves charged cast resource")
	check(Fixture.install_runtime_skill(manager, &"curse_cast_black_serpent_hunt"), "install real cast to consume harvest readiness")
	var context: Dictionary = _context(null, &"curse_cast_black_serpent_hunt")
	context["skill_instance"] = manager.get_skill(&"curse_cast_black_serpent_hunt")
	_bus.emit_skill_event(&"on_cast", context)
	_bus.process_pending_events()
	check(not store.get_cast_charge_snapshot().sources.has(HARVEST_SOURCE), "real cast consumes exact harvest next-cast resource")
	_view._process(0.11)
	check(not _view._harvest.visible, "consumed harvest charge immediately hides ready aura")
	check(_view._debt.visible and is_equal_approx(float(core.get_meta("grand_coffin_soul_debt", 0.0)), 12.0), "cast consumption leaves actual coffin debt intact")
