## 文件用途：登记 UI 状态、允许转移、构建顺序、暂停和子页属性。
## 使用方式：构造时注册默认状态；UIStateMachine/Host/PrepareRouter 查询统一状态契约。

extends RefCounted
class_name UIStateRegistry

const UIStateDescriptorScript: Script = preload("res://scripts/ui/ui_state_descriptor.gd")

const STATE_BOOT: String = "BOOT"
const STATE_TITLE: String = "TITLE"
const STATE_CHARACTER_SELECT: String = "CHARACTER_SELECT"
const STATE_MAP_SELECT: String = "MAP_SELECT"
const STATE_RUNNING: String = "RUNNING"
const STATE_LEVEL_UP_MODAL: String = "LEVEL_UP_MODAL"
const STATE_RUN_REWARD_MODAL: String = "RUN_REWARD_MODAL"
const STATE_CURSE_CHOICE_MODAL: String = "CURSE_CHOICE_MODAL"
const STATE_PAUSE_MENU: String = "PAUSE_MENU"
const STATE_RESULT_DEFEAT: String = "RESULT_DEFEAT"
const STATE_RESULT_VICTORY: String = "RESULT_VICTORY"
const STATE_META_UPGRADE: String = "META_UPGRADE"
const STATE_CODEX: String = "CODEX"
const STATE_SETTINGS: String = "SETTINGS"


var _allowed_to_by_state: Dictionary = {}
var _running_child_states: Dictionary = {}
var _fullscreen_choice_states: Dictionary = {}
var _descriptors: Dictionary = {}
var _build_order: Array[String] = []


## 作用：初始化本对象所需的配置与内部状态。
## 使用：对象构造时自动执行；传入构造参数后再使用公开接口。
func _init() -> void:
	_register_defaults()


## 作用：检查来源状态允许的目标列表。
## 使用：同状态或未登记来源状态直接允许；其余按 allowed_to 判断，from_state/to_state 为状态名；返回是否满足条件或执行成功。
func can_transition(from_state: String, to_state: String) -> bool:
	if from_state == to_state:
		return true
	if not _allowed_to_by_state.has(from_state):
		return true
	var allowed_to: Array = _allowed_to_by_state.get(from_state, [])
	return allowed_to.has(to_state)


## 作用：查询指定状态的描述字典。
## 使用：存在时返回内部原引用，修改会改变注册表；未知状态返回空字典。
func get_descriptor(state: String) -> Dictionary:
	if _descriptors.has(state):
		return _descriptors[state]
	return {}


## 作用：返回状态登记顺序的独立数组。
## 使用：页面构建循环使用；修改返回数组不会改变内部构建顺序。
func get_build_order() -> Array[String]:
	return _build_order.duplicate()


## 作用：获取构建方法，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；输入 state（状态）；返回 StringName 文本/标识。
func get_build_method(state: String) -> StringName:
	var descriptor: Dictionary = get_descriptor(state)
	if descriptor.is_empty():
		return &""
	return StringName(String(descriptor.get("build_method", "")))


## 作用：获取准备方法，供当前模块后续逻辑使用。
## 使用：供本模块调用者使用；输入 state（状态）；返回 StringName 文本/标识。
func get_prepare_method(state: String) -> StringName:
	var descriptor: Dictionary = get_descriptor(state)
	if descriptor.is_empty():
		return &""
	return StringName(String(descriptor.get("prepare_method", "")))


## 作用：判断运行子节点状态，返回布尔判断结果。
## 使用：供本模块调用者使用；输入 state（状态）。
func is_running_child_state(state: String) -> bool:
	return _running_child_states.has(state)


## 作用：判断全屏选择状态，返回布尔判断结果。
## 使用：供本模块调用者使用；输入 state（状态）。
func is_fullscreen_choice_state(state: String) -> bool:
	return _fullscreen_choice_states.has(state)


## 作用：按状态描述的 pause_mode 判断是否暂停。
## 使用：已登记状态仅 running 模式不暂停；未知状态仅 RUNNING 名称不暂停；返回是否满足条件或执行成功。
func should_pause_for_state(state: String) -> bool:
	var descriptor: Dictionary = get_descriptor(state)
	if not descriptor.is_empty():
		return String(descriptor.get("pause_mode", "")) != UIStateDescriptorScript.PAUSE_MODE_RUNNING
	return state != STATE_RUNNING


## 作用：登记默认配置。
## 使用：本文件由 _init 调用。
func _register_defaults() -> void:
	_register_boot_flow_states()
	_register_running_state()
	_register_running_child_states()
	_register_secondary_menu_states()


