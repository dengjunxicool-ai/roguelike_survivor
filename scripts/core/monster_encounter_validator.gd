## 发布前拒绝非法波次职责、阶段预算和地图遭遇；只读取文档，不依赖 GameData。
extends RefCounted
static func validate(documents: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var waves: Array = documents.get("res://data/waves/waves.json",{}).get("waves",[])
	var enemies := {}
	var group_ids := {}
	var wave_ids := {}
	for enemy: Variant in documents.get("res://data/enemies/enemies.json",{}).get("monsters",[]):
		if enemy is Dictionary: enemies[String(enemy.get("id",""))]=enemy
	for wave: Variant in waves:
		if not wave is Dictionary: continue
		wave_ids[String(wave.get("id",""))]=wave
		var where := "waves."+String(wave.get("id",""))
		var stages: Variant = wave.get("spawn_stages",[])
		if not stages is Array or stages.size()!=3:
			errors.append(where+".spawn_stages: expected three stages")
		else:
			var ratio := 0.0
			var previous_end := 0.0
			for stage: Variant in stages:
				if not stage is Dictionary:
					errors.append(where+".spawn_stages: expected object")
					continue
				var start: Variant = stage.get("start_ratio")
				var end: Variant = stage.get("end_ratio")
				var budget: Variant = stage.get("budget_ratio")
				if not (start is float or start is int) or not (end is float or end is int) or not (budget is float or budget is int):
					errors.append(where+".spawn_stages: required numeric ratios")
					continue
				if not is_finite(start) or not is_finite(end) or not is_finite(budget) or not is_equal_approx(start,previous_end) or end<=start or end>1 or budget<=0: errors.append(where+".spawn_stages: invalid boundaries or budget")
				previous_end=end
				ratio+=budget
			if not is_equal_approx(ratio,1.0) or not is_equal_approx(previous_end,1.0): errors.append(where+".spawn_stages: ratios must cover and sum to one")
		var groups: Variant = wave.get("groups",[])
		if not groups is Array or groups.is_empty():
			errors.append(where+".groups: nonempty groups required")
			continue
		for group: Variant in groups:
			if not group is Dictionary:
				errors.append(where+".groups: expected object member")
				continue
			group_ids[String(group.get("id",""))]=true
			if not String(group.get("role","")) in ["filler","pursuit","ranged","support","charge"]: errors.append(where+".groups.role: invalid role")
			var weight: Variant = group.get("weight")
			if not (weight is float or weight is int) or not is_finite(weight) or weight<=0: errors.append(where+".groups.weight: positive weight required")
	var treasures: Variant = documents.get("res://data/waves/waves.json",{}).get("rewards",{}).get("treasure_events",[])
	if not treasures is Array:
		errors.append("rewards.treasure_events: expected array")
	else:
		var treasure_waves := {}
		for event: Variant in treasures:
			if not event is Dictionary:
				errors.append("rewards.treasure_events: expected object")
				continue
			var wave_id := String(event.get("wave_id",""))
			var enemy_id := String(event.get("enemy_id",""))
			var chance: Variant = event.get("chance")
			var lifetime: Variant = event.get("lifetime")
			var limit: Variant = event.get("max_per_run")
			var time: Variant = event.get("wave_time")
			if event.get("type")!="spawn_treasure" or not wave_ids.has(wave_id) or treasure_waves.has(wave_id) or not enemies.has(enemy_id): errors.append("rewards.treasure_events: invalid type, wave or enemy ID")
			treasure_waves[wave_id]=true
			if not (chance is float or chance is int) or not is_finite(chance) or chance<0 or chance>1: errors.append("rewards.treasure_events.chance: expected 0..1")
			if not (lifetime is float or lifetime is int) or not is_finite(lifetime) or lifetime<=0: errors.append("rewards.treasure_events.lifetime: positive value required")
			if not (limit is float or limit is int) or not is_finite(limit) or limit!=floor(limit) or limit<1 or limit>2: errors.append("rewards.treasure_events.max_per_run: expected 1..2")
			if not (time is float or time is int) or not is_finite(time) or time<0 or (wave_ids.has(wave_id) and time>float(wave_ids[wave_id].get("duration_seconds",0))): errors.append("rewards.treasure_events.wave_time: outside wave")
	for map: Variant in documents.get("res://data/maps/maps.json",{}).get("maps",[]):
		if not map is Dictionary: continue
		var encounter: Variant = map.get("encounter",{})
		if not encounter is Dictionary: continue
		var where := "maps."+String(map.get("id",""))+".encounter"
		if not String(encounter.get("spawn_pattern","")) in ["uniform","alternating_sides"]: errors.append(where+".spawn_pattern: invalid pattern")
		var overrides: Variant = encounter.get("group_weight_overrides",{})
		if not overrides is Dictionary:
			errors.append(where+".group_weight_overrides: expected object")
		else:
			for key: Variant in overrides:
				var value: Variant = overrides[key]
				if not group_ids.has(key) or not (value is float or value is int) or not is_finite(value) or value<=0: errors.append(where+".group_weight_overrides: invalid group or multiplier "+str(key))
		var events: Variant = encounter.get("elite_events",[])
		if not events is Array:
			errors.append(where+".elite_events: expected array")
			continue
		var seen := {}
		for event: Variant in events:
			if not event is Dictionary:
				errors.append(where+".elite_events: expected object member")
				continue
			var wave_id := String(event.get("wave_id",""))
			var enemy_id := String(event.get("enemy_id",""))
			if not wave_ids.has(wave_id) or seen.has(wave_id): errors.append(where+".elite_events.wave_id: invalid or duplicate wave")
			seen[wave_id]=true
			if not enemies.has(enemy_id) or enemies[enemy_id].get("enemy_rank")!="elite": errors.append(where+".elite_events.enemy_id: expected registered elite")
			var time: Variant = event.get("wave_time")
			if not (time is float or time is int) or not is_finite(time) or time<0 or (wave_ids.has(wave_id) and time>float(wave_ids[wave_id].get("duration_seconds",0))): errors.append(where+".elite_events.wave_time: outside wave")
	return errors
