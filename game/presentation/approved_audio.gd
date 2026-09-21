extends Node
## Every sound the village makes, synthesised in code when the game starts.
## There are no audio files: this follows the original chime, keeps the web
## build small, and sidesteps licensing. Nothing in here drives the simulation;
## it only listens, the same way the world renderer does.

const RATE := 22050
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "audio"
const SETTINGS_KEY := "enabled"
## Where the water runs, in world units. The river loop fades with distance to it.
const RIVER_X := 57.5
const VOICES := 10
const BIRD_GAP := Vector2(6.0, 14.0)

## What each kind of work sounds like and how many seconds pass between strikes.
const CADENCE := {
	"axe": 0.9, "saw": 0.55, "chisel": 0.55, "pick": 0.6, "hammer": 0.75,
	"forge": 0.8, "bellows": 1.6, "rustle": 1.3, "knead": 1.1
}

static var _bank: Dictionary = {}

var sim: RefCounted
var world: Node3D
var enabled := true
## How many times each sound has played. Headless tests read this; the audio
## driver there is a dummy, so counting is the only way to know a sound fired.
var plays: Dictionary = {}

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _wind: AudioStreamPlayer
var _river: AudioStreamPlayer
var _work_timers: Dictionary = {}
var _complete_ids: Dictionary = {}
var _cooldowns: Dictionary = {}
var _bird_timer := 4.0
var _rng := RandomNumberGenerator.new()
var _won := false
var _captured := false
var _lost := false


func setup(village: RefCounted, scene: Node3D) -> void:
	sim = village
	world = scene
	enabled = saved_enabled()
	_rng.seed = 7
	var sounds := bank()
	for i in range(VOICES):
		var voice := AudioStreamPlayer.new()
		voice.bus = "Master"
		add_child(voice)
		_voices.append(voice)
	_wind = AudioStreamPlayer.new()
	_wind.stream = sounds.wind
	_wind.volume_db = -24.0
	add_child(_wind)
	_river = AudioStreamPlayer.new()
	_river.stream = sounds.river
	_river.volume_db = -60.0
	add_child(_river)
	_remember_completed()
	_apply_ambience()


func set_enabled(on: bool, persist: bool = true) -> void:
	enabled = on
	_apply_ambience()
	if not on:
		for voice in _voices:
			voice.stop()
	if persist:
		save_enabled(on)


## Fired by the game for notices the simulation tags as a chime.
func chime() -> void:
	_play("chime", -12.0)


func click() -> void:
	_play("click", -16.0)


func _process(delta: float) -> void:
	if sim == null or world == null:
		return
	_update_river()
	if not enabled:
		return
	_birds(delta)
	if bool(sim.get("paused")):
		return
	var pace: float = float(world.get("visual_speed")) if world.get("visual_speed") != null else 1.0
	_work(delta * pace)
	_completions()
	_combat()
	_outcomes()


func _apply_ambience() -> void:
	if _wind == null:
		return
	if enabled:
		if not _wind.playing:
			_wind.play()
		if not _river.playing:
			_river.play()
	else:
		_wind.stop()
		_river.stop()


func _update_river() -> void:
	if _river == null or not enabled:
		return
	var focus: Vector3 = world.get("focus")
	var distance: float = absf(focus.x - RIVER_X)
	# Full voice on the bank, ten decibels quieter for every twelve units away.
	_river.volume_db = clampf(-16.0 - 10.0 * (distance / 12.0), -60.0, -16.0)


func _birds(delta: float) -> void:
	_bird_timer -= delta
	if _bird_timer > 0.0:
		return
	_bird_timer = _rng.randf_range(BIRD_GAP.x, BIRD_GAP.y)
	_play("bird", _rng.randf_range(-24.0, -19.0), _rng.randf_range(0.9, 1.15))


## One strike per cadence for every villager mid-task, quieter with distance
## from where the camera is looking, with a little pitch scatter so a row of
## woodcutters does not sound like one loop.
func _work(delta: float) -> void:
	var alive: Dictionary = {}
	for worker: Dictionary in sim.workers:
		var sound := work_sound(worker)
		if sound.is_empty():
			continue
		var id: int = int(worker.id)
		alive[id] = true
		var remaining: float = float(_work_timers.get(id, _rng.randf_range(0.0, CADENCE[sound]))) - delta
		if remaining <= 0.0:
			var gain := _gain(_worker_position(worker))
			if gain > -50.0:
				_play(sound, gain, _rng.randf_range(0.92, 1.08))
			remaining = CADENCE[sound] * _rng.randf_range(0.85, 1.15)
		_work_timers[id] = remaining
	for id in _work_timers.keys():
		if not alive.has(id):
			_work_timers.erase(id)


