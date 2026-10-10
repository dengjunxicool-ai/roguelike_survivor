## 地图与波次合成唯一遭遇；预览只读取实际精英事件，输入始终不变。
extends RefCounted
static func resolve_wave(map_data: Dictionary,wave_data: Dictionary) -> Dictionary:
	var wave := wave_data.duplicate(true)
	var encounter: Dictionary = map_data.get("encounter",{})
	var overrides: Dictionary = encounter.get("group_weight_overrides",{})
	var total := 0.0
	for group: Dictionary in wave.get("groups",[]):
		group["weight"]=float(group.get("weight",0))*float(overrides.get(String(group.get("id","")),1.0))
		total+=float(group.weight)
	if total>0:
		for group: Dictionary in wave.get("groups",[]): group["weight"]=float(group.weight)*100.0/total
	for event: Dictionary in encounter.get("elite_events",[]):
		if String(event.get("wave_id",""))==String(wave.get("id","")):
			var events: Array = []
			for existing: Dictionary in wave.get("events",[]):
				if String(existing.get("type",""))!="spawn_elite": events.append(existing)
			var resolved := event.duplicate(true)
			resolved.erase("wave_id")
			resolved["type"]="spawn_elite"
			resolved["mandatory"]=true
			events.append(resolved)
			wave["events"]=events
	return wave
static func get_elite_preview_ids(map_data: Dictionary) -> Array[StringName]:
	var ids: Array[StringName] = []
	for event: Dictionary in map_data.get("encounter",{}).get("elite_events",[]): ids.append(StringName(event.enemy_id))
	return ids
