extends SceneTree
## A clean photograph of the world as a player first sees it, HUD hidden, for
## comparing the live game against a target rendering. Needs a display.
##
##   godot --path game --rendering-driver opengl3 --script res://tests/render_baseline.gd [-- out=user://x.png]

const SIZE := Vector2i(1920, 1080)

var game: Node


func _initialize() -> void:
	call_deferred("run")


func frames(n: int) -> void:
	for i in range(n):
		await process_frame


func run() -> void:
	var output := "user://dream-baseline.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("out="):
			output = argument.trim_prefix("out=")
	root.size = SIZE
	game = load("res://scenes/approved.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	await frames(4)
	for i in range(120):
		game.sim.step()
	game.sim.paused = true
	game.hud._dismiss_tutorial()
	game.hud.close_panels()
	game.hud.hide()
	game.world.elapsed = 150.0
	game.world.sync(0.0)
	await frames(8)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(output)
	print("BASELINE_SAVED %s %s" % [output, error_string(error)])
	quit(0 if error == OK else 1)