## Which sound, if any, a villager's current job makes. Read from the same
## fields the world renderer animates from, so the ear and the eye agree.
static func work_sound(worker: Dictionary) -> String:
	var role := str(worker.get("role", ""))
	var state := str(worker.get("state", ""))
	var task := str(worker.get("task", {}).get("type", ""))
	if task == "harvest":
		return "axe" if state.contains("Cort") or state.contains("Chop") or state.contains("砍") else ""
	var producing := state.begins_with("Produzindo") or state.begins_with("Producing") or state.begins_with("正在生产")
	if role == "builder":
		return "hammer" if state.contains("Construindo") or state.contains("Building") or state.contains("建造") else ""
	if not producing:
		return ""
	match role:
		"lumberjack": return "saw"
		"stonecutter": return "chisel"
		"miner": return "pick"
		"blacksmith": return "forge"
		"smelter": return "bellows"
		"farmer", "vintner": return "rustle"
		"baker": return "knead"
	return ""


func _worker_position(worker: Dictionary) -> Vector3:
	var people: Dictionary = world.get("people")
	var id: int = int(worker.id)
	if people != null and people.has(id):
		return (people[id] as Node3D).position
	var cell: Vector2i = worker.cell
	return Vector3(cell.x * 2.5, 0.0, cell.y * 2.5)


## A soft two-note ding when a building finishes, once per building.
func _completions() -> void:
	for building: Dictionary in sim.buildings:
		if str(building.stage) != "complete":
			continue
		var id: int = int(building.id)
		if _complete_ids.has(id):
			continue
		_complete_ids[id] = true
		var buildings: Dictionary = world.get("buildings")
		var at: Vector3 = (buildings[id] as Node3D).position if buildings != null and buildings.has(id) else Vector3.ZERO
		_play("complete", maxf(_gain(at), -30.0))


func _remember_completed() -> void:
	for building: Dictionary in sim.buildings:
		if str(building.stage) == "complete":
			_complete_ids[int(building.id)] = true


## A blow lands whenever a soldier's cooldown jumps back up.
func _combat() -> void:
	var battle: RefCounted = sim.get("battle")
	if battle == null:
		_cooldowns.clear()
		return
	var soldiers: Dictionary = world.get("soldiers")
	for unit: Dictionary in battle.units:
		if int(unit.hp) <= 0:
			continue
		var id: int = int(unit.id)
		var cooldown: int = int(unit.cooldown)
		if cooldown > int(_cooldowns.get(id, cooldown)):
			var at: Vector3 = (soldiers[id] as Node3D).position if soldiers != null and soldiers.has(id) else Vector3.ZERO
			_play("clash" if str(unit.role) == "lancer" else "twang", _gain(at), _rng.randf_range(0.9, 1.1))
		_cooldowns[id] = cooldown


func _outcomes() -> void:
	var won := bool(sim.get("won"))
	if won and not _won:
		_play("fanfare", -10.0)
	_won = won
	var lost := bool(sim.get("lost"))
	if lost and not _lost:
		_play("dirge", -10.0)
	_lost = lost
	var battle: RefCounted = sim.get("battle")
	var captured: bool = battle != null and bool(battle.get("captured"))
	if captured and not _captured:
		_play("fanfare", -10.0)
	_captured = captured


## Quieter with distance from the camera's focus: about ten decibels per
## doubling, with the reach growing as the view zooms out.
func _gain(at: Vector3) -> float:
	var focus: Vector3 = world.get("focus")
	var distance := Vector2(at.x - focus.x, at.z - focus.z).length()
	var reach: float = maxf(8.0, float(world.get("view_size")) * 0.9)
	if distance > reach * 2.4:
		return -80.0
	return -10.0 * log(1.0 + distance / reach) / log(2.0)


func _play(name: String, gain_db: float, pitch: float = 1.0) -> void:
	plays[name] = int(plays.get(name, 0)) + 1
	if not enabled or _voices.is_empty():
		return
	var voice: AudioStreamPlayer = _voices[_next_voice]
	for candidate in _voices:
		if not candidate.playing:
			voice = candidate
			break
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = bank()[name]
	voice.volume_db = gain_db
	voice.pitch_scale = pitch
	voice.play()


