## 文件用途：将状态 ID 映射为紧凑展示名。
## 使用方式：HUD/Debug 的状态摘要静态调用 short_name，未知 ID 沿用回退文本。

extends RefCounted
class_name StatusShortNameFormatter


const STATUS_SHORT_NAMES: Dictionary = {
	"burning": "Brn",
	"poison": "Psn",
	"bleed": "Bld",
	"freeze": "Frz",
	"slow": "Slw",
	"stun": "Stn",
	"paralyze": "Prz",
	"armor_break": "Arm",
	"shock": "Shk",
	"heat": "Heat",
	"soul_ember": "Embr",
	"flame_core": "Core",
	"soulburn_hint": "Soul",
	"chill": "Chil",
	"frost_lock": "Lock",
	"frostbite": "Fbt",
	"charge": "Chg",
	"voltage": "Volt",
	"arcane_mark": "Arc",
	"arcane_seal": "Seal",
	"wound": "Wnd",
	"eagle_mark": "Egl",
	"burst_mark": "Bst",
	"prey_mark": "Prey",
	"impurity": "Imp",
	"toxin_seed": "Seed",
	"toxic_core": "TCore",
	"flammable_mark": "Fla",
	"oil_stack": "Oil",
	"acid_mark": "Acid",
	"acid_residue": "ARes",
	"judgment": "Jdg",
	"residue": "Res",
	"hunter_mark": "Hnt",
	"snare_mark": "Snr",
	"holy_mark": "Hol",
	"blackfire": "Blk",
	"root": "Root",
	"weaken": "Wkn",
	"radiance": "Rad"
}


## 作用：短名名称。
## 使用：供本模块调用者使用；输入 status_id（状态效果ID）、fallback_length（回退length）；返回 String 文本/标识。
static func short_name(status_id: String, fallback_length: int = 4) -> String:
	if STATUS_SHORT_NAMES.has(status_id):
		return String(STATUS_SHORT_NAMES[status_id])
	if fallback_length < 0:
		return status_id
	return status_id.substr(0, mini(status_id.length(), fallback_length))
