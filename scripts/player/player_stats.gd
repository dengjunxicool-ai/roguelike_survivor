extends Resource
class_name PlayerStats


@export_range(0.0, 1000.0, 10.0, "or_greater") var move_speed: float = 220.0
@export_range(1, 1000, 1, "or_greater") var max_health: int = 100
@export_range(1, 100, 1, "or_greater") var starting_level: int = 1
@export_range(1, 10000, 1, "or_greater") var base_experience_to_next_level: int = 100
@export_range(1.0, 10.0, 0.05, "or_greater") var experience_growth_per_level: float = 1.25
