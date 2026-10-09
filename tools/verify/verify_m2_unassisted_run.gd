extends "res://tools/verify/verify_mage_full_run_autoplay.gd"
# Real scene, stock health/speed/damage, input-only movement. Test-selected
# primary/dash use production admission; subsequent choices use real offers.
var school: String = "fire"
var started: bool = false
func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--school="): school=arg.trim_prefix("--school=")
	call_deferred("_run")
func _run() -> void:
	if started: return
	started=true
	print("[M2Unassisted] start="+school)
	await super._run()
func _apply_autoplay_survival_assist() -> void:
	_autoplay_assist_enabled=false
	var attacks: Dictionary={"fire":"fire_attack_searing","frost":"frost_attack_frostbite","thunder":"thunder_attack_thundering","curse":"curse_attack_cursing","holy":"holy_attack_judgment"}
	var dashes: Dictionary={"fire":"fire_dash_blazing_run","frost":"frost_dash_ice_shard_assault","thunder":"thunder_dash_ball_lightning","curse":"curse_dash_soul_chain","holy":"holy_dash_heavenly_wings"}
	if not attacks.has(school):
		_fail("unknown school")
		return
	var manager: Node=_player.get_node("SkillManager")
	# Learning a god attack inherits the real character attack runtime.
	# A direct primary setter would omit its projectile/base configuration.
	if String(dashes[school])!="fire_dash_blazing_run":
		manager.call("_remove_active_skill",&"fire_dash_blazing_run")
	if not manager.add_skill(StringName(attacks[school])) or (not manager.has_skill(StringName(dashes[school])) and not manager.add_skill(StringName(dashes[school]))):
		_fail("production admission rejected test starting attack/dash")
		return
	_log("unassisted school=%s hp=%d move_speed=%s" % [school,_player.max_health,_player.move_speed])
func _apply_autopilot_position_step(_direction: Vector2,_delta: float) -> void:
	pass
func _maintain_autoplay_survival_assist() -> void:
	pass
func _apply_boss_damage_assist(_delta: float) -> void:
	pass
func _score_option(option: Dictionary,context: String) -> float:
	var payload: Dictionary=_dict(option.get("payload",{}))
	var id: String=String(payload.get("skill_id",payload.get("learn_skill_id","")))
	var data: Dictionary=GameData.get_skill(id)
	var score: float=super._score_option(option,context)
	if String(data.get("school",""))==school: score+=500
	if String(option.get("id","")).begins_with("skill_level_up:"):
		score+=200
		if String(data.get("skill_type",""))=="attack" and _owned_skill_level(id)<2: score+=1800
	if String(data.get("skill_type","")) in ["cast","summon"] and _owned_skill_level(id)==0 and _owned_direct_active_count()<2: score+=1300
	if _hp_percent()<0.4 and String(option.get("id","")).contains("heal"): score+=5000
	if _has_tag(_array(option.get("tags",[])),["heal","survival"]): score+=200 if _hp_percent()<0.5 else 0
	return score
func _write_report() -> void:
	var file: FileAccess=FileAccess.open(_report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":_status,"school":school,"elapsed":_elapsed,"boss_seen":_boss_seen,"reason":_failure_reason,"seed":_environment.seed,"assists":false,"movement":"Input only; no teleport, no speed change","player":_player_snapshot(),"skills":_skills_snapshot(),"choices":_choices,"observations":_observations},"\t"))
	file.close()
	print("[M2Unassisted] report="+_report_path)
