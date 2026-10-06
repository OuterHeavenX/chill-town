extends RefCounted
## Extend known legacy inventories before validation; never coerce bad quantities.
static func normalize(source: Dictionary, version: int, items: Array) -> Dictionary:
	var state := source.duplicate(true)
	if state.get("version") != version: return state
	# Extend only known inventories. Invalid values remain invalid and are rejected below.
	for key in ["stock", "reserved", "consumed", "produced", "initial"]:
		if state.get(key) is Dictionary:
			for item in items:
				if not state[key].has(item): state[key][item] = 0
	if state.get("buildings") is Array:
		for b in state.buildings:
			if not b is Dictionary: continue
			for key in ["delivered", "output", "input"]:
				if b.get(key) is Dictionary:
					for item in items:
						if not b[key].has(item): b[key][item] = 0
	return state

