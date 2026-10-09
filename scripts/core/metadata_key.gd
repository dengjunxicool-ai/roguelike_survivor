## 文件用途：将任意文本转换为适合 Godot 元数据的合法标识符。
## 使用方式：通过 key/identifier 构建键；业务写入元数据时使用同一转换规则读取。

extends RefCounted
class_name MetadataKey


## 作用：拼接命名空间和后缀并转换为合法 ASCII 标识符。
## 使用：namespace_text/suffix 为业务名称，invalid_prefix 用于补合法开头；返回统一元数据键。
static func key(namespace_text: String, suffix: String, invalid_prefix: String = "metadata") -> String:
	return identifier("%s_%s" % [namespace_text, suffix], invalid_prefix)


## 作用：替换非字母数字下划线字符，并为非法开头添加前缀。
## 使用：raw_key 可为任意文本；invalid_prefix 应提供合法标识前缀；返回 String 文本/标识。
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


## 作用：判断单字符是否为下划线或 ASCII 字母。
## 使用：identifier 内部检查标识符首字符；其他字符或多字符返回 false。
static func _is_ascii_identifier_start(character: String) -> bool:
	if character == "_":
		return true
	if character.length() != 1:
		return false
	var code: int = character.unicode_at(0)
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122)


## 作用：判断单字符是否为 ASCII 字母、数字或下划线。
## 使用：identifier 逐字符检查；不接受 Unicode 字母或多字符文本；返回是否满足条件或执行成功。
static func _is_ascii_identifier_character(character: String) -> bool:
	if _is_ascii_identifier_start(character):
		return true
	if character.length() != 1:
		return false
	var code: int = character.unicode_at(0)
	return code >= 48 and code <= 57
