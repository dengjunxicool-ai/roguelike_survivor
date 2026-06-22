extends Area2D
class_name MagnetPickup


@export_range(1.0, 1000.0, 1.0, "or_greater") var magnet_radius: float = 180.0
@export_range(1.0, 2000.0, 10.0, "or_greater") var fly_speed: float = 360.0
