extends RefCounted
class_name MetadataKey


static func key(namespace_text: String, suffix: String, invalid_prefix: String = "metadata") -> String:
	return identifier("%s_%s" % [namespace_text, suffix], invalid_prefix)


static func identifier(raw_key: String, invalid_prefix: String = "metadata") -> String:
	var safe_key: String = ""
	for index: int in range(raw_key.length()):
		var character: String = raw_key.substr(index, 1)
		if _is_ascii_identifier_character(character):
			safe_key += character
		else:
			safe_key += "_"
	if safe_key == "" or not _is_ascii_identifier_start(safe_key.substr(0, 1)):
		safe_key = "%s_%s" % [invalid_prefix, safe_key]
	return safe_key


static func _is_ascii_identifier_start(character: String) -> bool:
	if character == "_":
		return true
	if character.length() != 1:
		return false
	var code: int = character.unicode_at(0)
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122)


static func _is_ascii_identifier_character(character: String) -> bool:
	if _is_ascii_identifier_start(character):
		return true
	if character.length() != 1:
		return false
	var code: int = character.unicode_at(0)
	return code >= 48 and code <= 57
