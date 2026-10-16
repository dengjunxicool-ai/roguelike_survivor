extends "res://tools/verify/qa_app_fixture.gd"
const Builder = preload("res://scripts/upgrades/skill_learn_option_builder.gd")
const Repo = preload("res://scripts/upgrades/skill_learn_definition_repository.gd")
func key(code: int, shift: bool = false) -> void:
 var e := InputEventKey.new()
 e.keycode=code
 e.physical_keycode=code
 e.shift_pressed=shift
 e.pressed=true
 Input.parse_input_event(e)
 await settle(2)
 e=e.duplicate()
 e.pressed=false
 Input.parse_input_event(e)
 await settle(2)
func setup_replacement_choice() -> Button:
 player.level=12
 for id: StringName in [&"fire_cast_meteor_rain",&"fire_cast_lava_rift",&"fire_cast_scorching_vortex",&"fire_summon_crimson_dragon",&"fire_summon_ember_fox_pack"]: check(manager.add_skill(id),"fills ordinary slot " + String(id))
 var option: Dictionary=Builder.build_option_data(GameData.get_skill(&"holy_summon_shield_guardian"),Repo.resolve_upgrade(&"learn_skill_holy_summon_shield_guardian"),"epic")
 var choice: RefCounted=ui._run_choice_modal_controller
 choice.add_pending_level(2)
 ui.transition_to("LEVEL_UP_MODAL")
 var candidates: Array[Dictionary]=[option]
 choice._refresh_choice_card_modal(ui._level_up_options,candidates,"RUNNING",true)
 await settle(12)
 return choice._choice_card_buttons[0]
func run() -> void:
 await setup_run()
 root.size=Vector2i(800,600)
 var card: Button=await setup_replacement_choice()
 var choice: RefCounted=ui._run_choice_modal_controller
 card.grab_focus()
 await key(KEY_ENTER)
 var view: CanvasLayer=choice._replacement_view
 check(is_instance_valid(view) and paused,"keyboard opens real replacement")
 await click(buttons(view)[-1])
 check(not is_instance_valid(choice._replacement_view) and root.gui_get_focus_owner()==card,"mouse cancel restores original keyboard card")
 check(choice.pending_level_up_count==1 and not player.get_meta("ordinary_replacement_used",false),"mouse cancel preserves choice and replacement opportunity")
 await click(card)
 view=choice._replacement_view
 check(is_instance_valid(view) and paused,"mouse reopens replacement")
 for action: Array in [[KEY_DOWN,false],[KEY_UP,false],[KEY_TAB,true],[KEY_TAB,false]]:
  await key(action[0],action[1])
  var focus: Control=root.gui_get_focus_owner()
  check(focus!=null and view.is_ancestor_of(focus),"mixed mouse and keyboard navigation stays inside replacement")
 await click(buttons(view)[-1])
 check(not is_instance_valid(choice._replacement_view) and choice.pending_level_up_count==1,"second mixed-input cancel preserves transaction")
 await click(card)
 check(is_instance_valid(choice._replacement_view),"mouse reopens for keyboard confirmation")
 await key(KEY_ENTER)
 check(manager.has_skill(&"holy_summon_shield_guardian") and ui.current_state=="RUNNING" and not paused,"keyboard confirms after mouse-opened replacement")
 check(choice.pending_level_up_count==0 and player.get_meta("ordinary_replacement_used",false),"mixed-input commit consumes exactly one opportunity")
 ui.transition_to("TITLE")
 ui.transition_to("CHARACTER_SELECT")
 ui._on_loadout_confirmed(&"mage")
 check(await ui._start_run(&"lava_temple"),"new real run resets replacement lifecycle")
 await create_timer(0.3,true).timeout
 player=get_first_node_in_group(&"player")
 manager=player.get_node("SkillManager")
 ui._run_scene_coordinator.get_run_scene_parent(self).process_mode=Node.PROCESS_MODE_DISABLED
 card=await setup_replacement_choice()
 card.grab_focus()
 choice._select_upgrade_option(card.get_meta("choice_option"),"RUNNING",true)
 ui.transition_to("TITLE")
 await settle(12)
 check(not is_instance_valid(choice._replacement_view),"immediate exit closes replacement before deferred focus settles")
 var focus: Control=root.gui_get_focus_owner()
 check(focus==null or ui._screen_registry.get_screen("TITLE").is_ancestor_of(focus),"rapid close never leaves focus in hidden replacement")
 ui.transition_to("CHARACTER_SELECT")
 ui._on_loadout_confirmed(&"mage")
 check(await ui._start_run(&"abandoned_dungeon"),"run starts after rapid close")
 await create_timer(0.3,true).timeout
 player=get_first_node_in_group(&"player")
 check(not player.get_meta("ordinary_replacement_used",false) and choice.pending_level_up_count==0,"new run has no stale replacement consumption or pending choices")
 await finish()
