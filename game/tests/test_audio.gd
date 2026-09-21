extends SceneTree
## Headless checks for the synthesised soundscape. The audio driver here is a
## dummy, so the checks read the play counters rather than listening.
const Game = preload("res://presentation/approved_game.gd")
const Audio = preload("res://presentation/approved_audio.gd")
var game: Node
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	create_timer(180.0).timeout.connect(func():
		printerr("TIMEOUT: test_audio did not reach its result line")
		quit(1))
	call_deferred("run")


func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL ", message)


func frames(n: int = 3) -> void:
	for i in range(n):
		await process_frame


func run() -> void:
	# --- Every sound in the bank is real audio of a sensible length.
	var bank: Dictionary = Audio.bank()
	for name in ["wind", "river", "bird", "axe", "saw", "chisel", "pick", "hammer", "forge", "bellows", "rustle", "knead", "click", "clash", "twang", "chime", "complete", "fanfare", "dirge"]:
		var stream: AudioStreamWAV = bank.get(name)
		expect(stream != null and stream.data.size() > 200, "%s is synthesised" % name)
		if stream != null:
			expect(stream.mix_rate == Audio.RATE and stream.format == AudioStreamWAV.FORMAT_16_BITS, "%s is 16-bit at the shared rate" % name)
	expect(bank.wind.loop_mode == AudioStreamWAV.LOOP_FORWARD and bank.river.loop_mode == AudioStreamWAV.LOOP_FORWARD, "ambience loops")
	expect(bank.click.data.size() < bank.fanfare.data.size(), "a click is far shorter than a fanfare")
	for name in CADENCE_NAMES():
		expect(bank.has(name), "every work cadence has a sound: " + name)
	# The loop seam must not jump: first and last samples sit near each other.
	var wind: PackedByteArray = bank.wind.data
	var first := wind.decode_s16(0)
	var last := wind.decode_s16(wind.size() - 2)
	expect(absi(first - last) < 6000, "the wind loop is crossfaded at the seam (%d vs %d)" % [first, last])

	# --- Job to sound mapping reads the same fields the renderer animates from.
	expect(Audio.work_sound({"role": "lumberjack", "state": "Cortando árvore", "task": {"type": "harvest"}}) == "axe", "a woodcutter chopping sounds like an axe")
	expect(Audio.work_sound({"role": "lumberjack", "state": "Chopping a tree", "task": {"type": "harvest"}}) == "axe", "the English state matches too")
	expect(Audio.work_sound({"role": "lumberjack", "state": "Produzindo madeira", "task": {}}) == "saw", "a lumberjack at the sawmill saws")
	expect(Audio.work_sound({"role": "stonecutter", "state": "Produzindo pedra", "task": {}}) == "chisel", "a stonecutter chisels")
	expect(Audio.work_sound({"role": "blacksmith", "state": "Produzindo espada", "task": {}}) == "forge", "a blacksmith rings the anvil")
	expect(Audio.work_sound({"role": "builder", "state": "Construindo", "task": {}}) == "hammer", "a builder hammers")
	expect(Audio.work_sound({"role": "builder", "state": "Disponível", "task": {}}) == "", "an idle builder is silent")
	expect(Audio.work_sound({"role": "servant", "state": "Buscando madeira", "task": {"type": "delivery"}}) == "", "a servant carrying is silent")
	expect(Audio.work_sound({"role": "stonecutter", "state": "Aguardando retirada da produção", "task": {}}) == "", "a stalled quarry is silent")

	# --- In the running game: ambience, work strikes, attenuation and mute.
	game = Game.new()
	root.add_child(game)
	game.set_process(false)
	await frames(4)
	var audio: Node = game.audio
	expect(audio != null and audio.enabled, "the game carries a sound node, on by default")
	expect(audio._wind.playing and audio._river.playing, "wind and river start with the game")
	var near: float = audio._gain(game.world.focus)
	var far: float = audio._gain(game.world.focus + Vector3(60, 0, 0))
	expect(near == 0.0 and far < near, "sound fades with distance from the camera (%.1f vs %.1f)" % [near, far])
	expect(audio._gain(game.world.focus + Vector3(400, 0, 0)) <= -80.0, "far off the screen is cut entirely")
	game.world.focus = Vector3(Audio.RIVER_X, 0, 30)
	audio._process(0.0)
	var on_bank: float = audio._river.volume_db
	game.world.focus = Vector3(Audio.RIVER_X - 36.0, 0, 30)
	audio._process(0.0)
	expect(on_bank > audio._river.volume_db, "the river is louder on its bank than in the village (%.0f vs %.0f dB)" % [on_bank, audio._river.volume_db])

	# A woodcutter mid-chop strikes on the cadence, and stays quiet when paused.
	var worker: Dictionary = game.sim.workers[0]
	worker.role = "lumberjack"
	worker.state = "Cortando árvore"
	worker.task = {"type": "harvest", "building": -1, "tree": Vector2i(3, 3)}
	game.world.focus = Vector3(worker.cell.x * 2.5, 0, worker.cell.y * 2.5)
	game.sim.paused = false
	audio.plays.clear()
	for i in range(30):
		audio._process(0.1)
	var strikes := int(audio.plays.get("axe", 0))
	expect(strikes >= 2 and strikes <= 5, "three seconds of chopping gives a few axe strikes (%d)" % strikes)
	game.sim.paused = true
	for i in range(30):
		audio._process(0.1)
	expect(int(audio.plays.get("axe", 0)) == strikes, "a paused village makes no work sounds")
	game.sim.paused = false

	# A building finishing dings once, and never again for the same building.
	var site: Dictionary = game.sim._add_building("house", Vector2i(16, 18), false)
	audio._process(0.1)
	expect(int(audio.plays.get("complete", 0)) == 0, "a site under way is silent")
	site.stage = "complete"
	audio._process(0.1)
	audio._process(0.1)
	expect(int(audio.plays.get("complete", 0)) == 1, "a finished building dings exactly once")

	# Blows in a fight ring; a captured camp gets the fanfare.
	game.sim._ensure_battle()
	game.sim.battle.recruit("lancer", "sword")
	audio._process(0.1)
	var soldier: Dictionary = game.sim.battle.units.back()
	soldier.cooldown = 10
	audio._process(0.1)
	expect(int(audio.plays.get("clash", 0)) == 1, "a sword blow rings")
	audio._process(0.1)
	expect(int(audio.plays.get("clash", 0)) == 1, "a cooldown ticking down is not another blow")
	game.sim.battle.captured = true
	audio._process(0.1)
	expect(int(audio.plays.get("fanfare", 0)) == 1, "taking the camp earns a fanfare")

	# UI clicks come from the HUD button factory.
	audio.plays.clear()
	var button: Button = game.hud._button(game.hud._root, "x", func(): pass)
	button.pressed.emit()
	expect(int(audio.plays.get("click", 0)) == 1, "a HUD button click is heard")
	button.dragged = true
	button.pressed.emit()
	expect(int(audio.plays.get("click", 0)) == 1, "a drag that scrolled the panel is not a click")

	# Mute silences everything, persists, and comes back. Toggle the way a
	# player does, through the menu button, so the label is exercised too.
	game.hud.sound_toggled.emit()
	expect(not audio._wind.playing and not audio.enabled, "muting stops the ambience")
	audio.plays.clear()
	for i in range(20):
		audio._process(0.1)
	expect(audio.plays.is_empty(), "a muted village fires no work sounds")
	expect(not Audio.saved_enabled(), "the mute choice is remembered")
	expect(game.hud._sound_button.text == tr("Som: desligado"), "the menu shows sound off")
	game.hud.sound_toggled.emit()
	expect(Audio.saved_enabled() and audio._wind.playing, "sound comes back on and is remembered")
	expect(game.hud._sound_button.text == tr("Som: ligado"), "the menu shows sound on again")
	expect(tr("Som: ligado") == "Sound: on", "the sound toggle reads as English")
	print("AUDIO_RESULT checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)


func CADENCE_NAMES() -> Array:
	return Audio.CADENCE.keys()
