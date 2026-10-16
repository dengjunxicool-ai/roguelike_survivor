extends SceneTree

const ENEMY = preload("res://scenes/enemies/enemy.tscn")
var failures: int = 0
var output: String = ""

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition: failures += 1

func run() -> void:
	var save: String = ProjectSettings.globalize_path("user://save.cfg").replace("\\", "/")
	if not save.to_lower().begins_with("e:/codex/"):
		push_error("Visual verification needs E:/codex isolated user directory")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=").replace("\\", "/").simplify_path()
	if output != "" and not output.to_lower().begins_with("e:/codex/"):
		push_error("Visual capture must remain on E:/codex")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	if DisplayServer.get_name() != "headless":
		check(await preload("res://tools/verify/verification_run_environment.gd").configure_rendered_viewport(), "actual Vulkan viewport is 1280x720")
	var background := ColorRect.new()
	background.color = Color(0.055, 0.06, 0.07)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var stage := Node2D.new()
	root.add_child(stage)
	var colors: Array[Color] = []
	var positions: Array[Vector2] = [Vector2(400, 330), Vector2(880, 330)]
	var index: int = 0
	for id: StringName in [&"armored_skeleton", &"shadow_hunter"]:
		var definition: Dictionary = GameData.get_enemy(id)
		var enemy: Node2D = ENEMY.instantiate()
		enemy.enemy_id = id
		stage.add_child(enemy)
		enemy.position = positions[index]
		enemy.set_physics_process(false)
		var active: AnimatedSprite2D = enemy.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		check(active != null and active.visible, String(id) + " uses its visible animated enemy artwork")
		if active != null:
			check(active.sprite_frames != null and active.sprite_frames.get_animation_names().size() > 0, String(id) + " loads existing SpriteFrames")
			var controller: RefCounted = enemy.get("_visual_controller")
			for state: String in ["move_left", "move_right", "attack"]:
				controller.play_state(state, true)
				check(active.sprite_frames.has_animation(active.animation) and active.is_playing(), String(id) + " plays " + state)
			var texture: Texture2D = active.sprite_frames.get_frame_texture(active.animation, 0)
			check(texture != null and texture.resource_path != "res://icon.svg", String(id) + " renders enemy texture instead of Godot icon")
			var placeholder: Sprite2D = enemy.get_node_or_null("Sprite2D") as Sprite2D
			check(placeholder == null or not placeholder.visible, String(id) + " hides scene placeholder sprite")
			colors.append(active.modulate)
		var label := Label.new()
		label.position = positions[index] + Vector2(-180, 100)
		label.size = Vector2(360, 100)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text = String(definition.get("display_name", id)) + "\n" + String(id)
		label.add_theme_font_size_override("font_size", 24)
		root.add_child(label)
		index += 1
	check(colors.size() == 2 and colors[0] != colors[1], "armored and shadow enemies have distinct variant palettes")
	for frame: int in 12: await process_frame
	if output != "" and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(output)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("enemy-variant-artwork.png")) == OK, "post-fix real rendered evidence saved")
	stage.queue_free()
	background.queue_free()
	await process_frame
	await process_frame
	print("[enemy_missing_visuals] failures=", failures)
	quit(1 if failures > 0 else 0)
