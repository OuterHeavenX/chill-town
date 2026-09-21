extends SceneTree
## Photographs a built-out village for the loading screen: the game's own
## buildings, light and weather rather than a painting of them. Needs a real
## display (xvfb-run is enough); headless only checks the town can be placed.
##
##   godot --path game --rendering-driver opengl3 --script res://tests/render_splash.gd
##
## Writes res://assets/approved/previews/splash.webp (the shell's hero) and,
## for inspection, user://splash-*.png at every hour it considered.

const OUTPUT := "res://assets/approved/previews/splash.webp"
const CAPTURE := Vector2i(2560, 1440)
const FINAL := Vector2i(1920, 1080)
## Seconds of village time since the game opened; the sun is a clock.
const HOURS := {"afternoon": 120.0, "golden": 150.0, "dusk": 172.0, "nightfall": 186.0}
const KEEP := "dusk"

const TOWN: Array = [
	["house", Vector2i(4, 6)], ["house", Vector2i(7, 6)], ["house", Vector2i(10, 6)],
	["house", Vector2i(16, 6)], ["house", Vector2i(4, 16)], ["house", Vector2i(7, 16)],
	["inn", Vector2i(10, 16)], ["market", Vector2i(13, 16)], ["store", Vector2i(16, 9)],
	["lumber", Vector2i(3, 12)], ["quarry", Vector2i(14, 19)], ["farm", Vector2i(17, 17)],
	["farm", Vector2i(19, 17)], ["vineyard", Vector2i(17, 20)], ["vineyard", Vector2i(19, 20)],
	["winery", Vector2i(16, 13)], ["mill", Vector2i(13, 6)], ["bakery", Vector2i(19, 6)],
	["workshop", Vector2i(12, 3)], ["kiln", Vector2i(4, 3)], ["mine", Vector2i(9, 3)],
	["foundry", Vector2i(4, 9)], ["forge", Vector2i(4, 20)], ["barracks", Vector2i(7, 20)],
	["house", Vector2i(10, 20)],
]

var game: Node
var placed: Array[String] = []
var refused: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func frames(n: int) -> void:
	for i in range(n):
		await process_frame


func run() -> void:
	root.size = CAPTURE
	game = load("res://scenes/approved.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	await frames(4)
	var sim: RefCounted = game.sim
	sim.mission = null
	for plan: Array in TOWN:
		var reason: String = sim.can_place(plan[0], plan[1])
		if reason.is_empty():
			sim._add_building(plan[0], plan[1], true)
			placed.append("%s@%s" % [plan[0], plan[1]])
		else:
			refused.append("%s@%s: %s" % [plan[0], plan[1], reason])
	_pave()
	game.world.terrain.sync()
	# Let the town breathe for a while so people are out on the roads.
	for i in range(240):
		sim.step()
	sim.paused = true
	game.hud._dismiss_tutorial()
	game.hud.close_panels()
	game.hud.hide()
	game.world.target_focus = Vector3(26.0, 0.0, 33.0)
	game.world.focus = game.world.target_focus
	game.world.target_size = 39.0
	game.world.view_size = 39.0
	game.world.target_yaw = 0.48
	game.world.yaw = 0.48
	game.world.set_selected(-1)
	game.world.clear_preview()
	print("SPLASH_TOWN placed=%d refused=%s" % [placed.size(), refused])
	if DisplayServer.get_name() == "headless":
		print("SPLASH_PREPARED_HEADLESS: run under a display to write the image.")
		quit(0 if refused.is_empty() else 1)
		return
	var kept: Image
	for hour: String in HOURS:
		game.world.elapsed = HOURS[hour]
		game.world.sync(0.0)
		await frames(6)
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		image.save_png("user://splash-%s.png" % hour)
		if hour == KEEP:
			kept = image
	kept.resize(FINAL.x, FINAL.y, Image.INTERPOLATE_LANCZOS)
	var error: Error = kept.save_webp(OUTPUT, true, 0.86)
	print("SPLASH_SAVED %s %s" % [OUTPUT, error_string(error)])
	quit(0 if error == OK and refused.is_empty() else 1)


## A spine of finished road from the plaza east to the bridge, with side
## streets to the districts, laid directly so nothing has to be built.
func _pave() -> void:
	var sim: RefCounted = game.sim
	var cells: Array[Vector2i] = []
	for x in range(9, 22):
		cells.append(Vector2i(x, 13))
	for y in range(6, 13):
		cells.append(Vector2i(12, y))
		cells.append(Vector2i(6, y))
	for y in range(14, 23):
		cells.append(Vector2i(9, y))
		cells.append(Vector2i(15, y))
	for x in range(3, 22):
		cells.append(Vector2i(x, 5))
	for x in range(3, 15):
		cells.append(Vector2i(x, 22))
	for cell in cells:
		if sim.can_place_road(cell).is_empty():
			sim.roads.append({"id": sim._id(), "cell": cell, "stage": "complete", "progress": 1.0, "builder": -1, "funded": false, "delivered": 1, "carrier": -1, "reason": ""})
	sim._rebuild_roads()
	sim._road_supply_dirty = true
