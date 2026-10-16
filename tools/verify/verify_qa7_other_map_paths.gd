extends "res://tools/verify/qa_app_fixture.gd"
func key(code: int) -> void:
 var event := InputEventKey.new()
 event.keycode = code
 event.physical_keycode = code
 event.pressed = true
 Input.parse_input_event(event)
 await settle(2)
 event = event.duplicate()
 event.pressed = false
 Input.parse_input_event(event)
 await settle(2)
func run() -> void:
 await setup_run()
 for id: StringName in [&"abandoned_dungeon", &"toxic_fog_graveyard", &"lava_temple"]: SaveManager.mark_map_cleared(id)
 for map_id: StringName in [&"toxic_fog_graveyard", &"lava_temple", &"abyss_corridor"]:
  ui.transition_to("TITLE")
  await settle(3)
  check(get_nodes_in_group(&"map_hazard").is_empty(), "leaving prior run removes hazards before " + String(map_id))
  ui.transition_to("CHARACTER_SELECT")
  ui._on_loadout_confirmed(&"ranger")
  await settle(8)
  var screen: Node = ui._screen_registry.get_screen("MAP_SELECT")
  await click(screen.find_child("MapCard_" + String(map_id),true,false))
  check(ui._map_select_controller.selected_map_id == map_id, "real mouse selects " + String(map_id))
  await click(ui._map_select_controller._start_button)
  await create_timer(0.4,true).timeout
  check(ui.current_state == "RUNNING" and not paused, "real map starts " + String(map_id))
  player = get_first_node_in_group(&"player")
  var run_parent: Node = ui._run_scene_coordinator.get_run_scene_parent(self)
  var variable: Node = ui._run_scene_coordinator._map_variable_runtime
  check(variable._map_id == map_id and ui._selected_map_id == map_id, "map runtime matches actual selection " + String(map_id))
  if map_id != &"abyss_corridor":
   variable._hazard_timer = 0.0
   await physics_frame
   await physics_frame
   check(not get_nodes_in_group(&"map_hazard").is_empty(), "real hazard timer generates map hazard " + String(map_id))
  await key(KEY_ESCAPE)
  check(ui.current_state == "PAUSE_MENU" and paused, "Escape pauses " + String(map_id))
  var timer_before: float = variable._hazard_timer
  var hp_before: int = player.current_health
  var hazards_before: int = get_nodes_in_group(&"map_hazard").size()
  await create_timer(0.2,true).timeout
  check(variable._hazard_timer == timer_before and player.current_health == hp_before and get_nodes_in_group(&"map_hazard").size() == hazards_before, "pause freezes map hazards and health " + String(map_id))
  await key(KEY_ESCAPE)
  check(ui.current_state == "RUNNING" and not paused, "Escape resumes " + String(map_id))
  ui.transition_to("RESULT_DEFEAT")
  await settle(8)
  check(ui._frozen_result_state.selected_map_id == map_id and ui._frozen_result_state.selected_character_id == &"ranger", "result records correct map/character " + String(map_id))
 ui.transition_to("TITLE")
 await settle(4)
 check(get_nodes_in_group(&"map_hazard").is_empty(), "final exit removes all transient map hazards")
 await finish()