static func saved_enabled() -> bool:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return true
	return bool(config.get_value(SETTINGS_SECTION, SETTINGS_KEY, true))


static func save_enabled(on: bool) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SETTINGS_SECTION, SETTINGS_KEY, on)
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Could not save sound preference: %s" % error_string(err))


# --- Synthesis -----------------------------------------------------------------
# Everything below builds sample buffers. Samples are floats in [-1, 1] and are
# packed to 16-bit at the end; loops crossfade their tail into their head so the
# seam does not click.

static func bank() -> Dictionary:
	if _bank.is_empty():
		_bank = {
			"wind": _loop(_wind_samples(4.0)),
			"river": _loop(_river_samples(3.0)),
			"bird": _wav(_bird_samples()),
			"axe": _wav(_axe_samples()),
			"saw": _wav(_saw_samples()),
			"chisel": _wav(_metal_samples([2100.0, 3350.0, 4900.0], 40.0, 0.18, 0.5)),
			"pick": _wav(_metal_samples([1500.0, 2450.0, 3600.0], 34.0, 0.22, 0.6)),
			"hammer": _wav(_hammer_samples()),
			"forge": _wav(_metal_samples([620.0, 940.0, 1370.0, 2200.0], 9.0, 0.5, 0.9)),
			"bellows": _wav(_bellows_samples()),
			"rustle": _wav(_rustle_samples(0.25, 0.15)),
			"knead": _wav(_rustle_samples(0.18, 0.06)),
			"click": _wav(_click_samples()),
			"clash": _wav(_metal_samples([1800.0, 2700.0, 4100.0], 14.0, 0.35, 1.0)),
			"twang": _wav(_twang_samples()),
			"chime": _wav(_notes_samples([[523.25, 0.0, 8.0], [783.99, 0.0, 10.0]], 0.5, 0.4)),
			"complete": _wav(_notes_samples([[659.25, 0.0, 7.0], [987.77, 0.12, 7.0]], 0.6, 0.35)),
			"fanfare": _wav(_notes_samples([[523.25, 0.0, 5.0], [659.25, 0.14, 5.0], [783.99, 0.28, 4.0], [1046.5, 0.42, 3.0]], 1.2, 0.35)),
			"dirge": _wav(_notes_samples([[392.0, 0.0, 3.0], [311.13, 0.35, 3.0], [261.63, 0.7, 2.5]], 1.6, 0.35)),
		}
	return _bank


static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	stream.data = bytes
	return stream


