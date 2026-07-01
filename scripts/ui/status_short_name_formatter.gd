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


static func short_name(status_id: String, fallback_length: int = 4) -> String:
	if STATUS_SHORT_NAMES.has(status_id):
		return String(STATUS_SHORT_NAMES[status_id])
	if fallback_length < 0:
		return status_id
	return status_id.substr(0, mini(status_id.length(), fallback_length))