## 作用：登记启动流程状态组。
## 使用：本文件由 _register_defaults 调用。
func _register_boot_flow_states() -> void:
	_register_descriptor({
		"id": STATE_BOOT,
		"allowed_to": [STATE_TITLE],
		"build_method": "_build_boot",
		"pause_mode": UIStateDescriptorScript.PAUSE_MODE_PAUSE
	})
	_register_descriptor({
		"id": STATE_TITLE,
		"allowed_to": [STATE_CHARACTER_SELECT, STATE_META_UPGRADE, STATE_CODEX, STATE_SETTINGS],
		"build_method": "_build_title",
		"prepare_method": "_reset_title_screen",
		"pause_mode": UIStateDescriptorScript.PAUSE_MODE_PAUSE
	})
	_register_descriptor({
		"id": STATE_CHARACTER_SELECT,
		"allowed_to": [STATE_MAP_SELECT, STATE_TITLE],
		"build_method": "_build_character_select",
		"prepare_method": "_refresh_character_select_screen",
		"pause_mode": UIStateDescriptorScript.PAUSE_MODE_PAUSE
	})
	_register_descriptor({
		"id": STATE_MAP_SELECT,
		"allowed_to": [STATE_RUNNING, STATE_CHARACTER_SELECT],
		"build_method": "_build_map_select",
		"prepare_method": "_refresh_map_select_screen",
		"pause_mode": UIStateDescriptorScript.PAUSE_MODE_PAUSE
	})


## 作用：登记运行状态。
## 使用：本文件由 _register_defaults 调用。
func _register_running_state() -> void:
	_register_descriptor({
		"id": STATE_RUNNING,
		"allowed_to": [
			STATE_LEVEL_UP_MODAL,
			STATE_RUN_REWARD_MODAL,
			STATE_CURSE_CHOICE_MODAL,
			STATE_PAUSE_MENU,
			STATE_RESULT_DEFEAT,
			STATE_RESULT_VICTORY,
			STATE_TITLE
		],
		"build_method": "_build_run_hud",
		"pause_mode": UIStateDescriptorScript.PAUSE_MODE_RUNNING
	})


## 作用：登记运行子节点状态组。
## 使用：本文件由 _register_defaults 调用。
func _register_running_child_states() -> void:
	var running_child_targets: Array = [
		STATE_RUNNING,
		STATE_TITLE,
		STATE_CHARACTER_SELECT,
		STATE_META_UPGRADE,
		STATE_RESULT_DEFEAT,
		STATE_RESULT_VICTORY
	]
	for state: String in _get_running_child_state_list():
		_register_descriptor({
			"id": state,
			"allowed_to": running_child_targets,
			"is_running_child": true,
			"is_fullscreen_choice": [STATE_LEVEL_UP_MODAL, STATE_RUN_REWARD_MODAL].has(state),
			"build_method": _get_default_build_method(state),
			"pause_mode": UIStateDescriptorScript.PAUSE_MODE_PAUSE
		})


## 作用：登记次级菜单状态组。
## 使用：本文件由 _register_defaults 调用。
func _register_secondary_menu_states() -> void:
	_register_descriptor({
		"id": STATE_META_UPGRADE,
		"allowed_to": [STATE_TITLE],
		"build_method": "_build_meta_upgrade",
		"prepare_method": "_refresh_meta_upgrade_screen",
		"pause_mode": UIStateDescriptorScript.PAUSE_MODE_PAUSE
	})
	_register_descriptor({
		"id": STATE_CODEX,
		"allowed_to": [STATE_TITLE],
		"build_method": "_build_codex",
		"pause_mode": UIStateDescriptorScript.PAUSE_MODE_PAUSE
	})
	_register_descriptor({
		"id": STATE_SETTINGS,
		"allowed_to": [STATE_TITLE],
		"build_method": "_build_settings",
		"pause_mode": UIStateDescriptorScript.PAUSE_MODE_PAUSE
	})


## 作用：规范化状态描述并登记转移、构建顺序与子状态分类。
## 使用：data 为描述字段字典，空 ID 跳过；重复 ID 覆盖描述与转移，不重复加入构建顺序。
func _register_descriptor(data: Dictionary) -> void:
	var descriptor: Dictionary = UIStateDescriptorScript.from_dictionary(data)
	var state: String = String(descriptor.get("id", ""))
	if state == "":
		return
	_descriptors[state] = descriptor
	if not _build_order.has(state):
		_build_order.append(state)
	_allowed_to_by_state[state] = descriptor.get("allowed_to", [])
	if bool(descriptor.get("is_running_child", false)):
		_running_child_states[state] = true
	if bool(descriptor.get("is_fullscreen_choice", false)):
		_fullscreen_choice_states[state] = true


## 作用：获取默认构建方法，供当前模块后续逻辑使用。
## 使用：本文件由 _register_running_child_states 调用；输入 state（状态）；返回 String 文本/标识。
func _get_default_build_method(state: String) -> String:
	match state:
		STATE_LEVEL_UP_MODAL:
			return "_build_level_up_modal"
		STATE_RUN_REWARD_MODAL:
			return "_build_run_reward_modal"
		STATE_CURSE_CHOICE_MODAL:
			return "_build_curse_choice_modal"
		STATE_PAUSE_MENU:
			return "_build_pause_menu"
		STATE_RESULT_DEFEAT, STATE_RESULT_VICTORY:
			return "_build_result_screen"
		_:
			return ""


## 作用：获取运行子节点状态列表，供当前模块后续逻辑使用。
## 使用：本文件由 _register_running_child_states 调用；返回 Array[String] 列表。
func _get_running_child_state_list() -> Array[String]:
	return [
		STATE_LEVEL_UP_MODAL,
		STATE_RUN_REWARD_MODAL,
		STATE_CURSE_CHOICE_MODAL,
		STATE_PAUSE_MENU,
		STATE_RESULT_DEFEAT,
		STATE_RESULT_VICTORY
	]
