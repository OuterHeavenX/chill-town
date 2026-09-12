extends RefCounted
## Data-only KaM teaching-mission loader. Default sandbox play does not apply this.

const DIR := "res://content/missions"
## Campaign order. Each lesson unlocks one more of the production chains, so the
## list is also the order the buildings are introduced in.
const CAMPAIGN := ["tsk-01", "tsk-02", "tsk-03", "tsk-04"]

var id := ""
var name := ""
var save_mission_key := ""
var briefing: Array[String] = []
var available_buildings: Array[String] = []
var available_roles: Array[String] = []
var start: Dictionary = {}
var objectives: Array[Dictionary] = []
var win: Dictionary = {}
var lose: Array[Dictionary] = []


static func load_id(mission_id: String) -> RefCounted:
	var spec := new()
	var error := spec._load_path("%s/%s.json" % [DIR, mission_id])
	if not error.is_empty():
		push_error(error)
		return null
	return spec


## Title and one-line pitch for every campaign lesson, for the mission list. A
## lesson that fails to load is skipped rather than shown as a dead button.
static func campaign_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for mission_id: String in CAMPAIGN:
		var spec: RefCounted = load_id(mission_id)
		if spec == null:
			continue
		entries.append({
			"id": spec.id,
			"name": spec.name,
			"summary": spec.briefing[0] if not spec.briefing.is_empty() else "",
		})
	return entries


func _load_path(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "Mission file missing: " + path
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "Mission file unreadable: " + path
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return "Mission JSON must be an object: " + path
	return _apply(parsed)


func _apply(data: Dictionary) -> String:
	id = str(data.get("id", ""))
	save_mission_key = str(data.get("save_mission_key", id))
	name = str(data.get("name", id))
	if id.is_empty():
		return "Mission id is required."
	briefing = _string_array(data.get("briefing", []))
	available_buildings = _string_array(data.get("available_buildings", []))
	available_roles = _string_array(data.get("available_roles", []))
	start = data.get("start", {})
	if typeof(start) != TYPE_DICTIONARY:
		return "Mission start must be an object."
	objectives = _dict_array(data.get("objectives", []))
	win = data.get("win", {})
	if typeof(win) != TYPE_DICTIONARY:
		win = {}
	lose = _dict_array(data.get("lose", []))
	return ""


func allows_building(kind: String) -> bool:
	return available_buildings.has(kind)


func allows_role(role: String) -> bool:
	return available_roles.has(role)


func objectives_met(state: Dictionary) -> bool:
	if not bool(win.get("all_objectives", false)):
		return false
	for row in objectives:
		if not predicate_met(row, state):
			return false
	return not objectives.is_empty()


func predicate_met(row: Dictionary, state: Dictionary) -> bool:
	var progress := measure(row, state)
	return progress.x >= progress.y


## How far along one objective is, as [have, need]. The HUD shows both numbers so
## "produce 60 wine" reads as progress rather than as a light that is simply off.
func measure(row: Dictionary, state: Dictionary) -> Vector2i:
	var need: int = maxi(1, int(row.get("count", 1)))
	var kind := str(row.get("kind", ""))
	var have := 0
	match str(row.get("op", "")):
		"completed":
			have = int(_bucket(state, "completed").get(kind, 0))
		"produced":
			have = int(_bucket(state, "produced").get(kind, 0))
		"stock":
			have = int(_bucket(state, "stock").get(kind, 0))
		"role":
			have = int(_bucket(state, "roles").get(kind, 0))
		"population":
			have = int(state.get("population", 0))
		"survive":
			have = int(state.get("seconds", 0))
		_:
			return Vector2i(0, need)
	return Vector2i(mini(have, need), need)


## Whether an objective counts up towards a target the player can watch tick over.
## Building counts read better as a checkbox, so they are excluded.
func shows_progress(row: Dictionary) -> bool:
	if str(row.get("op", "")) == "completed":
		return false
	return int(row.get("count", 1)) > 1


static func _bucket(state: Dictionary, key: String) -> Dictionary:
	var value: Variant = state.get(key, {})
	return value if value is Dictionary else {}


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result


static func _dict_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for item in value:
			if item is Dictionary:
				result.append(item)
	return result
