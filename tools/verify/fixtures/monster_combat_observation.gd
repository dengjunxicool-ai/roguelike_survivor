extends RefCounted

var rows: Dictionary = {}
func enroll(key: int, metadata: Dictionary, health: int) -> void:
	rows[key] = metadata.duplicate(true)
	rows[key].merge({"last_health":health,"first_hit_seconds":-1.0,"end_seconds":-1.0,"outcome":"alive","ttk_seconds":null})
func health_changed(key: int, health: int, seconds: float, context: Dictionary) -> void:
	if not rows.has(key) or rows[key].outcome!="alive": return
	var row: Dictionary=rows[key]
	if health<int(row.last_health) and float(row.first_hit_seconds)<0:
		row.first_hit_seconds=seconds
		row.first_hit_context=context.duplicate(true)
	row.last_health=health
func finish(key: int, seconds: float, outcome: String) -> void:
	if not rows.has(key) or rows[key].outcome!="alive": return
	var row: Dictionary=rows[key]
	row.end_seconds=seconds
	row.outcome=outcome
	if float(row.first_hit_seconds)>=0:
		row.observed_after_hit_seconds=maxf(0,seconds-float(row.first_hit_seconds))
		if outcome=="killed": row.ttk_seconds=row.observed_after_hit_seconds
func snapshot() -> Array:
	return rows.values().duplicate(true)
