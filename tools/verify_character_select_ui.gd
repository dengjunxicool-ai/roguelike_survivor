extends SceneTree

const CharacterLoadoutControllerScript: Script = preload("res://scripts/ui/screens/character_loadout_controller.gd")

var _failed: bool = false


func _init() -> void:
	var controller: RefCounted = CharacterLoadoutControllerScript.new()
	var screen: Control = controller.call("build") as Control
	root.add_child(screen)
	screen.visible = true
	controller.call("refresh", &"mage")

	_assert(screen.find_child("CharacterCardList", true, false) != null, "CharacterCardList exists")
	_assert(screen.find_child("CharacterPortraitTexture", true, false) != null, "CharacterPortraitTexture exists")
	_assert(screen.find_child("CharacterRoleLabel", true, false) != null, "CharacterRoleLabel exists")
	_assert(screen.find_child("CharacterStatsList", true, false) != null, "CharacterStatsList exists")
	_assert(screen.find_child("CharacterTraitLabel", true, false) != null, "CharacterTraitLabel exists")
	_assert(screen.find_child("CharacterStartingSkillLabel", true, false) != null, "CharacterStartingSkillLabel exists")
	_assert(screen.find_child("CharacterConfirmButton", true, false) != null, "CharacterConfirmButton exists")
	_assert(screen.find_child("CharacterWeaponList", true, false) == null, "old weapon list removed")

	var text_dump: String = _collect_text(screen)
	_assert(text_dump.contains("选择角色"), "screen title is readable")
	_assert(text_dump.contains("初始技能"), "starting skill text is shown")
	_assert(text_dump.contains("角色特质"), "trait text is shown")
	_assert(not text_dump.contains("武器"), "legacy weapon wording is hidden from character select")

	if _failed:
		push_error("verify_character_select_ui: FAIL")
		quit(1)
	else:
		print("verify_character_select_ui: PASS")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failed = true
		push_error("FAIL: %s" % message)


func _collect_text(node: Node) -> String:
	var parts: Array[String] = []
	var label: Label = node as Label
	if label != null:
		parts.append(label.text)
	var button: Button = node as Button
	if button != null:
		parts.append(button.text)
	for child: Node in node.get_children():
		parts.append(_collect_text(child))
	return "\n".join(parts)
