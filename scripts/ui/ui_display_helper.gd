## 文件用途：统一解析展示名称、纹理、颜色及安全容器值。
## 使用方式：UI 页面用静态函数格式化配置；清理子控件时调用 clear_children。

extends RefCounted
class_name UIDisplayHelper


## 作用：角色名称。
## 使用：供本模块调用者使用；输入 character（角色）、fallback_id（回退ID）；返回 String 文本/标识。
static func character_name(character: Dictionary, fallback_id: Variant = "") -> String:
	return String(character.get("display_name", fallback_id))


## 作用：敌人名称。
## 使用：供本模块调用者使用；输入 enemy（敌人）、fallback_id（回退ID）；返回 String 文本/标识。
static func enemy_name(enemy: Dictionary, fallback_id: Variant = "") -> String:
	return String(enemy.get("display_name", fallback_id))


## 作用：技能名称。
## 使用：供本模块调用者使用；输入 skill_id（技能ID）；返回 String 文本/标识。
static func skill_name(skill_id: StringName) -> String:
	var skill: Dictionary = GameData.get_skill(skill_id)
	return String(skill.get("display_name", skill_id))


## 作用：视觉纹理。
## 使用：供本模块调用者使用；输入 definition（定义）、preferred_key（preferred键）；返回 Texture2D 对象/值。
static func visual_texture(definition: Dictionary, preferred_key: String) -> Texture2D:
	var visual: Dictionary = dictionary(definition.get("visual", {}))
	var texture_path: String = String(visual.get(preferred_key, visual.get("texture", "")))
	return null if texture_path == "" else load(texture_path) as Texture2D


## 作用：视觉调色。
## 使用：供本模块调用者使用；输入 definition（定义）；返回 Color 对象/值。
static func visual_modulate(definition: Dictionary) -> Color:
	var visual: Dictionary = dictionary(definition.get("visual", {}))
	var color_values: Array = array(visual.get("modulate", []))
	if color_values.size() < 4:
		return Color.WHITE
	return Color(float(color_values[0]), float(color_values[1]), float(color_values[2]), float(color_values[3]))


## 作用：从容器移除子节点并请求释放，供重建列表使用。
## 使用：传入需要清空的 parent；已有控件引用随后不应再用于交互；输入 parent（父节点）。
static func clear_children(parent: Node) -> void:
	if parent == null:
		return
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


## 作用：安全取得数组值，类型不符时返回空数组。
## 使用：本文件由 visual_modulate 调用；输入 value（值）。
static func array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


## 作用：安全取得字典值，类型不符时返回空字典。
## 使用：本文件由 visual_texture、visual_modulate 调用；输入 value（值）。
static func dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var typed: Dictionary = value
		return typed
	return {}


## 作用：双语名称。
## 使用：供本模块调用者使用；输入 data（数据）、fallback_id（回退ID）、local_keys（localkeys）、english_keys（englishkeys）；返回 String 文本/标识。
static func bilingual_name(data: Dictionary, fallback_id: Variant, local_keys: Array[String], english_keys: Array[String]) -> String:
	var local_name: String = _first_string(data, local_keys)
	var english_name: String = _first_string(data, english_keys)
	if local_name != "" and english_name != "" and local_name != english_name:
		return "%s / %s" % [local_name, english_name]
	if local_name != "":
		return local_name
	if english_name != "":
		return english_name
	return String(fallback_id)


## 作用：首个字符串。
## 使用：本文件由 bilingual_name 调用；输入 data（数据）、keys（keys）；返回 String 文本/标识。
static func _first_string(data: Dictionary, keys: Array[String]) -> String:
	for key: String in keys:
		var text: String = String(data.get(key, ""))
		if text != "":
			return text
	return ""
