extends SceneTree


const MapSelectControllerScript: Script = preload("res://scripts/ui/screens/map_select_controller.gd")


func _init() -> void:
	var controller: RefCounted = MapSelectControllerScript.new()
	var screen: Control = controller.call("build") as Control
	root.add_child(screen)
	controller.call("refresh", &"mage")

	_assert(screen != null, "map select screen builds")
	_assert(screen.find_child("MapSoulLabel", true, false) != null, "map select shows soul counter")
	_assert(screen.find_child("MapPreviewTexture", true, false) != null, "map select shows map preview texture")
	_assert(screen.find_child("MapEnemyPreviewList", true, false) != null, "map select shows enemy preview list")
	_assert(screen.find_child("MapLoadoutCharacterLabel", true, false) != null, "map select shows selected character")
	_assert(screen.find_child("MapLoadoutSkillLabel", true, false) != null, "map select shows starting skill")
	_assert(screen.find_child("MapLoadoutThreatLabel", true, false) != null, "map select shows threat level")
	_assert(screen.find_child("MapLoadoutWeaponLabel", true, false) == null, "map select does not show obsolete loadout label")
	_assert(screen.find_child("MapStartButton", true, false) != null, "map select has start button")

	var text: String = _collect_text(screen)
	_assert(text.contains("战斗准备"), "map select title is readable Chinese")
	_assert(text.contains("开始挑战"), "map select start button is readable Chinese")
	_assert(text.contains("废弃地牢"), "map select uses readable map names")
	_assert(not text.contains("武器"), "map select text does not expose obsolete loadout concept")

	print("[verify_map_select_ui] PASS")
	quit(0)


func _collect_text(node: Node) -> String:
	var parts: Array[String] = []
	_collect_text_recursive(node, parts)
	return "\n".join(parts)


func _collect_text_recursive(node: Node, parts: Array[String]) -> void:
	if node is Label:
		parts.append((node as Label).text)
	elif node is Button:
		parts.append((node as Button).text)
	for child: Node in node.get_children():
		_collect_text_recursive(child, parts)


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return
	push_error("FAIL %s" % message)
	quit(1)
