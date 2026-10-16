extends "res://tools/verify/qa_app_fixture.gd"
func key(code: int) -> void:
 var e := InputEventKey.new()
 e.keycode=code
 e.physical_keycode=code
 e.pressed=true
 Input.parse_input_event(e)
 await settle(2)
 e=e.duplicate()
 e.pressed=false
 Input.parse_input_event(e)
 await settle(2)
func reach(target: Control) -> bool:
 for step: int in 100:
  if root.gui_get_focus_owner()==target: return true
  await key(KEY_TAB)
 return false
func visible_rect(control: Control) -> Rect2:
 var rect: Rect2 = control.get_global_rect().intersection(Rect2(Vector2.ZERO,Vector2(root.size)))
 var ancestor: Node = control.get_parent()
 while ancestor != null:
  if ancestor is ScrollContainer: rect=rect.intersection(ancestor.get_global_rect())
  ancestor=ancestor.get_parent()
 return rect
func run() -> void:
 root.size=Vector2i(720,480)
 create_timer(30.0,true).timeout.connect(func() -> void: push_error("QA7 visibility timeout"); quit(1))
 SaveManager.set_language_id("zh")
 SaveManager.add_soul_stones(10000)
 for id: StringName in [&"abandoned_dungeon",&"toxic_fog_graveyard",&"lava_temple"]: SaveManager.mark_map_cleared(id)
 app=APP.instantiate()
 root.add_child(app)
 await settle(16)
 ui=app.get_node("UIManager")
 if DisplayServer.get_name() != "headless":
  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
  DisplayServer.window_set_size(Vector2i(720,480))
  root.size=Vector2i(720,480)
  await settle(12)
 for state: String in ["META_UPGRADE","CHARACTER_SELECT","MAP_SELECT"]:
  if state=="MAP_SELECT": ui._on_loadout_confirmed(&"mage")
  else:
   ui.transition_to("TITLE")
   ui.transition_to(state)
  await settle(12)
  var list: Node
  if state=="META_UPGRADE": list=ui._meta_upgrade_controller._upgrade_list
  elif state=="CHARACTER_SELECT": list=ui._character_loadout_controller._character_list
  else: list=ui._map_select_controller._map_list
  var target: Button=buttons(list)[-1]
  check(await reach(target), "Tab reaches last list action " + state)
  await settle(8)
  var rect: Rect2=target.get_global_rect()
  var shown: Rect2=visible_rect(target)
  print("VISIBLE ",state," target=",rect," shown=",shown)
  check(shown.size.x>=rect.size.x-1.0 and shown.size.y>=rect.size.y-1.0,"focused last list action is visible in compact window " + state)
  await capture("focused-last-"+state)
  if state != "META_UPGRADE":
   var selected_name: StringName = target.name
   await key(KEY_ENTER)
   await settle(8)
   var restored: Control = root.gui_get_focus_owner()
   check(restored != null and restored.name == selected_name, "selection retains last card focus identity " + state)
   if restored != null:
    var restored_rect: Rect2 = visible_rect(restored)
    check(restored_rect.size.x>=restored.size.x-1.0 and restored_rect.size.y>=restored.size.y-1.0,"rebuilt selected card stays visible " + state)
 await finish()
