extends RefCounted
class_name UICommand


var type: StringName = &""
var payload: Dictionary = {}


static func create(command_type: StringName, command_payload: Dictionary = {}) -> Dictionary:
	var result: Dictionary = command_payload.duplicate(true)
	result["type"] = command_type
	return result


static func apply_choice_option(option: Dictionary) -> Dictionary:
	return create(&"apply_choice_option", {"option": option.duplicate(true)})


static func purchase_meta_upgrade(upgrade_id: StringName) -> Dictionary:
	return create(&"purchase_meta_upgrade", {"upgrade_id": upgrade_id})


static func purchase_character(character_id: StringName) -> Dictionary:
	return create(&"purchase_character", {"character_id": character_id})


static func add_soul_stones(amount: int) -> Dictionary:
	return create(&"add_soul_stones", {"amount": amount})


func to_dictionary() -> Dictionary:
	var result: Dictionary = payload.duplicate(true)
	result["type"] = type
	return result
