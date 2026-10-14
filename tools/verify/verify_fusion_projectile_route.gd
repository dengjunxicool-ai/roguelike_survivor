## Catches a retargeted fusion projectile being spawned at its destination instead of the original hit.
extends "res://tools/verify/verify_fusion_semantics_v2.gd"

func run() -> void:
	await process_frame
	setup()
	nearby.append(make_enemy(Vector2(130, 0)))
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tools/verify/fusion_semantic_cases.json"))
	var row: Dictionary = {}
	for candidate: Dictionary in rows:
		if candidate.skill_id == "fusion_curse_frost_cold_scythe_soul_chase":
			row = candidate
	var context: Dictionary = fixture(row, "positive")
	install(StringName(row.skill_id))
	bus.emit_skill_event(&"post_damage_hit", context)
	var emitted: Array[Node2D] = []
	for node: Node in root.get_children():
		if node.get_script() == Projectile and String(node.damage_packet.get("origin_skill_id", "")) == row.skill_id:
			emitted.append(node)
	expect(emitted.size() == 1, "cold-scythe fusion creates its real follow-up projectile")
	if emitted.size() == 1:
		var projectile: Node2D = emitted[0]
		var heading: Vector2 = projectile.get("direction")
		expect(heading.dot(Vector2.RIGHT) > 0.999, "follow-up flies from original hit toward the separate cursed target")
		expect(projectile.global_position.x >= 30.0 and projectile.global_position.x < 130.0, "follow-up starts beside the original hit rather than at the selected target")
		expect(String(projectile.damage_packet.get("origin_skill_id", "")) == "fusion_curse_frost_cold_scythe_soul_chase" and not bool(projectile.damage_packet.get("can_generate_secondary_proc", true)), "follow-up retains fusion origin and cannot recursively generate secondary procs")
	clean()
	await process_frame
	finish()
