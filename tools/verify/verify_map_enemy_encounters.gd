extends SceneTree
var failed := false
func _init() -> void:
	call_deferred("run")
func expect(ok: bool,message: String) -> void:
	if not ok:
		failed=true
		push_error("[MapEncounters] "+message)
func run() -> void:
	var path := "res://scripts/maps/map_encounter_resolver.gd"
	expect(FileAccess.file_exists(path),"runtime and preview resolver exists")
	if not FileAccess.file_exists(path):
		quit(1)
		return
	var resolver: Script = load(path)
	var expected := {"abandoned_dungeon":["giant_slime","skeleton_captain"],"toxic_fog_graveyard":["giant_slime","toxic_matriarch"],"lava_temple":["skeleton_captain","lava_golem"],"abyss_corridor":["skeleton_captain","skeleton_captain"]}
	for id: String in expected:
		var map: Dictionary = GameData.get_map(id)
		var preview: Array = resolver.call("get_elite_preview_ids",map)
		for index in range(2):
			var base: Dictionary = GameData.get_wave_config().waves[3 if index==0 else 5]
			var original := base.duplicate(true)
			var wave: Dictionary = resolver.call("resolve_wave",map,base)
			expect(wave.events[0].enemy_id==expected[id][index] and String(preview[index])==expected[id][index],id+" preview matches real wave event")
			expect(base==original,"resolver does not mutate content owner")
			expect(GameData.get_enemy(preview[index]).enemy_rank=="elite","preview cannot label normal hunter as elite")
		var weight_sum := 0.0
		for group: Dictionary in resolver.call("resolve_wave",map,GameData.get_wave_config().waves[5]).groups: weight_sum+=group.weight
		expect(is_equal_approx(weight_sum,100.0),id+" effective weights are normalized")
	root.size=Vector2i(1280,720)
	var world := Node2D.new()
	world.process_mode=Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	var player := Node2D.new()
	player.add_to_group("player")
	player.position=Vector2(640,360)
	world.add_child(player)
	var spawner := EnemySpawner.new()
	world.add_child(spawner)
	expect(spawner.has_method("set_map_encounter"),"map context enters real spawner")
	if spawner.has_method("set_map_encounter"):
		spawner.call("set_map_encounter",GameData.get_map("abyss_corridor"))
		var variables := MapVariableRuntime.new()
		world.add_child(variables)
		variables.setup(GameData.get_map("abyss_corridor"))
		spawner.apply_run_modifiers({"enemy_spawn_count_multiplier_add":0.0})
		for index in range(8):
			var base_count := int(GameData.get_wave_config().waves[index].total_count)
			expect(spawner.call("_get_wave_total_count",spawner.call("_get_wave_at_index",index))==roundi(base_count*1.12),"player stat refresh preserves map pressure in wave "+str(index+1))
		spawner.apply_run_modifiers({"enemy_spawn_count_multiplier_add":0.2})
		expect(spawner.call("_get_wave_total_count",spawner.call("_get_wave_at_index",0))==roundi(35*1.32),"map and player population additions compose once")
		spawner.call("set_map_encounter",GameData.get_map("abandoned_dungeon"))
		variables.setup(GameData.get_map("abandoned_dungeon"))
		spawner.apply_run_modifiers({"enemy_spawn_count_multiplier_add":0.0})
		expect(spawner.call("_get_wave_total_count",spawner.call("_get_wave_at_index",0))==35,"changing map clears corridor pressure without retaining a player modifier")
		variables.setup(GameData.get_map("abyss_corridor"))
		root.canvas_transform=Transform2D(Vector2(0.75,0),Vector2(0,0.75),Vector2(90,-20))
		player.position=root.canvas_transform.affine_inverse()*Vector2(640,360)
		spawner.call("_start_wave",0)
		var sides: Array = []
		for index in range(6):
			var actor: Node2D = spawner.call("spawn_enemy",EnemySpawnRequest.create(&"small_slime",{"source_type":"wave"}))
			expect(actor!=null,"side band finds safe legal birth")
			if actor!=null:
				var screen := root.canvas_transform*actor.global_position
				expect(screen.x<320 or screen.x>960,"visible sampling uses left/right quarter bands after canvas transform")
				sides.append(screen.x<320)
		for index in range(1,sides.size()): expect(sides[index]!=sides[index-1],"actual births alternate sides")
	var validator: Script = load("res://scripts/core/content_config_validator.gd")
	var sources: Dictionary = validator.call("load_sources")
	var documents: Dictionary = sources.documents.duplicate(true)
	var shape_cases: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tools/verify/fixtures/monster_encounter_invalid_shapes.json"))
	var encounter_validator: Script=load("res://scripts/core/monster_encounter_validator.gd")
	for shape: Dictionary in shape_cases:
		var changed: Dictionary=sources.documents.duplicate(true)
		var parent: Variant=changed[shape.document]
		for index in range(shape.path.size()-1): parent=parent[shape.path[index]]
		parent[shape.path[-1]]=shape.value
		var errors: Array=encounter_validator.call("validate",changed)
		expect(errors.any(func(message): return String(message).contains(shape.field)),"invalid member shape rejected with field path: "+shape.field)
	documents["res://data/maps/maps.json"].maps[0].encounter.elite_events[0].enemy_id="shadow_hunter"
	expect(not validator.call("validate_documents",documents,sources.schema).is_empty(),"normal enemy cannot be published as map elite")
	documents=sources.documents.duplicate(true)
	documents["res://data/maps/maps.json"].maps[0].encounter.group_weight_overrides={"invented_group":-1}
	expect(not validator.call("validate_documents",documents,sources.schema).is_empty(),"invalid override ID and negative weight are rejected before publication")
	documents=sources.documents.duplicate(true)
	documents["res://data/waves/waves.json"].waves[0].spawn_stages[1].budget_ratio=0.9
	expect(not validator.call("validate_documents",documents,sources.schema).is_empty(),"stage ratios must sum to one")
	documents=sources.documents.duplicate(true)
	documents["res://data/waves/waves.json"].waves[0].groups[0].enemy_ids=["missing_enemy"]
	expect(not validator.call("validate_documents",documents,sources.schema).is_empty(),"nested group enemy IDs rejected before publication")
	documents=sources.documents.duplicate(true)
	documents["res://data/waves/waves.json"].rewards.treasure_events[0].chance=1.2
	documents["res://data/waves/waves.json"].rewards.treasure_events[0].lifetime=-1
	expect(not validator.call("validate_documents",documents,sources.schema).is_empty(),"invalid treasure chance and lifetime rejected before publication")
	world.queue_free()
	await process_frame
	quit(1 if failed else 0)