static func _loop(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := _wav(_seamless(samples, int(RATE * 0.35)))
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = samples.size() - int(RATE * 0.35)
	return stream


## Blend the last `overlap` samples into the first so the loop point vanishes.
static func _seamless(samples: PackedFloat32Array, overlap: int) -> PackedFloat32Array:
	var body := samples.size() - overlap
	var out := PackedFloat32Array()
	out.resize(body)
	for i in range(body):
		out[i] = samples[i]
	for i in range(overlap):
		var t := float(i) / float(overlap)
		out[i] = samples[i] * t + samples[body + i] * (1.0 - t)
	return out


static func _noise(count: int, seed_value: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := PackedFloat32Array()
	out.resize(count)
	for i in range(count):
		out[i] = rng.randf_range(-1.0, 1.0)
	return out


## One-pole low pass; `amount` near zero keeps only rumble, near one keeps all.
static func _lowpass(samples: PackedFloat32Array, amount: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(samples.size())
	var y := 0.0
	for i in range(samples.size()):
		y += amount * (samples[i] - y)
		out[i] = y
	return out


static func _wind_samples(seconds: float) -> PackedFloat32Array:
	var count := int(RATE * seconds)
	var out := _lowpass(_noise(count, 11), 0.035)
	for i in range(count):
		var t := float(i) / RATE
		var gust := 0.55 + 0.45 * (0.6 * sin(TAU * 0.13 * t) + 0.4 * sin(TAU * 0.31 * t + 1.7))
		out[i] *= gust * 4.0
	return out


static func _river_samples(seconds: float) -> PackedFloat32Array:
	var count := int(RATE * seconds)
	var raw := _noise(count, 23)
	var bright := _lowpass(raw, 0.32)
	var dull := _lowpass(raw, 0.05)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in range(count):
		var t := float(i) / RATE
		var swirl := 0.8 + 0.2 * sin(TAU * 0.47 * t)
		out[i] = (bright[i] - dull[i]) * 1.6 * swirl
	return out


static func _bird_samples() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(RATE * 0.55))
	var phrase := [[0.0, 2900.0, 3900.0, 0.07], [0.11, 3300.0, 2700.0, 0.06], [0.24, 3000.0, 4100.0, 0.09]]
	for chirp in phrase:
		var start := int(RATE * float(chirp[0]))
		var length := int(RATE * float(chirp[3]))
		var phase := 0.0
		for i in range(length):
			var u := float(i) / float(length)
			var freq: float = lerpf(float(chirp[1]), float(chirp[2]), u)
			phase += TAU * freq / RATE
			var envelope := sin(PI * u)
			out[start + i] += sin(phase) * envelope * 0.55
	return out


static func _axe_samples() -> PackedFloat32Array:
	var count := int(RATE * 0.16)
	var crack := _lowpass(_noise(count, 5), 0.55)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in range(count):
		var t := float(i) / RATE
		out[i] = sin(TAU * 110.0 * t) * exp(-t * 28.0) * 0.8 + crack[i] * exp(-t * 90.0) * 0.9
	return out


static func _saw_samples() -> PackedFloat32Array:
	var count := int(RATE * 0.42)
	var buzz := _lowpass(_noise(count, 9), 0.3)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in range(count):
		var t := float(i) / RATE
		var envelope := minf(t / 0.05, 1.0) * minf((0.42 - t) / 0.12, 1.0)
		out[i] = buzz[i] * (0.55 + 0.45 * sin(TAU * 38.0 * t)) * envelope * 1.4
	return out


static func _hammer_samples() -> PackedFloat32Array:
	var count := int(RATE * 0.18)
	var knock := _lowpass(_noise(count, 13), 0.4)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in range(count):
		var t := float(i) / RATE
		out[i] = sin(TAU * 180.0 * t) * exp(-t * 26.0) * 0.7 + knock[i] * exp(-t * 60.0) * 0.8
	return out


## Struck metal: a click, then inharmonic partials ringing down together.
static func _metal_samples(partials: Array, decay: float, seconds: float, brightness: float) -> PackedFloat32Array:
	var count := int(RATE * seconds)
	var click := _lowpass(_noise(count, 17), 0.7)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in range(count):
		var t := float(i) / RATE
		var ring := 0.0
		for k in range(partials.size()):
			ring += sin(TAU * float(partials[k]) * t) * exp(-t * decay * (1.0 + 0.25 * k)) / float(k + 1)
		out[i] = ring * 0.55 * brightness + click[i] * exp(-t * 400.0) * 0.6
	return out


static func _bellows_samples() -> PackedFloat32Array:
	var count := int(RATE * 0.9)
	var air := _lowpass(_noise(count, 19), 0.12)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in range(count):
		var t := float(i) / RATE
		out[i] = air[i] * sin(PI * t / 0.9) * 2.2
	return out


static func _rustle_samples(seconds: float, tone: float) -> PackedFloat32Array:
	var count := int(RATE * seconds)
	var leaves := _lowpass(_noise(count, 29), tone)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in range(count):
		var t := float(i) / RATE
		out[i] = leaves[i] * sin(PI * t / seconds) * 1.3
	return out


static func _click_samples() -> PackedFloat32Array:
	var count := int(RATE * 0.035)
	var tick := _lowpass(_noise(count, 31), 0.8)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in range(count):
		var t := float(i) / RATE
		out[i] = sin(TAU * 1400.0 * t) * exp(-t * 260.0) * 0.5 + tick[i] * exp(-t * 900.0) * 0.5
	return out


static func _twang_samples() -> PackedFloat32Array:
	var count := int(RATE * 0.22)
	var snap := _lowpass(_noise(count, 37), 0.6)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in range(count):
		var t := float(i) / RATE
		out[i] = sin(TAU * 190.0 * t + 3.0 * sin(TAU * 190.0 * t)) * exp(-t * 22.0) * 0.6 + snap[i] * exp(-t * 500.0) * 0.5
	return out


## Notes as [frequency, start seconds, decay]; the original chime is one of these.
static func _notes_samples(notes: Array, seconds: float, level: float) -> PackedFloat32Array:
	var count := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(count)
	for note in notes:
		var start := int(RATE * float(note[1]))
		for i in range(start, count):
			var t := float(i - start) / RATE
			out[i] += (sin(TAU * float(note[0]) * t) + 0.35 * sin(TAU * float(note[0]) * 2.0 * t)) * exp(-t * float(note[2])) * level
	return out
