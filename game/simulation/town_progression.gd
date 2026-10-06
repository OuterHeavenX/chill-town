extends RefCounted
## Repeatable free-village goals, kept separate from logistics and missions.
static func update(town: RefCounted) -> void:
	var earned := {"working_village": town._completed("inn") > 0 and town._completed("lumber") > 0 and town._completed("quarry") > 0,
		"bread_chain": int(town.produced.loaves) >= 20,
		"trading_town": int(town.stats.get("gold_earned",0)) >= 80,
		"iron_age": int(town.produced.sword) >= 1,
		"growing_town": town.workers.size() >= 32,
		"camp_taken": town.raid_looted}
	for key in earned:
		if earned[key] and not town.milestones.has(key):
			town.milestones.append(key)
			town._emit(town.tr("Town milestone reached: {name}").format({"name":town.tr(str(key).replace("_", " ").capitalize())}), "chime")
	# Contracts pay for real sales rather than repeatedly rewarding the same stock.
	if town.mission == null and int(town.stats.get("gold_earned",0)) - town.trade_contract_baseline >= 100:
		town.trade_contract_baseline += 100
		town.trade_contracts += 1
		town.stock.gold += 10
		town.produced.gold += 10
		town._emit(town.tr("Trade contract fulfilled: 100 gold earned, 10 gold bonus."), "chime")
	if town.mission == null and town.harvest_map != null and town.tick >= town.forestry_due:
		town.forestry_due = town.tick + town.FORESTRY_REGROW_TICKS
		var stumps: Array = town.harvest_map.harvested_cells()
		if not stumps.is_empty():
			town.harvest_map.replant(stumps[0])

