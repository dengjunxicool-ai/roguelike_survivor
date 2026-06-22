extends EnemyBase
class_name BossController


@export_range(1.0, 10.0, 0.1, "or_greater") var boss_health_multiplier: float = 1.0


func _ready() -> void:
	enemy_id = &"dungeon_heart"
	super._ready()
	if boss_health_multiplier != 1.0:
		max_health = roundi(float(max_health) * boss_health_multiplier)
		current_health = max_health
		health_changed.emit(current_health, max_health)
